import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock Supabase — the factory returns a fresh chain each time from() is called
const mockFrom = vi.fn();
vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({ from: mockFrom })),
}));

import { generateUniqueJoinCode } from './classroom';

/** Build a mock Supabase client that returns the given data on maybeSingle(). */
function makeMockSupabase(maybeSingleData: unknown) {
  const chain = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    maybeSingle: vi.fn(async () => ({ data: maybeSingleData, error: null })),
  };
  return {
    from: vi.fn(() => chain),
  } as unknown as import('@supabase/supabase-js').SupabaseClient;
}

describe('classroom service — join code generation', () => {
  beforeEach(() => {
    mockFrom.mockClear();
  });

  it('generates a 6-char join code with valid characters (no collision)', async () => {
    const supabase = makeMockSupabase(null);
    const code = await generateUniqueJoinCode(supabase);
    expect(code).toHaveLength(6);
    expect(code).toMatch(/^[A-HJ-NP-Z2-9]{6}$/);
  });

  it('retries on collision until unique found', async () => {
    let callCount = 0;
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      maybeSingle: vi.fn(async () => {
        callCount++;
        return {
          data: callCount <= 1 ? { id: 'existing' } : null,
          error: null,
        };
      }),
    };
    const supabase = {
      from: vi.fn(() => chain),
    } as unknown as import('@supabase/supabase-js').SupabaseClient;

    const code = await generateUniqueJoinCode(supabase);
    expect(code).toHaveLength(6);
    expect(code).toMatch(/^[A-HJ-NP-Z2-9]{6}$/);
    expect(callCount).toBe(2);
  });

  it('throws after 20 failed attempts (always collides)', async () => {
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      maybeSingle: vi.fn(async () => ({ data: { id: 'always-exists' }, error: null })),
    };
    const supabase = {
      from: vi.fn(() => chain),
    } as unknown as import('@supabase/supabase-js').SupabaseClient;

    await expect(generateUniqueJoinCode(supabase)).rejects.toThrow(/Failed to generate unique/);
  });

  it('generates different codes on subsequent calls (randomness)', async () => {
    const supabase = makeMockSupabase(null);
    const code1 = await generateUniqueJoinCode(supabase);
    const code2 = await generateUniqueJoinCode(supabase);
    expect(code1).not.toBe(code2);
  });
});