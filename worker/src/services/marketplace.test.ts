/** Marketplace service tests — T14 (Wave 2). */

import { describe, it, expect } from 'vitest';
import { calculateSplit, OSEE_COMMISSION_PCT } from './marketplace';

describe('calculateSplit', () => {
  it('returns 15% commission by default', () => {
    expect(OSEE_COMMISSION_PCT).toBe(15);
  });

  it('splits 100000 IDR → 15000 commission + 85000 payout', () => {
    const split = calculateSplit(100000);
    expect(split.commission).toBe(15000);
    expect(split.payout).toBe(85000);
  });

  it('splits 50000 IDR → 7500 + 42500', () => {
    const split = calculateSplit(50000);
    expect(split.commission).toBe(7500);
    expect(split.payout).toBe(42500);
  });

  it('handles small amounts (rounds to nearest IDR)', () => {
    const split = calculateSplit(99);
    expect(split.commission + split.payout).toBe(99);
  });

  it('handles large amounts (10M IDR → 1.5M commission + 8.5M payout)', () => {
    const split = calculateSplit(10000000);
    expect(split.commission).toBe(1500000);
    expect(split.payout).toBe(8500000);
  });
});