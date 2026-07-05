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

/** Report progress update from EduBot to Hub. */
export async function receiveProgress(
  env: Env,
  userId: string,
  update: { activity_type: string; score?: number; topic?: string; metadata?: Record<string, unknown> }
): Promise<void> {
  const supabase = getSupabase(env);
  await supabase.from('student_progress_history').insert({
    student_id: userId,
    platform: 'edubot',
    exam_type: 'GENERAL',
    section: update.activity_type,
    score: update.score ?? null,
    completed_at: new Date().toISOString(),
  });
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