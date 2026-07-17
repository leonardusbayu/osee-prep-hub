import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Env } from '../types';

// Use vi.hoisted so mock variables are available inside hoisted vi.mock factories.
const hoisted = vi.hoisted(() => {
  const updateStudentProgress = vi.fn(async () => {});
  const recordCommission = vi.fn(async () => {});
  const awardQuotaBonus = vi.fn(async () => {});
  // Configurable chain plan shared between mock factory and tests.
  const chainPlan: Array<{ data?: unknown; error?: unknown }> = [];
  const fetchMock = vi.fn(async () => new Response('{}', { status: 200 }));
  return { updateStudentProgress, recordCommission, awardQuotaBonus, chainPlan, fetchMock };
});

vi.mock('../services/student-progress', () => ({ updateStudentProgress: hoisted.updateStudentProgress }));
vi.mock('../services/commission', () => ({ recordCommission: hoisted.recordCommission }));
vi.mock('../services/quota', () => ({ awardQuotaBonus: hoisted.awardQuotaBonus }));
vi.stubGlobal('fetch', hoisted.fetchMock);

// Supabase mock: factory builds chains that drain from chainPlan.
vi.mock('../services/supabase', () => {
  const consume = () => hoisted.chainPlan.shift() ?? { data: null, error: null };
  const makeChain = () => {
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      neq: vi.fn(() => chain),
      order: vi.fn(() => chain),
      limit: vi.fn(async () => consume()),
      maybeSingle: vi.fn(async () => consume()),
      single: vi.fn(async () => consume()),
      insert: vi.fn(() => chain),
      update: vi.fn(() => chain),
    };
    return chain;
  };
  return { getSupabase: vi.fn(() => ({ from: vi.fn(() => makeChain()) })) };
});

import { processWebhookBatch } from './webhook-processor';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
  EDUBOT_API_URL: 'https://edubot.test',
  EDUBOT_INTERNAL_SECRET: 'secret',
  TELEGRAM_BOT_TOKEN: 'tg-token',
} as unknown as Env;

function makeEvent(over: Partial<{
  id: string; platform: string; event_type: string;
  user_email: string | null; user_id: string | null;
  payload: Record<string, unknown>; created_at: string;
}> = {}) {
  return {
    id: 'evt-1',
    platform: 'ibt',
    event_type: 'test_completed',
    user_email: 'student@test.com',
    user_id: null,
    payload: { score: 85, total_score: 120 },
    created_at: new Date().toISOString(),
    ...over,
  };
}

describe('webhook-processor', () => {
  beforeEach(() => {
    hoisted.updateStudentProgress.mockClear();
    hoisted.recordCommission.mockClear();
    hoisted.awardQuotaBonus.mockClear();
    hoisted.fetchMock.mockClear();
    hoisted.chainPlan.length = 0;
  });

  it('returns empty result when no events', async () => {
    hoisted.chainPlan.push({ data: [], error: null });
    const r = await processWebhookBatch(mockEnv);
    expect(r).toEqual({ total: 0, succeeded: 0, failed: 0, errors: [] });
  });

  it('throws on fetch error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'db down' } });
    await expect(processWebhookBatch(mockEnv)).rejects.toThrow(/Failed to fetch webhook events/);
  });

  it('fails event when user cannot be resolved', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: null, user_email: 'x@y.com' })], error: null });
    hoisted.chainPlan.push({ data: null, error: null }); // user lookup
    hoisted.chainPlan.push({ data: null, error: null }); // markProcessed
    const r = await processWebhookBatch(mockEnv);
    expect(r.total).toBe(1);
    expect(r.failed).toBe(1);
    expect(r.succeeded).toBe(0);
    expect(r.errors[0].error).toMatch(/Could not resolve user/);
  });

  it('processes test_completed: progress + commission + bonus + telegram notify', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-1', event_type: 'test_completed' })], error: null });
    hoisted.chainPlan.push({ data: { referred_by: 'teacher-1' }, error: null });
    hoisted.chainPlan.push({ data: { target_exam: 'TOEFL_IBT', target_score: { overall: 100 }, telegram_id: 'tg-1' }, error: null });
    hoisted.chainPlan.push({ data: null, error: null }); // readiness update
    hoisted.chainPlan.push({ data: null, error: null }); // markProcessed

    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
    expect(r.failed).toBe(0);
    expect(hoisted.updateStudentProgress).toHaveBeenCalledWith(mockEnv, expect.objectContaining({ user_id: 'stu-1' }));
    expect(hoisted.recordCommission).toHaveBeenCalled();
    expect(hoisted.awardQuotaBonus).toHaveBeenCalledWith(mockEnv, 'teacher-1', 'test_completed');
    expect(hoisted.fetchMock).toHaveBeenCalledWith(
      'https://edubot.test/api/hub-progress-update',
      expect.objectContaining({ method: 'POST' })
    );
    const calls = hoisted.fetchMock.mock.calls as unknown as string[][];
    const tgCall = calls.find((c) => String(c[0]).includes('api.telegram.org'));
    expect(tgCall).toBeTruthy();
  });

  it('test_booked triggers commission + booking bonus (no progress update)', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-2', event_type: 'test_booked' })], error: null });
    hoisted.chainPlan.push({ data: { referred_by: 'teacher-2' }, error: null });
    hoisted.chainPlan.push({ data: null, error: null });

    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
    expect(hoisted.awardQuotaBonus).toHaveBeenCalledWith(mockEnv, 'teacher-2', 'official_booking');
    expect(hoisted.updateStudentProgress).not.toHaveBeenCalled();
  });

  it('premium_subscribed triggers commission + premium bonus', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-3', event_type: 'premium_subscribed', platform: 'edubot' })], error: null });
    hoisted.chainPlan.push({ data: { referred_by: 'teacher-3' }, error: null });
    hoisted.chainPlan.push({ data: null, error: null });

    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
    expect(hoisted.awardQuotaBonus).toHaveBeenCalledWith(mockEnv, 'teacher-3', 'premium_subscribed');
  });

  it('booking_confirmed is a no-op', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-4', event_type: 'booking_confirmed' })], error: null });
    hoisted.chainPlan.push({ data: null, error: null });
    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
    expect(hoisted.recordCommission).not.toHaveBeenCalled();
  });

  it('bot_session_started is a no-op', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-5', event_type: 'bot_session_started' })], error: null });
    hoisted.chainPlan.push({ data: null, error: null });
    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
  });

  it('unknown event_type still succeeds', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-6', event_type: 'mystery_event' })], error: null });
    hoisted.chainPlan.push({ data: null, error: null });
    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
  });

  it('skips commission when student has no referring teacher', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-7', event_type: 'test_completed' })], error: null });
    hoisted.chainPlan.push({ data: { referred_by: null }, error: null });
    hoisted.chainPlan.push({ data: null, error: null }); // readiness profile
    hoisted.chainPlan.push({ data: null, error: null }); // readiness update
    hoisted.chainPlan.push({ data: null, error: null }); // markProcessed
    const r = await processWebhookBatch(mockEnv);
    expect(r.succeeded).toBe(1);
    expect(hoisted.recordCommission).not.toHaveBeenCalled();
    expect(hoisted.awardQuotaBonus).not.toHaveBeenCalled();
  });

  it('does not notify telegram when readiness below 80%', async () => {
    hoisted.chainPlan.push({ data: [makeEvent({ user_id: 'stu-8', event_type: 'test_completed', payload: { score: 50, total_score: 100 } })], error: null });
    hoisted.chainPlan.push({ data: { referred_by: 'teacher-8' }, error: null });
    hoisted.chainPlan.push({ data: { target_exam: 'TOEFL_IBT', target_score: { overall: 100 }, telegram_id: 'tg-8' }, error: null });
    hoisted.chainPlan.push({ data: null, error: null }); // readiness update
    hoisted.chainPlan.push({ data: null, error: null }); // markProcessed

    await processWebhookBatch(mockEnv);
    const calls = hoisted.fetchMock.mock.calls as unknown as string[][];
    const tgCall = calls.find((c) => String(c[0]).includes('api.telegram.org'));
    expect(tgCall).toBeUndefined();
  });
});