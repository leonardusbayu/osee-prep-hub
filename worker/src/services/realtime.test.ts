/**
 * Realtime service tests — Task 2 (Wave 1).
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { canAccessSyllabus } from './realtime';

vi.mock('./supabase', () => ({
  getSupabase: vi.fn(),
}));

describe('realtime service', () => {
  beforeEach(() => vi.clearAllMocks());

  it('canAccessSyllabus returns owner role when teacher_id matches', async () => {
    const { getSupabase } = await import('./supabase');
    const chain: any = {
      from: vi.fn(() => {
        const c: any = { select: () => c, eq: () => c, single: async () => ({ data: { teacher_id: 'u1' }, error: null }) };
        return c;
      }),
    };
    (getSupabase as any).mockReturnValue(chain);

    const result = await canAccessSyllabus({} as never, 'u1', 's1');
    expect(result).toEqual({ allowed: true, role: 'owner' });
  });

  it('canAccessSyllabus returns false when not owner or collaborator', async () => {
    const { getSupabase } = await import('./supabase');
    const chain: any = {
      from: vi.fn(() => {
        const c: any = { select: () => c, eq: () => c, single: async () => ({ data: null, error: null }) };
        return c;
      }),
    };
    (getSupabase as any).mockReturnValue(chain);

    const result = await canAccessSyllabus({} as never, 'uX', 's1');
    expect(result).toEqual({ allowed: false });
  });
});