/**
 * Push notification routes — T23 (Wave 3).
 *
 * POST /api/push/tokens                   — register device push token
 * POST /api/push/subscriptions            — subscribe/unsubscribe to topic
 * GET  /api/push/log                      — view recent push log (self)
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  registerPushToken,
  subscribeTopic,
  unsubscribeTopic,
  sendToTopic,
  sendToUser,
  type PushTopic,
} from '../services/push';
import { getSupabase } from '../services/supabase';

export const pushRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

pushRoutes.use('*', requireAuth());

/** POST /api/push/tokens — register device. */
pushRoutes.post('/tokens', async (c) => {
  const user = getAuthedUser(c);
  let body: { token?: string; platform?: string; deviceInfo?: Record<string, unknown> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.token || !body.platform) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'token, platform required' } }, 400);
  }
  if (!['ios', 'android', 'web'].includes(body.platform)) {
    return c.json({ error: { code: 'INVALID_PLATFORM', message: 'platform must be ios/android/web' } }, 400);
  }
  try {
    const result = await registerPushToken(c.env, user.id, body.token, body.platform as 'ios' | 'android' | 'web', body.deviceInfo);
    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Register failed';
    return c.json({ error: { code: 'REGISTER_FAILED', message } }, 400);
  }
});

/** POST /api/push/subscriptions */
pushRoutes.post('/subscriptions', async (c) => {
  const user = getAuthedUser(c);
  let body: { topic?: string; enabled?: boolean };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.topic) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'topic required' } }, 400);
  }
  const validTopics: PushTopic[] = ['class_starting', 'coach_reply', 'passport_issued', 'marketplace_sale', 'daily_reminder', 'viral_share'];
  if (!validTopics.includes(body.topic as PushTopic)) {
    return c.json({ error: { code: 'INVALID_TOPIC', message: `topic must be one of: ${validTopics.join(', ')}` } }, 400);
  }
  try {
    if (body.enabled === false) {
      await unsubscribeTopic(c.env, user.id, body.topic as PushTopic);
    } else {
      await subscribeTopic(c.env, user.id, body.topic as PushTopic);
    }
    return c.json({ subscribed: body.enabled !== false });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Subscribe failed';
    return c.json({ error: { code: 'SUBSCRIBE_FAILED', message } }, 500);
  }
});

/** GET /api/push/log — view recent push history for the user. */
pushRoutes.get('/log', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('push_log')
    .select('id, topic, payload, status, sent_at')
    .eq('user_id', user.id)
    .order('sent_at', { ascending: false })
    .limit(50);
  if (error) {
    return c.json({ error: { code: 'LIST_FAILED', message: error.message } }, 500);
  }
  return c.json({ pushes: data ?? [] });
});

/** POST /api/push/send (admin only) — manual push to topic. */
pushRoutes.post('/send', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  let body: { topic?: string; title?: string; body?: string; userId?: string; data?: Record<string, string> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.topic || !body.title || !body.body) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'topic, title, body required' } }, 400);
  }
  if (body.userId) {
    await sendToUser(c.env, body.userId, {
      topic: body.topic as PushTopic,
      title: body.title,
      body: body.body,
      data: body.data,
    });
    return c.json({ sent: 1 });
  }
  const result = await sendToTopic(c.env, {
    topic: body.topic as PushTopic,
    title: body.title,
    body: body.body,
    data: body.data,
  });
  return c.json(result);
});