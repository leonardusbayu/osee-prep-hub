import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { webhookAuth } from '../middleware/webhook-auth';
import { rateLimit } from '../middleware/rate-limit';
import { getSupabase } from '../services/supabase';

export const webhookRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// Per-platform, per-IP rate limit: burst 60, sustained 1/sec.
const webhookRateLimit = rateLimit({
  key: (c) => `${c.req.path}:${c.req.header('cf-connecting-ip') ?? 'unknown'}`,
  capacity: 60,
  refillPerSecond: 1,
});

// ---------- Webhook event validation ----------

interface WebhookPayload {
  event_type: string;
  student_id?: string;
  user_email?: string;
  timestamp?: string;
  data?: Record<string, unknown>;
}

function validatePayload(body: unknown): { ok: true; payload: WebhookPayload } | { ok: false; error: string } {
  if (typeof body !== 'object' || body === null) {
    return { ok: false, error: 'Body must be a JSON object' };
  }
  const obj = body as Record<string, unknown>;
  if (typeof obj.event_type !== 'string' || obj.event_type.length === 0) {
    return { ok: false, error: 'event_type (string) required' };
  }
  // student_id OR user_email required (some platforms send email, some send id)
  if (!obj.student_id && !obj.user_email) {
    return { ok: false, error: 'student_id or user_email required' };
  }
  return {
    ok: true,
    payload: {
      event_type: obj.event_type,
      student_id: typeof obj.student_id === 'string' ? obj.student_id : undefined,
      user_email: typeof obj.user_email === 'string' ? obj.user_email : undefined,
      timestamp: typeof obj.timestamp === 'string' ? obj.timestamp : new Date().toISOString(),
      data: (obj.data as Record<string, unknown>) ?? {},
    },
  };
}

/** Store webhook event in webhook_events table. Returns the inserted row ID. */
async function storeWebhookEvent(
  env: Env,
  platform: string,
  payload: WebhookPayload
): Promise<string> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('webhook_events')
    .insert({
      platform,
      event_type: payload.event_type,
      user_email: payload.user_email ?? null,
      user_id: payload.student_id ?? null,
      payload: {
        ...payload.data,
        _event_type: payload.event_type,
        _timestamp: payload.timestamp,
      },
      processed: false,
    })
    .select('id')
    .single();

  if (error || !data) {
    console.error('Failed to store webhook event:', error);
    throw new Error(`Failed to store webhook event: ${error?.message ?? 'unknown'}`);
  }
  return data.id as string;
}

// ---------- Endpoints (one per platform) ----------

/**
 * All 6 webhook endpoints follow the same pattern:
 * 1. Verify secret via middleware
 * 2. Validate payload structure
 * 3. Store in webhook_events table (processed=false)
 * 4. Return 202 Accepted (async processing)
 */

webhookRoutes.post('/ibt', webhookRateLimit, webhookAuth('ibt'), async (c) => {
  return handleWebhook(c, 'ibt');
});

webhookRoutes.post('/itp', webhookRateLimit, webhookAuth('itp'), async (c) => {
  return handleWebhook(c, 'itp');
});

webhookRoutes.post('/ielts', webhookRateLimit, webhookAuth('ielts'), async (c) => {
  return handleWebhook(c, 'ielts');
});

webhookRoutes.post('/toeic', webhookRateLimit, webhookAuth('toeic'), async (c) => {
  return handleWebhook(c, 'toeic');
});

webhookRoutes.post('/booking', webhookRateLimit, webhookAuth('booking'), async (c) => {
  return handleWebhook(c, 'booking');
});

webhookRoutes.post('/edubot', webhookRateLimit, webhookAuth('edubot'), async (c) => {
  return handleWebhook(c, 'edubot');
});

// ---------- Internal processing trigger ----------

/**
 * POST /api/webhook/process — internal endpoint to process queued events.
 * Triggered by the cron trigger in wrangler.toml. Guarded by an
 * X-Internal-Secret header checked against EDUBOT_INTERNAL_SECRET so only
 * the Cloudflare cron (or an admin with the secret) can trigger batch
 * processing — not an anonymous caller.
 */
webhookRoutes.post('/process', async (c) => {
  const provided = c.req.header('X-Internal-Secret');
  const expected = c.env.EDUBOT_INTERNAL_SECRET;
  if (!expected) {
    return c.json({ error: { code: 'SECRET_NOT_CONFIGURED', message: 'EDUBOT_INTERNAL_SECRET not set' } }, 500);
  }
  if (!provided || provided !== expected) {
    return c.json({ error: { code: 'UNAUTHORIZED', message: 'Invalid or missing X-Internal-Secret' } }, 401);
  }
  try {
    const { processWebhookBatch } = await import('../services/webhook-processor');
    const result = await processWebhookBatch(c.env, 100);
    return c.json({
      total: result.total,
      succeeded: result.succeeded,
      failed: result.failed,
      errors: result.errors,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Processing failed';
    return c.json({ error: { code: 'PROCESSING_FAILED', message } }, 500);
  }
});

// ---------- Handler function ----------

async function handleWebhook(c: import('hono').Context<{ Bindings: Env; Variables: ContextVars }>, platform: string): Promise<Response> {
  let body: unknown;
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON body' } }, 400);
  }

  const validation = validatePayload(body);
  if (!validation.ok) {
    return c.json({ error: { code: 'INVALID_PAYLOAD', message: validation.error } }, 400);
  }

  try {
    const eventId = await storeWebhookEvent(c.env, platform, validation.payload);
    return c.json(
      {
        accepted: true,
        event_id: eventId,
        platform,
        event_type: validation.payload.event_type,
      },
      202
    );
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Storage failed';
    return c.json({ error: { code: 'STORE_FAILED', message } }, 500);
  }
}