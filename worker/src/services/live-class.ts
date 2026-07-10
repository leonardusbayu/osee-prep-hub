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