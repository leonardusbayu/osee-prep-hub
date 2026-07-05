import { describe, it, expect } from 'vitest';
import { webhookAuth } from './webhook-auth';
import type { Env, ContextVars } from '../types';

// Mock Hono context for testing middleware in isolation
function mockContext(secret: string | undefined, providedSecret: string | undefined) {
  const headers: Record<string, string | undefined> = {
    'X-Webhook-Secret': providedSecret,
  };
  return {
    req: {
      header: (name: string) => headers[name],
    },
    env: { WEBHOOK_SECRET_IBT: secret } as unknown as Env,
    json: (body: unknown, status: number) => new Response(JSON.stringify(body), { status }),
  } as unknown as import('hono').Context<{ Bindings: Env; Variables: ContextVars }>;
}

describe('webhook-auth middleware', () => {
  it('rejects missing X-Webhook-Secret header', async () => {
    const middleware = webhookAuth('ibt');
    const ctx = mockContext('server-secret', undefined);
    const next = vi.fn();
    const result = await middleware(ctx, next);
    expect(result).toBeInstanceOf(Response);
    expect((result as Response).status).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('rejects wrong secret', async () => {
    const middleware = webhookAuth('ibt');
    const ctx = mockContext('correct-secret', 'wrong-secret');
    const next = vi.fn();
    const result = await middleware(ctx, next);
    expect((result as Response).status).toBe(401);
    expect(next).not.toHaveBeenCalled();
  });

  it('accepts correct secret', async () => {
    const middleware = webhookAuth('ibt');
    const ctx = mockContext('correct-secret', 'correct-secret');
    const next = vi.fn(async () => {});
    const result = await middleware(ctx, next);
    expect(result).toBeUndefined(); // passed through to next()
    expect(next).toHaveBeenCalled();
  });

  it('returns 500 if server secret not configured', async () => {
    const middleware = webhookAuth('ibt');
    const ctx = mockContext(undefined, 'any-secret');
    const next = vi.fn();
    const result = await middleware(ctx, next);
    expect((result as Response).status).toBe(500);
    expect(next).not.toHaveBeenCalled();
  });
});

// Webhook payload validation logic (extracted for testability)
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

describe('webhook payload validation', () => {
  it('accepts valid payload with student_id', () => {
    const result = validatePayload({
      event_type: 'practice_completed',
      student_id: 'uuid-123',
      data: { score: 85 },
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.payload.event_type).toBe('practice_completed');
      expect(result.payload.student_id).toBe('uuid-123');
    }
  });

  it('accepts valid payload with user_email (no student_id)', () => {
    const result = validatePayload({
      event_type: 'test_booked',
      user_email: 'student@test.com',
    });
    expect(result.ok).toBe(true);
  });

  it('rejects non-object body', () => {
    expect(validatePayload(null).ok).toBe(false);
    expect(validatePayload('string').ok).toBe(false);
    expect(validatePayload(123).ok).toBe(false);
  });

  it('rejects missing event_type', () => {
    const result = validatePayload({ student_id: 'uuid-123' });
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('event_type');
  });

  it('rejects empty event_type', () => {
    const result = validatePayload({ event_type: '', student_id: 'uuid-123' });
    expect(result.ok).toBe(false);
  });

  it('rejects missing student_id AND user_email', () => {
    const result = validatePayload({ event_type: 'practice_completed' });
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toContain('student_id or user_email');
  });

  it('defaults timestamp to now if not provided', () => {
    const result = validatePayload({
      event_type: 'test',
      student_id: 'uuid',
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.payload.timestamp).toBeDefined();
      // ISO timestamp format
      expect(result.payload.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T/);
    }
  });

  it('defaults data to empty object if not provided', () => {
    const result = validatePayload({
      event_type: 'test',
      student_id: 'uuid',
    });
    expect(result.ok).toBe(true);
    if (result.ok) {
      expect(result.payload.data).toEqual({});
    }
  });
});

// Need vi import for the mocks above
import { vi } from 'vitest';