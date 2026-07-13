import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock Supabase
const mockFrom = vi.fn();
const mockRpc = vi.fn();
vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({ from: mockFrom, rpc: mockRpc })),
}));

import {
  getAdminAnalytics,
  getAdminCommissionSummary,
  listTeachers,
  listStudents,
} from './admin-stats';
import type { Env } from '../types';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('admin-stats service', () => {
  beforeEach(() => {
    mockFrom.mockClear();
    mockRpc.mockClear();
  });

  describe('getAdminAnalytics', () => {
    it('aggregates all analytics fields with count:true where possible', async () => {
      // Mock supabase.from() chain — return chainable thenables
      const chainable = (count: number, data?: unknown[]) => {
        const handler = {
          eq: vi.fn(() => chainable(count)),
          in: vi.fn(() => chainable(count, data)),
          order: vi.fn(() => chainable(count, data)),
          limit: vi.fn(() => chainable(count, data)),
          maybeSingle: vi.fn(async () => ({ data: data?.[0] ?? null, error: null })),
        };
        // Thenable: await returns { count, data, error }
        const thenable = {
          ...handler,
          then: (resolve: (v: unknown) => void) => resolve({ count, data: data ?? [], error: null }),
        };
        return thenable;
      };

      mockFrom.mockImplementation((table: string) => {
        if (table === 'orders') {
          return {
            select: vi.fn(() => ({
              in: vi.fn(() => chainable(10, [{ total_amount: 100000 }, { total_amount: 50000 }])),
            })),
          };
        }
        if (table === 'commission_ledger') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => chainable(0, [{ amount_idr: 25000 }, { amount_idr: 5000 }])),
            })),
          };
        }
        if (table === 'commission_payouts') {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => chainable(3)),
            })),
          };
        }
        return {
          select: vi.fn(() => chainable(10)),
        };
      });

      const analytics = await getAdminAnalytics(mockEnv);
      expect(analytics.total_teachers).toBe(10);
      expect(analytics.total_students).toBe(10);
      expect(analytics.total_partners).toBe(10);
      expect(analytics.total_classrooms).toBe(10);
      expect(analytics.total_bookings).toBe(10);
      expect(analytics.total_revenue).toBe(150000);
      expect(analytics.commission_paid).toBe(30000);
      expect(analytics.commission_pending).toBe(30000);
      expect(analytics.ai_grading_count).toBe(10);
      expect(analytics.ai_generation_count).toBe(10);
      expect(analytics.active_payouts).toBe(3);
    });

    it('returns zeros when DB returns null/empty', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(async () => ({ count: null, error: null })),
          in: vi.fn(async () => ({ data: [], error: null })),
        })),
      });
      const analytics = await getAdminAnalytics(mockEnv);
      expect(analytics.total_teachers).toBe(0);
      expect(analytics.total_revenue).toBe(0);
    });

    it('throws when DB query fails', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(async () => ({ count: 0, error: { message: 'DB down' } })),
        })),
      });
      // Promise.all rejects on first error
      await expect(getAdminAnalytics(mockEnv)).rejects.toThrow();
    });
  });

  describe('getAdminCommissionSummary', () => {
    it('groups commission by teacher with totals + pending + paid', async () => {
      // First .from() call returns commission_ledger rows
      const commissionRows = [
        { status: 'paid', amount_idr: 50000, teacher_id: 't1' },
        { status: 'paid', amount_idr: 25000, teacher_id: 't1' },
        { status: 'pending', amount_idr: 10000, teacher_id: 't2' },
        { status: 'pending', amount_idr: 15000, teacher_id: 't2' },
        { status: 'confirmed', amount_idr: 5000, teacher_id: 't1' },
      ];
      let callCount = 0;
      mockFrom.mockImplementation(() => {
        callCount++;
        if (callCount === 1) {
          return {
            select: vi.fn(async () => ({ data: commissionRows, error: null })),
          };
        }
        if (callCount === 2) {
          // teacher name lookup
          return {
            select: vi.fn(() => ({
              in: vi.fn(async () => ({
                data: [
                  { id: 't1', display_name: 'Budi' },
                  { id: 't2', display_name: 'Sari' },
                ],
                error: null,
              })),
            })),
          };
        }
        // referral count
        return {
          select: vi.fn(async () => ({
            data: [{ teacher_id: 't1' }, { teacher_id: 't1' }, { teacher_id: 't2' }],
            error: null,
          })),
        };
      });

      const summary = await getAdminCommissionSummary(mockEnv);
      expect(summary.total_paid).toBe(75000);
      expect(summary.total_pending).toBe(25000);
      expect(summary.total_confirmed).toBe(5000);
      expect(summary.by_teacher).toHaveLength(2);
      // Sorted by total_earned desc — t1 (80000) before t2 (25000)
      expect(summary.by_teacher[0].teacher_name).toBe('Budi');
      expect(summary.by_teacher[0].total_earned).toBe(80000);
      expect(summary.by_teacher[0].paid).toBe(75000);
      expect(summary.by_teacher[0].student_count).toBe(2);
      expect(summary.by_teacher[1].teacher_name).toBe('Sari');
      expect(summary.by_teacher[1].total_earned).toBe(25000);
      expect(summary.by_teacher[1].pending).toBe(25000);
      expect(summary.by_teacher[1].student_count).toBe(1);
    });
  });

  describe('listTeachers', () => {
    it('joins teacher_profiles + computes student counts + earnings', async () => {
      let callCount = 0;
      mockFrom.mockImplementation(() => {
        callCount++;
        if (callCount === 1) {
          return {
            select: vi.fn(() => ({
              eq: vi.fn(() => ({
                order: vi.fn(() => ({
                  limit: vi.fn(async () => ({
                    data: [
                      {
                        id: 't1',
                        display_name: 'Budi',
                        email: 'budi@test.com',
                        target_exam: 'IELTS',
                        created_at: '2026-01-01',
                        teacher_profiles: { tier: 'pro', referral_code: 'BUDI2401' },
                      },
                    ],
                    error: null,
                  })),
                })),
              })),
            })),
          };
        }
        if (callCount === 2) {
          // teacher_referrals
          return {
            select: vi.fn(async () => ({
              data: [{ teacher_id: 't1' }, { teacher_id: 't1' }],
              error: null,
            })),
          };
        }
        // commission_ledger
        return {
          select: vi.fn(async () => ({
            data: [
              { teacher_id: 't1', amount_idr: 50000 },
              { teacher_id: 't1', amount_idr: 25000 },
            ],
            error: null,
          })),
        };
      });

      const teachers = await listTeachers(mockEnv);
      expect(teachers).toHaveLength(1);
      expect(teachers[0].display_name).toBe('Budi');
      expect(teachers[0].tier).toBe('pro');
      expect(teachers[0].referral_code).toBe('BUDI2401');
      expect(teachers[0].total_students).toBe(2);
      expect(teachers[0].total_earnings).toBe(75000);
    });

    it('returns empty array when no teachers', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            order: vi.fn(() => ({
              limit: vi.fn(async () => ({ data: [], error: null })),
            })),
          })),
        })),
      });
      const teachers = await listTeachers(mockEnv);
      expect(teachers).toEqual([]);
    });
  });

  describe('listStudents', () => {
    it('joins student_progress_unified for score fields', async () => {
      mockFrom.mockReturnValue({
        select: vi.fn(() => ({
          eq: vi.fn(() => ({
            order: vi.fn(() => ({
              limit: vi.fn(async () => ({
                data: [
                  {
                    id: 's1',
                    display_name: 'Andi',
                    email: 'andi@test.com',
                    target_exam: 'TOEFL_IBT',
                    current_level: 'B2',
                    referred_by: 't1',
                    created_at: '2026-02-01',
                    student_progress_unified: {
                      ibt_latest_score: 87,
                      ielts_latest_band: 6.5,
                    },
                  },
                ],
                error: null,
              })),
            })),
          })),
        })),
      });
      const students = await listStudents(mockEnv);
      expect(students).toHaveLength(1);
      expect(students[0].display_name).toBe('Andi');
      expect(students[0].ibt_latest_score).toBe(87);
      expect(students[0].ielts_latest_band).toBe(6.5);
      expect(students[0].referred_by).toBe('t1');
    });
  });
});