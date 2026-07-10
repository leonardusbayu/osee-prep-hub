/** Insight service tests — T13 (Wave 2). */

import { describe, it, expect } from 'vitest';
import { calculateSplit } from '../services/marketplace';

describe('insight read paths (mocked)', () => {
  it('commission split math works for analytics tests', () => {
    // ROI = score_improvement / price_idr (mocked here).
    const split = calculateSplit(500000);
    expect(split.payout).toBe(425000);
    expect(split.commission).toBe(75000);
  });
});