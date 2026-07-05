import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock Supabase
vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          maybeSingle: vi.fn(async () => ({ data: null, error: null })),
          order: vi.fn(() => ({
            limit: vi.fn(async () => ({ data: [], error: null })),
          })),
        })),
        in: vi.fn(async () => ({ data: [], error: null })),
      })),
      insert: vi.fn(() => ({
        select: vi.fn(() => ({ single: vi.fn(async () => ({ data: { id: 'test-id' }, error: null })) })),
      })),
      delete: vi.fn(() => ({ eq: vi.fn(async () => ({ error: null })) })),
    })),
  })),
}));

import { generateStudentReport, generateClassroomReport } from './reports';
import type { Env } from '../types';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('reports service — input validation', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('generateStudentReport rejects empty studentId', async () => {
    await expect(generateStudentReport(mockEnv, 'teacher-1', '')).rejects.toThrow();
  });

  it('generateClassroomReport rejects empty classroomId', async () => {
    await expect(generateClassroomReport(mockEnv, 'teacher-1', '')).rejects.toThrow();
  });
});