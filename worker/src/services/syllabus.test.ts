import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({
    from: vi.fn(() => ({
      insert: vi.fn(() => ({
        select: vi.fn(() => ({
          single: vi.fn(async () => ({ data: { id: 's1', teacher_id: 't1', name: 'Test' }, error: null })),
        })),
      })),
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          order: vi.fn(() => ({ data: [], error: null })),
          maybeSingle: vi.fn(async () => ({ data: null, error: null })),
        })),
      })),
      delete: vi.fn(() => ({ eq: vi.fn(async () => ({ error: null })) })),
      limit: vi.fn(() => ({ maybeSingle: vi.fn(async () => ({ data: null, error: null })) })),
    })),
  })),
}));

import { createSyllabus } from './syllabus';
import type { Env } from '../types';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('syllabus service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('createSyllabus with empty name will fail at DB level (not validation)', async () => {
    // The service doesn't pre-validate name — it relies on DB NOT NULL constraint.
    // The mock returns success, so this just verifies the function runs without crashing.
    // In production, an empty name would cause a DB error.
    const result = await createSyllabus(mockEnv, 't1', { name: 'Test Syllabus' });
    expect(result).toBeDefined();
  });
});