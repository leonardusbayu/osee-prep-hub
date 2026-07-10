/** Ambassador v2 tests — T37 (Wave 5). */

import { describe, it, expect } from 'vitest';
import { computeTier, applyTierMultiplier, TIER_DEFINITIONS } from './ambassador-v2';

describe('computeTier', () => {
  it('returns partner for low engagement', () => {
    expect(computeTier(0, 0)).toBe('partner');
    expect(computeTier(4, 5)).toBe('partner');
  });

  it('returns ambassador for 5+ referrals', () => {
    expect(computeTier(5, 0)).toBe('ambassador');
    expect(computeTier(19, 0)).toBe('ambassador');
  });

  it('returns top_ambassador for 20+ referrals', () => {
    expect(computeTier(20, 0)).toBe('top_ambassador');
    expect(computeTier(49, 0)).toBe('top_ambassador');
  });

  it('returns elite for 50+ referrals + 4.5+ rating', () => {
    expect(computeTier(50, 4.5)).toBe('elite');
    expect(computeTier(100, 5)).toBe('elite');
  });

  it('top_ambassador requires only 20 referrals, not rating', () => {
    expect(computeTier(20, 2)).toBe('top_ambassador');
  });

  it('elite requires BOTH 50 referrals AND 4.5 rating', () => {
    expect(computeTier(50, 4)).toBe('top_ambassador');
    expect(computeTier(40, 5)).toBe('top_ambassador');
  });
});

describe('applyTierMultiplier', () => {
  it('partner = 1.0x', () => {
    expect(applyTierMultiplier(10000, 'partner')).toBe(10000);
  });

  it('ambassador = 1.25x', () => {
    expect(applyTierMultiplier(10000, 'ambassador')).toBe(12500);
  });

  it('top_ambassador = 1.5x', () => {
    expect(applyTierMultiplier(10000, 'top_ambassador')).toBe(15000);
  });

  it('elite = 2.0x', () => {
    expect(applyTierMultiplier(10000, 'elite')).toBe(20000);
  });
});

describe('TIER_DEFINITIONS', () => {
  it('has 4 tiers', () => {
    expect(Object.keys(TIER_DEFINITIONS)).toHaveLength(4);
  });

  it('elite has highest multiplier', () => {
    const multipliers = Object.values(TIER_DEFINITIONS).map(t => t.multiplier);
    expect(Math.max(...multipliers)).toBe(TIER_DEFINITIONS.elite.multiplier);
  });

  it('only elite and top_ambassador have equity', () => {
    expect(TIER_DEFINITIONS.partner.equity_pct).toBe(0);
    expect(TIER_DEFINITIONS.ambassador.equity_pct).toBe(0);
    expect(TIER_DEFINITIONS.top_ambassador.equity_pct).toBeGreaterThan(0);
    expect(TIER_DEFINITIONS.elite.equity_pct).toBeGreaterThan(0);
  });

  it('equity_pct matches plan: 0.01-0.05% range', () => {
    expect(TIER_DEFINITIONS.top_ambassador.equity_pct).toBeCloseTo(0.01, 5);
    expect(TIER_DEFINITIONS.elite.equity_pct).toBeCloseTo(0.05, 5);
  });
});