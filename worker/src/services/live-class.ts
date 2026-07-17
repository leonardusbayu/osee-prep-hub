/**
 * Live class service — T12 (Wave 2).
 *
 * Live video sessions via LiveKit. Worker creates a JWT for room join
 * (LiveKit API key + secret stored in env). Recording goes to R2.
 *
 * Skeleton: route returns mock JWT. Real impl requires:
 *   LIVEKIT_API_KEY, LIVEKIT_API_SECRET
 * Plus a Flutter client using livekit_client package.
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface LiveClassRoom {
  id: string;
  syllabus_id: string;
  teacher_id: string;
  scheduled_at: string;
  duration_minutes: number;
  livekit_room_name: string;
  status: 'scheduled' | 'live' | 'ended' | 'cancelled';
  recording_url: string | null;
  created_at: string;
}

export interface LiveClass {
  id: string;
  title: string;
  description: string | null;
  teacher_id: string;
  scheduled_at: string;
  duration_minutes: number;
  zoom_url: string | null;
  max_participants: number | null;
  target_exam: string | null;
  created_at: string;
}

/** List upcoming live classes. */
export async function listUpcomingClasses(env: Env): Promise<LiveClass[]> {
  const { getSupabase } = await import('./supabase');
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

/** Register user for a class — compatibility stub for existing route. */
export async function registerForClass(env: Env, userId: string, classId: string): Promise<void> {
  const { getSupabase } = await import('./supabase');
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('live_class_attendees')
    .upsert({ class_id: classId, user_id: userId, joined_at: new Date().toISOString() }, { onConflict: 'class_id,user_id' });
  if (error) throw new Error(`registerForClass failed: ${error.message}`);
}

/** Generate a LiveKit JWT for a participant joining a room.
 *  Stub: returns a placeholder JWT. Real impl uses 'jsonwebtoken' + LIVEKIT_API_SECRET.
 */
export function generateLivekitJwt(
  env: Env,
  roomName: string,
  participantIdentity: string,
  participantName: string
): string {
  if (!env.LIVEKIT_API_KEY || !env.LIVEKIT_API_SECRET) {
    // Mock JWT for development.
    const payload = JSON.stringify({
      iss: 'mock',
      sub: participantIdentity,
      video: { room: roomName, roomJoin: true, canPublish: true, canSubscribe: true },
      exp: Math.floor(Date.now() / 1000) + 60 * 60,
      name: participantName,
    });
    const b64 = btoa(payload);
    return `mock.${b64.replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}`;
  }
  // Real impl:
  // import jwt from 'jsonwebtoken';
  // const token = jwt.sign({...}, env.LIVEKIT_API_SECRET, { algorithm: 'HS256' });
  throw new Error('LIVEKIT_API_SECRET not configured for real JWT generation');
}

/** Send class reminder via Telegram (EduBot bridge — Task 14.4). */
export async function sendClassReminder(env: Env, classId: string): Promise<{ sent: number }> {
  const supabase = getSupabase(env);

  // Fetch class details
  const { data: cls } = await supabase
    .from('live_classes')
    .select('id, title, description, teacher_name, scheduled_at, duration_minutes, zoom_link')
    .eq('id', classId)
    .maybeSingle();
  if (!cls) {
    return { sent: 0 };
  }
  const c = cls as Record<string, unknown>;

  // Fetch registered users with their Telegram IDs
  const { data: registrations } = await supabase
    .from('class_registrations')
    .select('user_id')
    .eq('class_id', classId);
  const userIds = ((registrations ?? []) as Array<Record<string, unknown>>).map((r) => r.user_id as string);

  // Also send to the Telegram channel broadcast
  const when = new Date(c.scheduled_at as string).toLocaleString('id-ID', {
    timeZone: 'Asia/Jakarta',
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  });
  const text =
    `📅 *Live Class Reminder*\n\n` +
    `*${c.title as string}*\n` +
    (c.description ? `${c.description as string}\n` : '') +
    `👨‍🏫 Pengajar: ${c.teacher_name as string ?? 'OSEE Instructor'}\n` +
    `⏰ ${when} WIB\n` +
    `⏱ Durasi: ${c.duration_minutes as number ?? 90} menit\n\n` +
    `🔗 Join Zoom:\n${c.zoom_link as string ?? '(link akan dibagikan saat kelas dimulai)'}`;

  let sent = 0;

  // Broadcast to Telegram channel
  if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHANNEL_ID) {
    try {
      const res = await fetch(
        `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: env.TELEGRAM_CHANNEL_ID,
            text,
            parse_mode: 'Markdown',
          }),
        }
      );
      if (res.ok) sent++;
    } catch (err) {
      console.error('Telegram channel send failed:', err);
    }
  }

  // DM registered users who have telegram_id linked
  if (userIds.length > 0 && env.TELEGRAM_BOT_TOKEN) {
    const { data: users } = await supabase
      .from('unified_profiles')
      .select('id, telegram_id, display_name')
      .in('id', userIds)
      .not('telegram_id', 'is', null);
    for (const u of (users ?? []) as Array<Record<string, unknown>>) {
      const chatId = u.telegram_id as string;
      try {
        const res = await fetch(
          `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              chat_id: chatId,
              text,
              parse_mode: 'Markdown',
            }),
          }
        );
        if (res.ok) sent++;
      } catch (err) {
        console.error(`Telegram DM to ${u.id} failed:`, err);
      }
    }
  }

  // Mark reminder sent
  await supabase
    .from('live_classes')
    .update({ bot_reminder_sent: true })
    .eq('id', classId);

  return { sent };
}

/** Cron entry: send reminders for classes starting within the next hour. */
export async function sendUpcomingClassReminders(env: Env): Promise<{ reminders_sent: number }> {
  const supabase = getSupabase(env);
  const now = new Date();
  const oneHourFromNow = new Date(now.getTime() + 60 * 60 * 1000);

  // Find classes starting within the next 60 minutes that haven't had reminders sent
  const { data: classes } = await supabase
    .from('live_classes')
    .select('id')
    .gte('scheduled_at', now.toISOString())
    .lte('scheduled_at', oneHourFromNow.toISOString())
    .eq('status', 'scheduled')
    .eq('bot_reminder_sent', false);

  let totalSent = 0;
  for (const cls of (classes ?? []) as Array<Record<string, unknown>>) {
    const result = await sendClassReminder(env, cls.id as string);
    totalSent += result.sent;
  }
  return { reminders_sent: totalSent };
}
/** Send post-class recording notification to Telegram channel (blueprint line 2462). */
export async function sendClassRecordingNotification(
  env: Env,
  classId: string,
  recordingUrl: string
): Promise<{ sent: number }> {
  const supabase = getSupabase(env);
  const { data: cls } = await supabase
    .from('live_classes')
    .select('title, teacher_name, scheduled_at')
    .eq('id', classId)
    .maybeSingle();
  if (!cls) return { sent: 0 };
  const c = cls as Record<string, unknown>;
  const text =
    `🎬 *Live Class Recording Available*\n\n` +
    `*${c.title as string}*\n` +
    `👨‍🏫 ${c.teacher_name as string ?? 'OSEE Instructor'}\n\n` +
    `🔗 Recording:\n${recordingUrl}`;

  let sent = 0;
  if (env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHANNEL_ID) {
    try {
      const res = await fetch(
        `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            chat_id: env.TELEGRAM_CHANNEL_ID,
            text,
            parse_mode: 'Markdown',
          }),
        }
      );
      if (res.ok) sent++;
    } catch (err) {
      console.error('Telegram recording notification failed:', err);
    }
  }
  return { sent };
}
