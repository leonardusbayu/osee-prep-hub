import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Live class service — Task 14.x.
 *
 * Manages live class scheduling, registrations, and reminders.
 */

export interface LiveClass {
  id: string;
  title: string;
  description: string | null;
  teacher_id: string;
  scheduled_at: string;
  duration_minutes: number;
  zoom_url: string;
  max_participants: number | null;
  target_exam: string | null;
  created_at: string;
}

/** List upcoming live classes. */
export async function listUpcomingClasses(env: Env): Promise<LiveClass[]> {
  const supabase = getSupabase(env);
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('live_classes')
    .select('*')
    .gte('scheduled_at', now)
    .order('scheduled_at', { ascending: true });
  if (error) throw new Error(`List classes failed: ${error.message}`);
  return (data ?? []) as LiveClass[];
}

/** Register user for a class. */
export async function registerForClass(env: Env, userId: string, classId: string): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase.from('class_registrations').insert({
    user_id: userId,
    class_id: classId,
  });
  if (error) {
    if (error.code === '23505') return; // already registered
    throw new Error(`Registration failed: ${error.message}`);
  }
}

/** Send class reminder (placeholder — Telegram via EduBot bridge). */
export async function sendClassReminder(env: Env, classId: string): Promise<{ sent: number }> {
  const supabase = getSupabase(env);
  const { data: registrations } = await supabase
    .from('class_registrations')
    .select('user_id')
    .eq('class_id', classId);

  // TODO: Bridge to EduBot's Telegram sendMessage
  // For now, log and return count
  console.log(`Reminder would be sent to ${registrations?.length ?? 0} users for class ${classId}`);
  return { sent: registrations?.length ?? 0 };
}