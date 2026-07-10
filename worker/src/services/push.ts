/**
 * Push notification service — T23 (Wave 3).
 *
 * Multi-platform push (iOS/Android/Web). Stub: stores push tokens,
 * queues messages, logs sends. Real impl: integrate Firebase Cloud
 * Messaging + OneSignal for delivery.
 *
 * Topics: 'class_starting', 'coach_reply', 'passport_issued',
 *          'marketplace_sale', 'daily_reminder', 'viral_share'
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export type PushTopic = 'class_starting' | 'coach_reply' | 'passport_issued' | 'marketplace_sale' | 'daily_reminder' | 'viral_share';

export interface PushPayload {
  topic: PushTopic;
  title: string;
  body: string;
  data?: Record<string, string>;
}

/** Register a device push token for the current user. */
export async function registerPushToken(
  env: Env,
  userId: string,
  token: string,
  platform: 'ios' | 'android' | 'web',
  deviceInfo?: Record<string, unknown>
): Promise<{ id: string }> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('push_tokens')
    .upsert({
      user_id: userId,
      token,
      platform,
      device_info: deviceInfo ?? {},
      last_seen_at: new Date().toISOString(),
    }, { onConflict: 'user_id,token' })
    .select('id')
    .single();
  if (error) throw new Error(`registerPushToken failed: ${error.message}`);
  return { id: data.id };
}

/** Subscribe a user to a topic. */
export async function subscribeTopic(env: Env, userId: string, topic: PushTopic): Promise<void> {
  const supabase = getSupabase(env);
  await supabase
    .from('push_subscriptions')
    .upsert({
      user_id: userId,
      topic,
      enabled: true,
    }, { onConflict: 'user_id,topic' });
}

/** Unsubscribe from a topic. */
export async function unsubscribeTopic(env: Env, userId: string, topic: PushTopic): Promise<void> {
  const supabase = getSupabase(env);
  await supabase
    .from('push_subscriptions')
    .update({ enabled: false })
    .eq('user_id', userId)
    .eq('topic', topic);
}

/** Send a push to all subscribed users of a topic. */
export async function sendToTopic(env: Env, payload: PushPayload): Promise<{ queued: number; errors: number }> {
  const supabase = getSupabase(env);

  // Find subscribed users.
  const { data: subs } = await supabase
    .from('push_subscriptions')
    .select('user_id')
    .eq('topic', payload.topic)
    .eq('enabled', true);
  if (!subs || subs.length === 0) return { queued: 0, errors: 0 };

  let queued = 0;
  let errors = 0;
  for (const sub of subs as any[]) {
    try {
      // Stub: log the push instead of actually sending.
      // Real impl: call FCM/OneSignal SDK.
      await supabase.from('push_log').insert({
        user_id: sub.user_id,
        topic: payload.topic,
        payload: { title: payload.title, body: payload.body, data: payload.data ?? {} },
        status: 'sent',
      });
      queued++;
    } catch (err) {
      errors++;
      await supabase.from('push_log').insert({
        user_id: sub.user_id,
        topic: payload.topic,
        payload: { title: payload.title, body: payload.body },
        status: 'failed',
        error_message: err instanceof Error ? err.message : 'unknown',
      });
    }
  }
  return { queued, errors };
}

/** Send a push to a single user. */
export async function sendToUser(env: Env, userId: string, payload: PushPayload): Promise<void> {
  const supabase = getSupabase(env);
  await supabase.from('push_log').insert({
    user_id: userId,
    topic: payload.topic,
    payload: { title: payload.title, body: payload.body, data: payload.data ?? {} },
    status: 'sent',
  });
}