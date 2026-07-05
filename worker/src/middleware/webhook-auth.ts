import type { Context } from 'hono';
import type { Env, ContextVars } from '../types';

/**
 * Webhook secret authentication middleware.
 * Each platform has its own secret env var (WEBHOOK_SECRET_IBT, etc.).
 * Verifies X-Webhook-Secret header against the expected secret.
 *
 * Usage: app.post('/api/webhook/ibt', webhookAuth('ibt'), handler)
 */
export function webhookAuth(platform: 'ibt' | 'itp' | 'ielts' | 'toeic' | 'booking' | 'edubot') {
  return async (c: Context<{ Bindings: Env; Variables: ContextVars }>, next: () => Promise<void>): Promise<Response | void> => {
    const provided = c.req.header('X-Webhook-Secret');
    if (!provided) {
      return c.json(
        { error: { code: 'MISSING_SECRET', message: 'X-Webhook-Secret header required' } },
        401
      );
    }

    const expected = getExpectedSecret(c.env, platform);
    if (!expected) {
      console.error(`Webhook secret not configured for platform: ${platform}`);
      return c.json(
        { error: { code: 'SECRET_NOT_CONFIGURED', message: 'Webhook secret not set on server' } },
        500
      );
    }

    // Constant-time comparison to prevent timing attacks
    if (!constantTimeEqual(provided, expected)) {
      return c.json(
        { error: { code: 'INVALID_SECRET', message: 'Invalid webhook secret' } },
        401
      );
    }

    await next();
  };
}

/** Get the expected secret for a platform from env. */
function getExpectedSecret(env: Env, platform: 'ibt' | 'itp' | 'ielts' | 'toeic' | 'booking' | 'edubot'): string | null {
  const map: Record<typeof platform, keyof Env> = {
    ibt: 'WEBHOOK_SECRET_IBT',
    itp: 'WEBHOOK_SECRET_ITP',
    ielts: 'WEBHOOK_SECRET_IELTS',
    toeic: 'WEBHOOK_SECRET_TOEIC',
    booking: 'WEBHOOK_SECRET_BOOKING',
    edubot: 'WEBHOOK_SECRET_EDUBOT',
  };
  const value = env[map[platform]] as string | undefined;
  return value && value.length > 0 ? value : null;
}

/** Constant-time string comparison. */
function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}