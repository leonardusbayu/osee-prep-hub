import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * EduBot bridge — Task 16.x.
 *
 * Provides external API endpoints that EduBot calls to:
 * - Verify a student is authenticated
 * - Read student progress
 * - Get the syllabus to tutor on
 * - Report progress back to Hub
 *
 * Auth via EDUBOT_INTERNAL_SECRET header.
 */

export interface StudentSnapshot {
  student_id: string;
  telegram_id: string | null;
  email: string;
  display_name: string;
  role: string;
  current_level: string | null;
  target_exam: string | null;
}

/** Verify a student's OSEE token (called by EduBot during Telegram auth). */
export async function verifyStudent(env: Env, telegramId: string): Promise<StudentSnapshot | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('unified_profiles')
    .select('id, telegram_id, email, display_name, role, current_level, target_exam')
    .eq('telegram_id', telegramId)
    .maybeSingle();

  if (!data) return null;
  return {
    student_id: data.id as string,
    telegram_id: data.telegram_id as string | null,
    email: data.email as string,
    display_name: data.display_name as string,
    role: data.role as string,
    current_level: data.current_level as string | null,
    target_exam: data.target_exam as string | null,
  };
}

/** Report progress update from EduBot to Hub.
 *  Also updates student_progress_unified (aggregated) + edubot_practice_count. */
export async function receiveProgress(
  env: Env,
  userId: string,
  update: { activity_type: string; score?: number; topic?: string; metadata?: Record<string, unknown> }
): Promise<void> {
  const supabase = getSupabase(env);
  const now = new Date().toISOString();

  // Insert history row
  await supabase.from('student_progress_history').insert({
    student_id: userId,
    platform: 'edubot',
    exam_type: 'GENERAL',
    section: update.activity_type,
    score: update.score ?? null,
    completed_at: now,
    metadata: update.metadata ?? {},
  });

  // Update student_progress_unified — increment edubot_practice_count + update edubot fields
  // Read streak_days + accuracy_rate from metadata (EduBot has session context).
  const { data: existing } = await supabase
    .from('student_progress_unified')
    .select('edubot_practice_count, edubot_xp, edubot_questions_answered, edubot_last_active, edubot_streak_days, edubot_accuracy_rate')
    .eq('student_id', userId)
    .maybeSingle();

  const p = (existing as Record<string, unknown> | null) ?? {};
  const newCount = (p.edubot_practice_count as number ?? 0) + 1;
  const newXp = (p.edubot_xp as number ?? 0) + (update.score ?? 10);  // award XP
  const newQuestions = (p.edubot_questions_answered as number ?? 0) + 1;
  // Streak: EduBot sends the current streak_days in metadata; fall back to existing.
  const newStreak = (update.metadata?.streak_days as number | undefined) ?? (p.edubot_streak_days as number | undefined) ?? 0;
  // Accuracy: EduBot sends the running accuracy (0-100) in metadata; compute a
  // running average if it sends a per-session accuracy delta instead.
  const metaAccuracy = update.metadata?.accuracy_rate as number | undefined;
  let newAccuracy: number | undefined;
  if (typeof metaAccuracy === 'number') {
    // If metadata value is in 0-100 range, treat it as the current overall accuracy.
    if (metaAccuracy <= 100) {
      newAccuracy = metaAccuracy;
    } else {
      // Otherwise treat as a count-correct delta and compute a running average.
      const prevCorrect = Math.round(((p.edubot_accuracy_rate as number ?? 0) / 100) * (newQuestions - 1));
      newAccuracy = Math.round(((prevCorrect + metaAccuracy) / newQuestions) * 100);
    }
  } else {
    newAccuracy = (p.edubot_accuracy_rate as number | undefined) ?? undefined;
  }

  const upsertPayload: Record<string, unknown> = {
    student_id: userId,
    edubot_practice_count: newCount,
    edubot_xp: newXp,
    edubot_questions_answered: newQuestions,
    edubot_last_active: now,
    edubot_streak_days: newStreak,
    updated_at: now,
  };
  if (newAccuracy !== undefined) {
    upsertPayload.edubot_accuracy_rate = newAccuracy;
  }

  await supabase
    .from('student_progress_unified')
    .upsert(upsertPayload, { onConflict: 'student_id' });
}

/** Get teacher's syllabus items so EduBot can tutor on those topics. */
export async function getTeacherSyllabusForTutor(
  env: Env,
  teacherId: string
): Promise<Array<{ student_id: string; topics: string[] }>> {
  const supabase = getSupabase(env);

  // Get students in this teacher's classrooms
  const { data: classrooms } = await supabase
    .from('classrooms')
    .select('id')
    .eq('teacher_id', teacherId);

  const studentIds: string[] = [];
  for (const classroom of classrooms ?? []) {
    const { data: enrollments } = await supabase
      .from('classroom_enrollments')
      .select('student_id')
      .eq('classroom_id', (classroom as Record<string, unknown>).id)
      .eq('is_active', true);
    for (const e of enrollments ?? []) {
      studentIds.push((e as Record<string, unknown>).student_id as string);
    }
  }

  // Get topic distribution from syllabi of this teacher
  const { data: items } = await supabase
    .from('syllabus_items')
    .select('title, syllabus!inner(teacher_id)')
    .eq('syllabus.teacher_id', teacherId)
    .limit(50);

  const topics: string[] = Array.from(
    new Set((items ?? []).map((i: Record<string, unknown>) => i.title as string))
  );

  return studentIds.map((id) => ({ student_id: id, topics }));
}