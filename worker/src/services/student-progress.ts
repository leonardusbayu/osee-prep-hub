import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Student progress service — updates student_progress_unified table
 * from webhook events.
 *
 * Task 3.3: Implements the full update logic.
 * For now, this is a functional implementation that handles
 * practice_completed and test_completed events.
 */

export interface ProgressUpdateInput {
  user_id: string;
  platform: string; // 'ibt' | 'itp' | 'ielts' | 'toeic' | 'booking' | 'edubot'
  event_type: string;
  payload: Record<string, unknown>;
}

/** Update student_progress_unified with new practice/test data. */
export async function updateStudentProgress(env: Env, input: ProgressUpdateInput): Promise<void> {
  const supabase = getSupabase(env);

  // Extract score + section from payload (shape varies by platform)
  const score = extractScore(input.payload);
  const section = (input.payload.section as string) ?? null;
  const examType = mapPlatformToExamType(input.platform);

  // Upsert into student_progress_unified
  // The table has one row per student, with columns for each platform's latest score
  const update: Record<string, unknown> = {
    student_id: input.user_id,
    updated_at: new Date().toISOString(),
  };

  // Update platform-specific latest score column
  const scoreColumn = `${input.platform}_latest_score` as string;
  if (score !== null) {
    update[scoreColumn] = score;
  }

  // Update section-specific score if provided
  if (section && score !== null) {
    const sectionColumn = `${input.platform}_${section}_score` as string;
    update[sectionColumn] = score;
  }

  // Increment practice count
  const countColumn = `${input.platform}_practice_count` as string;
  update[countColumn] = await incrementCount(supabase, input.user_id, countColumn);

  // Try upsert — if row doesn't exist, insert; if exists, update
  const { error } = await supabase
    .from('student_progress_unified')
    .upsert(update, { onConflict: 'student_id' });

  if (error) {
    throw new Error(`Failed to update progress: ${error.message}`);
  }

  // Also insert a history row (if student_progress_history table exists)
  // This preserves the full practice history for analytics
  await supabase.from('student_progress_history').insert({
    student_id: input.user_id,
    platform: input.platform,
    exam_type: examType,
    section,
    score,
    completed_at: new Date().toISOString(),
  });
}

/** Extract numeric score from webhook payload. Returns null if not found. */
function extractScore(payload: Record<string, unknown>): number | null {
  const candidates = ['score', 'total_score', 'overall_score', 'band'];
  for (const key of candidates) {
    const val = payload[key];
    if (typeof val === 'number') return val;
    if (typeof val === 'string') {
      const parsed = parseFloat(val);
      if (!Number.isNaN(parsed)) return parsed;
    }
  }
  return null;
}

/** Map platform string to exam_type used in DB. */
function mapPlatformToExamType(platform: string): string {
  const map: Record<string, string> = {
    ibt: 'TOEFL_IBT',
    itp: 'TOEFL_ITP',
    ielts: 'IELTS',
    toeic: 'TOEIC',
    booking: 'OFFICIAL',
    edubot: 'EDUBOT',
  };
  return map[platform] ?? 'GENERAL';
}

/** Get current value of count column + 1. */
async function incrementCount(
  supabase: import('@supabase/supabase-js').SupabaseClient,
  userId: string,
  column: string
): Promise<number> {
  const { data } = await supabase
    .from('student_progress_unified')
    .select(column)
    .eq('student_id', userId)
    .maybeSingle();
  const current = ((data as Record<string, unknown> | null)?.[column] as number) ?? 0;
  return current + 1;
}