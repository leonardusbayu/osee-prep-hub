import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

const mockSelect = vi.fn();
const mockUpdate = vi.fn();

vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({
    from: vi.fn(() => ({
      select: mockSelect,
      update: mockUpdate,
    })),
  })),
}));

import { validateVoucher, redeemVoucher } from './voucher';
import type { Env } from '../types';

const mockEnv = {
  EDUBOT_INTERNAL_SECRET: 'test-secret',
} as unknown as Env;

describe('voucher service', () => {
  beforeEach(() => {
    mockFetch.mockClear();
    mockSelect.mockClear();
    mockUpdate.mockClear();
  });

  it('validateVoucher returns valid for active voucher', async () => {
    const futureDate = new Date();
    futureDate.setFullYear(futureDate.getFullYear() + 1);
    mockSelect.mockReturnValueOnce({
      eq: vi.fn(() => ({
        maybeSingle: vi.fn(async () => ({
          data: {
            item_type: 'mock_ibt',
            status: 'active',
            expires_at: futureDate.toISOString(),
            order_items: { assigned_student_id: null },
          },
          error: null,
        })),
      })),
    });

    const result = await validateVoucher(mockEnv, 'TESTVOUCHER1');
    expect(result.valid).toBe(true);
    expect(result.item_type).toBe('mock_ibt');
  });

  it('validateVoucher returns invalid for expired voucher', async () => {
    const pastDate = new Date();
    pastDate.setFullYear(pastDate.getFullYear() - 1);
    mockSelect.mockReturnValueOnce({
      eq: vi.fn(() => ({
        maybeSingle: vi.fn(async () => ({
          data: {
            item_type: 'mock_ibt',
            status: 'active',
            expires_at: pastDate.toISOString(),
            order_items: { assigned_student_id: null },
          },
          error: null,
        })),
      })),
    });

    const result = await validateVoucher(mockEnv, 'EXPIRED1');
    expect(result.valid).toBe(false);
  });

  it('validateVoucher returns invalid for redeemed voucher', async () => {
    mockSelect.mockReturnValueOnce({
      eq: vi.fn(() => ({
        maybeSingle: vi.fn(async () => ({
          data: {
            item_type: 'mock_ibt',
            status: 'redeemed',
            expires_at: null,
            order_items: null,
          },
          error: null,
        })),
      })),
    });

    const result = await validateVoucher(mockEnv, 'REDEEMED1');
    expect(result.valid).toBe(false);
  });

  it('validateVoucher returns invalid for non-existent code', async () => {
    mockSelect.mockReturnValueOnce({
      eq: vi.fn(() => ({
        maybeSingle: vi.fn(async () => ({ data: null, error: null })),
      })),
    });

    const result = await validateVoucher(mockEnv, 'NONEXISTENT');
    expect(result.valid).toBe(false);
  });

  it('redeemVoucher rejects voucher assigned to different student', async () => {
    const futureDate = new Date();
    futureDate.setFullYear(futureDate.getFullYear() + 1);
    mockSelect.mockReturnValueOnce({
      eq: vi.fn(() => ({
        maybeSingle: vi.fn(async () => ({
          data: {
            item_type: 'mock_ibt',
            status: 'active',
            expires_at: futureDate.toISOString(),
            order_items: { assigned_student_id: 'student-A' },
          },
          error: null,
        })),
      })),
    });

    await expect(
      redeemVoucher(mockEnv, 'ASSIGNED1', 'student-B')
    ).rejects.toThrow(/assigned to different student/);
  });
});
