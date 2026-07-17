import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Env } from '../types';

const hoisted = vi.hoisted(() => {
  const chainPlan: Array<{ data?: unknown; error?: unknown }> = [];
  return { chainPlan };
});

vi.mock('../services/supabase', () => {
  const consume = () => hoisted.chainPlan.shift() ?? { data: null, error: null };
  const makeChain = () => {
    let consumed: { data?: unknown; error?: unknown } | null = null;
    const getResolved = () => (consumed ??= consume());
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      neq: vi.fn(() => chain),
      order: vi.fn(() => chain),
      insert: vi.fn(() => chain),
      update: vi.fn(() => chain),
      delete: vi.fn(() => chain),
      upsert: vi.fn(() => chain),
      limit: vi.fn(() => chain),
      maybeSingle: vi.fn(async () => getResolved()),
      single: vi.fn(async () => getResolved()),
      get data() { return getResolved().data; },
      get error() { return getResolved().error; },
    };
    // chain is thenable so `await chain` returns resolved value too.
    (chain as unknown as { then: (resolve: (v: unknown) => unknown) => Promise<unknown> }).then =
      (resolve) => Promise.resolve(getResolved()).then(resolve);
    return chain;
  };
  return { getSupabase: vi.fn(() => ({ from: vi.fn(() => makeChain()) })) };
});

import { getPrice, getPricingForRole, setPrice, listAllPricing, deactivatePrice } from './pricing';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('pricing service', () => {
  beforeEach(() => {
    hoisted.chainPlan.length = 0;
  });

  it('setPrice rejects negative prices', async () => {
    await expect(setPrice(mockEnv, 'mock_ibt', 'teacher', -100)).rejects.toThrow(/negative/i);
  });

  it('setPrice accepts zero (free)', async () => {
    hoisted.chainPlan.push({ data: null, error: null });
    await setPrice(mockEnv, 'mock_ibt', 'admin', 0);
  });

  it('setPrice throws on db error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'constraint' } });
    await expect(setPrice(mockEnv, 'mock_ibt', 'teacher', 50000)).rejects.toThrow(/Set price failed/);
  });

  it('getPrice returns role-specific price when present', async () => {
    hoisted.chainPlan.push({ data: { price: 120000 }, error: null });
    const p = await getPrice(mockEnv, 'mock_ibt', 'teacher');
    expect(p).toBe(120000);
  });

  it('getPrice returns null on query error (warns, does not throw)', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'rls' } });
    const p = await getPrice(mockEnv, 'mock_ibt', 'teacher');
    expect(p).toBeNull();
  });

  it('getPrice falls back to student price for non-student role', async () => {
    hoisted.chainPlan.push({ data: { price: null }, error: null }); // role-specific null
    hoisted.chainPlan.push({ data: { price: 150000 }, error: null }); // student fallback
    const p = await getPrice(mockEnv, 'mock_ibt', 'teacher');
    expect(p).toBe(150000);
  });

  it('getPrice does not fallback when role is student', async () => {
    hoisted.chainPlan.push({ data: { price: null }, error: null });
    const p = await getPrice(mockEnv, 'mock_ibt', 'student');
    expect(p).toBeNull();
  });

  it('getPricingForRole returns map of item_type→price', async () => {
    hoisted.chainPlan.push({
      data: [{ item_type: 'mock_ibt', price: 120000 }, { item_type: 'mock_itp', price: 60000 }],
      error: null,
    });
    // No student fallback needed since all items present
    hoisted.chainPlan.push({ data: [{ item_type: 'mock_ibt', price: 150000 }, { item_type: 'mock_ielts', price: 150000 }], error: null });
    const r = await getPricingForRole(mockEnv, 'teacher');
    expect(r.mock_ibt).toBe(120000);
    expect(r.mock_itp).toBe(60000);
    // ielts missing from teacher → filled with student price
    expect(r.mock_ielts).toBe(150000);
  });

  it('getPricingForRole returns {} on query error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'db down' } });
    const r = await getPricingForRole(mockEnv, 'teacher');
    expect(r).toEqual({});
  });

  it('listAllPricing returns rows or throws on error', async () => {
    hoisted.chainPlan.push({
      data: [{ item_type: 'mock_ibt', role: 'student', price: 150000 }],
      error: null,
    });
    const rows = await listAllPricing(mockEnv);
    expect(rows).toHaveLength(1);
  });

  it('listAllPricing throws on db error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'x' } });
    await expect(listAllPricing(mockEnv)).rejects.toThrow(/List pricing failed/);
  });

  it('deactivatePrice returns true when a row was matched', async () => {
    hoisted.chainPlan.push({ data: { id: 'pc-1' }, error: null });
    const ok = await deactivatePrice(mockEnv, 'mock_ibt', 'teacher');
    expect(ok).toBe(true);
  });

  it('deactivatePrice returns false when no row matched', async () => {
    hoisted.chainPlan.push({ data: null, error: null });
    const ok = await deactivatePrice(mockEnv, 'mock_ibt', 'teacher');
    expect(ok).toBe(false);
  });

  it('deactivatePrice throws on db error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'rls' } });
    await expect(deactivatePrice(mockEnv, 'mock_ibt', 'teacher')).rejects.toThrow(/Deactivate price failed/);
  });
});