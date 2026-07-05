import type { Env } from '../types';
import { getSupabase } from './supabase';
import { gradeWriting } from './ai-grading';

/**
 * Grading queue system — Task 5.2.
 *
 * Stores grading requests in ai_grading_queue table with status:
 *   pending → processing → completed (or failed)
 *
 * POST /api/ai/grade-writing creates a queue entry and returns queue_id.
 * The queue is processed by POST /api/webhook/process (cron-triggered)
 * or by a dedicated /api/ai/grading/:id/process endpoint.
 */

export type GradingStatus = 'pending' | 'processing' | 'completed' | 'failed';
export type GradingType = 'writing' | 'speaking';

export interface GradingQueueEntry {
  id: string;
  user_id: string;
  grading_type: GradingType;
  status: GradingStatus;
  input: Record<string, unknown>;
  result: Record<string, unknown> | null;
  error_message: string | null;
  created_at: string;
  updated_at: string;
}

/** Create a grading queue entry. Returns the queue ID. */
export async function createGradingEntry(
  env: Env,
  userId: string,
  gradingType: GradingType,
  input: Record<string, unknown>
): Promise<string> {
  const supabase = getSupabase(env);
  // Actual table columns: teacher_id, student_id, submission_type, exam_type,
  //   rubric_type, rubric_config, student_response, audio_url, status, etc.
  const { data, error } = await supabase
    .from('ai_grading_queue')
    .insert({
      teacher_id: userId,
      submission_type: gradingType,
      exam_type: (input.examType as string) ?? 'IELTS',
      rubric_type: (input.rubric as string) ?? 'ielts_task2',
      rubric_config: { level: input.level },
      student_response: (input.essay as string) ?? null,
      status: 'pending',
    })
    .select('id')
    .single();

  if (error || !data) {
    throw new Error(`Failed to create grading entry: ${error?.message ?? 'unknown'}`);
  }
  return data.id as string;
}

/** Get a grading queue entry by ID. */
export async function getGradingEntry(
  env: Env,
  userId: string,
  entryId: string
): Promise<GradingQueueEntry | null> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('ai_grading_queue')
    .select('*')
    .eq('id', entryId)
    .eq('teacher_id', userId)
    .maybeSingle();

  if (error || !data) return null;
  return data as GradingQueueEntry;
}

/** Get user's grading history. */
export async function listGradingHistory(
  env: Env,
  userId: string,
  limit = 50
): Promise<GradingQueueEntry[]> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('ai_grading_queue')
    .select('*')
    .eq('teacher_id', userId)
    .order('created_at', { ascending: false })
    .limit(limit);

  if (error) {
    throw new Error(`Failed to fetch grading history: ${error.message}`);
  }
  return (data ?? []) as GradingQueueEntry[];
}

/** Process a pending grading entry — calls gradeWriting and stores result. */
export async function processGradingEntry(env: Env, entryId: string): Promise<void> {
  const supabase = getSupabase(env);

  // Mark as processing
  const { data: entry, error: fetchError } = await supabase
    .from('ai_grading_queue')
    .select('*')
    .eq('id', entryId)
    .maybeSingle();

  if (fetchError || !entry) {
    throw new Error(`Grading entry not found: ${entryId}`);
  }

  if (entry.status !== 'pending') {
    throw new Error(`Entry already ${entry.status}`);
  }

  await supabase
    .from('ai_grading_queue')
    .update({ status: 'processing', updated_at: new Date().toISOString() })
    .eq('id', entryId);

  try {
    // Grade the essay — actual table stores essay in student_response,
    // rubric in rubric_type, exam type in exam_type, level in rubric_config
    const rubricConfig = (entry as Record<string, unknown>).rubric_config as Record<string, unknown> | null;
    const result = await gradeWriting(env, {
      essay: ((entry as Record<string, unknown>).student_response as string) ?? '',
      rubric: (entry as Record<string, unknown>).rubric_type as string,
      examType: (entry as Record<string, unknown>).exam_type as string,
      level: (rubricConfig?.level as string) ?? undefined,
    });

    // Store result — actual table uses ai_score, ai_band, ai_feedback columns
    await supabase
      .from('ai_grading_queue')
      .update({
        status: 'completed',
        ai_score: (result.score as number) ?? null,
        ai_band: parseFloat(String(result.band)) || null,
        ai_feedback: result as unknown as Record<string, unknown>,
        completed_at: new Date().toISOString(),
      })
      .eq('id', entryId);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Grading failed';
    await supabase
      .from('ai_grading_queue')
      .update({
        status: 'failed',
        error_message: message,
        updated_at: new Date().toISOString(),
      })
      .eq('id', entryId);
    throw err;
  }
}

/** Process all pending grading entries (cron-triggered). */
export async function processPendingGrading(env: Env, batchSize = 10): Promise<{
  total: number;
  succeeded: number;
  failed: number;
}> {
  const supabase = getSupabase(env);
  const { data: pending, error } = await supabase
    .from('ai_grading_queue')
    .select('id')
    .eq('status', 'pending')
    .order('created_at', { ascending: true })
    .limit(batchSize);

  if (error) {
    throw new Error(`Failed to fetch pending grading: ${error.message}`);
  }

  const result = { total: pending?.length ?? 0, succeeded: 0, failed: 0 };
  for (const entry of pending ?? []) {
    try {
      await processGradingEntry(env, entry.id as string);
      result.succeeded++;
    } catch {
      result.failed++;
    }
  }
  return result;
}