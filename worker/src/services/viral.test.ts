/** Viral service tests — T25 (Wave 3). */

import { describe, it, expect } from 'vitest';
import { calculateReferralReward, generateReferralCode } from './viral';

describe('generateReferralCode', () => {
  it('returns 8 uppercase base36 chars', () => {
    const code = generateReferralCode();
    expect(code).toMatch(/^[0-9A-Z]{8}$/);
  });

  it('generates different codes', () => {
    const codes = new Set();
    for (let i = 0; i < 100; i++) codes.add(generateReferralCode());
    expect(codes.size).toBeGreaterThan(95);
  });
});

describe('calculateReferralReward', () => {
  it('returns 25k IDR per conversion', () => {
    expect(calculateReferralReward(1)).toBe(25000);
    expect(calculateReferralReward(5)).toBe(125000);
  });

  it('caps at 500k IDR/month', () => {
    expect(calculateReferralReward(20)).toBe(500000);
    expect(calculateReferralReward(100)).toBe(500000);
  });

  it('returns 0 for 0 conversions', () => {
    expect(calculateReferralReward(0)).toBe(0);
  });
});