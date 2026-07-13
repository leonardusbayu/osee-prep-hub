import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Student progress service — updates student_progress_unified table
 * from webhook events.
 *
 * Task 3.3: Implements the full update logic.
 * Handles practice_completed and test_completed events.
 *
 * IMPORTANT: Only writes columns that exist in the schema:
 *   - ibt_latest_score, ibt_latest_section_scores (JSONB), ibt_last_test_at, ibt_practice_count
 *   - itp_*, ielts_*, toeic_* (same pattern)
 *   - edubot_xp, edubot_streak_days, edubot_questions_answered, edubot_accuracy_rate, edubot_last_active, edubot_practice_count
 *
 * For platform 'booking' and 'edubot': no score column, only update what exists.
 */

export interface ProgressUpdateInput {
  user_id: string;
  platform: string; // 'ibt' | 'itp' | 'ielts' | 'toeic' | 'booking' | 'edubot'
  event_type: string;
  payload: Record<string, unknown>;
}

/** Map platform to exam score column prefix (null = no score column for this platform). */
const PLATFORM_SCORE_PREFIX: Record<string, string | null> = {
  ibt: 'ibt',
  itp: 'itp',
  ielts: 'ielts',
  toeic: 'toeic',
  booking: null,
  edubot: null,
};

/** Update student_progress_unified with new practice/test data. */
export async function updateStudentProgress(env: Env, input: ProgressUpdateInput): Promise<void> {
  const supabase = getSupabase(env);

  const score = extractScore(input.payload);
  const sectionScores = extractSectionScores(input.payload);
  const examType = mapPlatformToExamType(input.platform);
  const prefix = PLATFORM_SCORE_PREFIX[input.platform];

  const now = new Date().toISOString();

  // Build update object — only columns that exist in schema
  const update: Record<string, unknown> = {
    student_id: input.user_id,
    updated_at: now,
  };

  // Set score column + last_test_at + section_scores (JSONB) if platform has score prefix
  if (prefix && score !== null) {
    update[`${prefix}_latest_score`] = score;
    update[`${prefix}_last_test_at`] = now;
    if (sectionScores) {
      update[`${prefix}_latest_section_scores`] = sectionScores;
    }
  }

  // For ielts, the score column is ielts_latest_band (not ielts_latest_score)
  if (input.platform === 'ielts' && score !== null) {
    update['ielts_latest_band'] = score;
    delete update['ielts_latest_score']; // column doesn't exist
  }

  // Increment practice count
  const countColumn = `${input.platform}_practice_count`;
  const currentCount = await getCount(supabase, input.user_id, countColumn);
  update[countColumn] = currentCount + 1;

  // Try upsert
  const { error } = await supabase
    .from('student_progress_unified')
    .upsert(update, { onConflict: 'student_id' });

  if (error) {
    throw new Error(`Failed to update progress: ${error.message}`);
  }

  // Also insert a history row
  await supabase.from('student_progress_history').insert({
    student_id: input.user_id,
    platform: input.platform,
    exam_type: examType,
    section: (input.payload.section as string) ?? null,
    score,
    completed_at: now,
    metadata: input.payload,
  }).then(() => {}); // best-effort, ignore errors
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

/** Extract section scores as JSONB object. Returns null if not found. */
function extractSectionScores(payload: Record<string, unknown>): Record<string, unknown> | null {
  const candidates = ['section_scores', 'sections', 'scores'];
  for (const key of candidates) {
    const val = payload[key];
    if (val && typeof val === 'object' && !Array.isArray(val)) {
      return val as Record<string, unknown>;
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

/** Get current value of count column. */
async function getCount(
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
  return current;
}