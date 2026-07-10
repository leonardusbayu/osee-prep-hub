/**
 * Rate-limit middleware — Task 1 (Wave 1).
 *
 * Simple in-memory token-bucket per userId+route. For production scale this should
 * be KV-backed, but in-memory is sufficient for Wave 1 correctness + tests.
 *
 * Free tier: 20 req/min. Pro tier: 200 req/min.
 */

import type { Context } from 'hono';
import type { Env, ContextVars, User } from '../types';

interface Bucket {
  tokens: number;
  lastRefill: number; // epoch ms
}

const buckets = new Map<string, Bucket>();
const REFILL_INTERVAL_MS = 60_000;

function refill(bucket: Bucket, capacity: number): void {
  const now = Date.now();
  const elapsed = now - bucket.lastRefill;
  if (elapsed >= REFILL_INTERVAL_MS) {
    const refills = Math.floor(elapsed / REFILL_INTERVAL_MS);
    bucket.tokens = Math.min(capacity, bucket.tokens + refills * capacity);
    bucket.lastRefill = now;
  }
}

function getCapacity(user: User | null): number {
  if (!user) return 20;
  // Pro tier: admin/partner/teacher with explicit role flag.
  // For Wave 1 simplicity: admin + partner = pro. Teacher = pro.
  // Student = free unless they have a paid subscription (future).
  if (user.role === 'admin' || user.role === 'partner' || user.role === 'teacher') {
    return 200;
  }
  return 20;
}

/**
 * Rate-limit middleware factory.
 * Usage: agentRoutes.use('*', rateLimit('agent-invoke'));
 */
export function rateLimit(scope: string) {
  return async (
    c: Context<{ Bindings: Env; Variables: ContextVars }>,
    next: () => Promise<void>
  ): Promise<Response | void> => {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } }, 401);
    }
    const key = `${scope}:${user.id}`;
    const capacity = getCapacity(user);
    let bucket = buckets.get(key);
    if (!bucket) {
      bucket = { tokens: capacity, lastRefill: Date.now() };
      buckets.set(key, bucket);
    }
    refill(bucket, capacity);
    if (bucket.tokens < 1) {
      const retryAfterSec = Math.ceil((REFILL_INTERVAL_MS - (Date.now() - bucket.lastRefill)) / 1000);
      c.header('Retry-After', String(Math.max(retryAfterSec, 1)));
      return c.json(
        { error: { code: 'RATE_LIMITED', message: `Rate limit exceeded (${capacity}/min). Retry after ${retryAfterSec}s.` } },
        429
      );
    }
    bucket.tokens -= 1;
    await next();
  };
}

/** Test-only helper: reset buckets between tests. */
export function _resetBucketsForTests(): void {
  buckets.clear();
}