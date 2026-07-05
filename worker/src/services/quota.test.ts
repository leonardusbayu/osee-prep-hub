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
    it('returns -1 (unlimited) for admin', () => {
      expect(getQuotaLimit('admin')).toBe(-1);
    });

    it('returns -1 (unlimited) for partner', () => {
      expect(getQuotaLimit('partner')).toBe(-1);
    });

    it('returns 50 for teacher (free tier default)', () => {
      expect(getQuotaLimit('teacher')).toBe(50);
    });

    it('returns 50 for student', () => {
      expect(getQuotaLimit('student')).toBe(50);
    });

    it('adds bonus credits to teacher quota', () => {
      expect(getQuotaLimit('teacher', 10)).toBe(60);
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
    it('allows request when under limit', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 10, error: null })),
          })),
        })),
      });

      const status = await checkQuota(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.used).toBe(10);
      expect(status.limit).toBe(50);
      expect(status.remaining).toBe(40);
    });

    it('throws when quota exceeded', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 50, error: null })),
          })),
        })),
      });

      await expect(checkQuota(mockEnv, 'user-1', 'teacher', 'grading')).rejects.toThrow(
        /Quota exceeded/
      );
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
    it('returns 0 remaining when quota exceeded (instead of throwing)', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 50, error: null })),
          })),
        })),
      });

      const status = await getQuotaStatus(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.remaining).toBe(0);
      expect(status.used).toBe(50);
    });

    it('returns proper status when under limit', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            gte: vi.fn(async () => ({ count: 5, error: null })),
          })),
        })),
      });

      const status = await getQuotaStatus(mockEnv, 'user-1', 'teacher', 'grading');
      expect(status.remaining).toBe(45);
      expect(status.used).toBe(5);
    });
  });
});