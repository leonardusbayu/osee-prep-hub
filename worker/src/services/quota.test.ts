import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock Supabase
const mockFrom = vi.fn();
const mockRpc = vi.fn();
vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({ from: mockFrom, rpc: mockRpc })),
}));

import { getQuotaLimit, checkQuota, getQuotaStatus, getMonthlyUsage } from './quota';
import type { Env } from '../types';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('quota service', () => {
  beforeEach(() => {
    mockFrom.mockClear();
    mockRpc.mockClear();
  });

  describe('getQuotaLimit', () => {
    function teacherMock(tier: string, earnedBonus = 0) {
      return mockFrom.mockImplementation((table: string) => {
        if (table === 'teacher_profiles') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                maybeSingle: vi.fn(async () => ({ data: { tier, tier_expires_at: null }, error: null })),
              })),
            })),
          };
        }
        if (table === 'ai_quota_usage') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                eq: vi.fn(() => ({
                  maybeSingle: vi.fn(async () => ({
                    data: { earned_bonus: earnedBonus },
                    error: null,
                  })),
                })),
              })),
            })),
          };
        }
        return {
          select: vi.fn(() => ({
            eq: vi.fn(() => ({
              gte: vi.fn(async () => ({ count: 0, error: null })),
            })),
          })),
        };
      });
    }

    it('returns -1 (unlimited) for admin', async () => {
      expect(await getQuotaLimit(mockEnv, 'admin', 'user-1', 'grading')).toBe(-1);
    });

    it('returns -1 (unlimited) for partner', async () => {
      expect(await getQuotaLimit(mockEnv, 'partner', 'user-1', 'grading')).toBe(-1);
    });

    it('returns 50 for teacher on free tier (no pro subscription, no bonus)', async () => {
      teacherMock('free');
      expect(await getQuotaLimit(mockEnv, 'teacher', 'user-1', 'grading')).toBe(50);
    });

    it('returns -1 for teacher on pro tier', async () => {
      teacherMock('pro');
      expect(await getQuotaLimit(mockEnv, 'teacher', 'user-1', 'grading')).toBe(-1);
    });

    it('returns 50 for student', async () => {
      expect(await getQuotaLimit(mockEnv, 'student', 'user-1', 'grading')).toBe(50);
    });

    it('returns 10 for student generation quota', async () => {
      expect(await getQuotaLimit(mockEnv, 'student', 'user-1', 'generation')).toBe(10);
    });

    it('adds bonus credits (passed) to teacher free-tier quota', async () => {
      teacherMock('free');
      expect(await getQuotaLimit(mockEnv, 'teacher', 'user-1', 'grading', 10)).toBe(60);
    });

    it('reads earned_bonus from DB when no bonus passed', async () => {
      teacherMock('free', 30);
      expect(await getQuotaLimit(mockEnv, 'teacher', 'user-1', 'grading')).toBe(80);
    });
  });

  describe('getMonthlyUsage', () => {
    it('counts grading queue entries this month', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 5, error: null })),
          })),
        })),
      });

      const usage = await getMonthlyUsage(mockEnv, 'user-1', 'grading');
      expect(usage).toBe(5);
    });

    it('returns 0 when count is null', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: null, error: null })),
          })),
        })),
      });

      const usage = await getMonthlyUsage(mockEnv, 'user-1', 'grading');
      expect(usage).toBe(0);
    });

    it('returns 0 when query fails (table may not exist)', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: null, error: { message: 'Table missing' } })),
          })),
        })),
      });

      const usage = await getMonthlyUsage(mockEnv, 'user-1', 'generation');
      expect(usage).toBe(0);
    });
  });

  describe('checkQuota', () => {
    // Shared mock that returns free-tier teacher profile + grading usage count.
    function freeTeacherMock(count: number, earnedBonus = 0) {
      return mockFrom.mockImplementation((table: string) => {
        if (table === 'teacher_profiles') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                maybeSingle: vi.fn(async () => ({ data: { tier: 'free' }, error: null })),
              })),
            })),
          };
        }
        if (table === 'ai_quota_usage') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                eq: vi.fn(() => ({
                  maybeSingle: vi.fn(async () => ({
                    data: { earned_bonus: earnedBonus },
                    error: null,
                  })),
                })),
              })),
            })),
          };
        }
        // ai_grading_queue
        return {
          select: vi.fn(() => ({
            eq: vi.fn(() => ({
              gte: vi.fn(async () => ({ count, error: null })),
            })),
          })),
        };
      });
    }

    it('allows request when under limit', async () => {
      freeTeacherMock(10);
      const status = await checkQuota(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.used).toBe(10);
      expect(status.limit).toBe(50);
      expect(status.remaining).toBe(40);
    });

    it('throws when quota exceeded', async () => {
      freeTeacherMock(50);
      await expect(checkQuota(mockEnv, 'user-1', 'teacher', 'grading')).rejects.toThrow(
        /Quota exceeded/
      );
    });

    it('adds earned bonus to limit', async () => {
      freeTeacherMock(10, 20);
      const status = await checkQuota(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.limit).toBe(70); // 50 base + 20 bonus
      expect(status.remaining).toBe(60);
    });

    it('never throws for admin (unlimited)', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 9999, error: null })),
          })),
        })),
      });

      const status = await checkQuota(mockEnv, 'user-1', 'admin', 'grading');
      expect(status.limit).toBe(-1);
      expect(status.remaining).toBe(-1);
    });

    it('never throws for partner (unlimited)', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 9999, error: null })),
          })),
        })),
      });

      const status = await checkQuota(mockEnv, 'user-1', 'partner', 'grading');
      expect(status.limit).toBe(-1);
    });
  });

  describe('getQuotaStatus', () => {
    function freeTeacherMock(count: number, earnedBonus = 0) {
      return mockFrom.mockImplementation((table: string) => {
        if (table === 'teacher_profiles') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                maybeSingle: vi.fn(async () => ({ data: { tier: 'free' }, error: null })),
              })),
            })),
          };
        }
        if (table === 'ai_quota_usage') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                eq: vi.fn(() => ({
                  maybeSingle: vi.fn(async () => ({
                    data: { earned_bonus: earnedBonus },
                    error: null,
                  })),
                })),
              })),
            })),
          };
        }
        return {
          select: vi.fn(() => ({
            eq: vi.fn(() => ({
              gte: vi.fn(async () => ({ count, error: null })),
            })),
          })),
        };
      });
    }

    it('returns 0 remaining when quota exceeded (instead of throwing)', async () => {
      freeTeacherMock(50);
      const status = await getQuotaStatus(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.remaining).toBe(0);
      expect(status.used).toBe(50);
    });

    it('returns proper status when under limit', async () => {
      freeTeacherMock(5);
      const status = await getQuotaStatus(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.remaining).toBe(45);
      expect(status.used).toBe(5);
    });

    it('includes earned bonus in remaining', async () => {
      freeTeacherMock(5, 30);
      const status = await getQuotaStatus(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.limit).toBe(80);
      expect(status.remaining).toBe(75);
    });
  });
});