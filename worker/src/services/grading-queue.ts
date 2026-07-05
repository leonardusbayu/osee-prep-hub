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
  const { data, error } = await supabase
    .from('ai_grading_queue')
    .insert({
      user_id: userId,
      grading_type: gradingType,
      status: 'pending',
      input,
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
    .eq('user_id', userId)
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
    .eq('user_id', userId)
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
    // Grade the essay
    const result = await gradeWriting(env, {
      essay: entry.input.essay as string,
      rubric: entry.input.rubric as string,
      examType: entry.input.examType as string,
      level: entry.input.level as string | undefined,
    });

    // Store result
    await supabase
      .from('ai_grading_queue')
      .update({
        status: 'completed',
        result: result as unknown as Record<string, unknown>,
        updated_at: new Date().toISOString(),
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