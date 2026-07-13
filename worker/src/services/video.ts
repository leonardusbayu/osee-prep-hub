import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Video content service — Task 13.x.
 *
 * Manages video courses + lessons with R2 storage.
 */

export interface VideoCourse {
  id: string;
  title: string;
  description: string | null;
  category: string;
  is_published: boolean;
  free_preview_url: string | null;
  premium_video_key: string | null;
  created_at: string;
}

export interface VideoLesson {
  id: string;
  course_id: string;
  title: string;
  description: string | null;
  video_key: string;
  duration_minutes: number;
  quiz_questions: Array<Record<string, unknown>>;
  order_index: number;
}

/** List all video courses. */
export async function listVideoCourses(env: Env, includeUnpublished = false): Promise<VideoCourse[]> {
  const supabase = getSupabase(env);
  let query = supabase.from('video_courses').select('*').order('created_at', { ascending: false });
  if (!includeUnpublished) {
    query = query.eq('is_published', true);
  }
  const { data, error } = await query;
  if (error) throw new Error(`List courses failed: ${error.message}`);
  return (data ?? []) as VideoCourse[];
}

/** Get a single course with lessons. */
export async function getCourse(env: Env, courseId: string): Promise<{
  course: VideoCourse;
  lessons: VideoLesson[];
} | null> {
  const supabase = getSupabase(env);
  const { data: course } = await supabase
    .from('video_courses')
    .select('*')
    .eq('id', courseId)
    .maybeSingle();
  if (!course) return null;

  const { data: lessons } = await supabase
    .from('video_lessons')
    .select('*')
    .eq('course_id', courseId)
    .order('lesson_number', { ascending: true });

  return {
    course: course as VideoCourse,
    lessons: (lessons ?? []) as VideoLesson[],
  };
}

/** Track video watch progress. */
export async function trackProgress(
  env: Env,
  userId: string,
  lessonId: string,
  data: { watched_seconds: number; completed: boolean; quiz_score?: number }
): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase.from('video_progress').upsert(
    {
      user_id: userId,
      lesson_id: lessonId,
      watched_seconds: data.watched_seconds,
      completed: data.completed,
      quiz_score: data.quiz_score ?? null,
      last_watched_at: new Date().toISOString(),
    },
    { onConflict: 'user_id,lesson_id' }
  );
  if (error) throw new Error(`Track progress failed: ${error.message}`);
}