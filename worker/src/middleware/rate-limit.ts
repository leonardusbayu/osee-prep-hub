import type { Context } from 'hono';
import type { Env, ContextVars } from '../types';

/**
 * Simple in-memory rate-limit middleware.
 *
 * Uses a per-key token bucket stored in a module-level Map. Each Worker
 * isolate has its own map, so this is a best-effort limiter (not globally
 * accurate across isolates) — sufficient to stop a single caller from
 * flooding an endpoint. For stricter limits, use Cloudflare's Rate Limiting
 * Rules in the dashboard.
 *
 * Returns 429 when the bucket is empty.
 */

interface RateLimitBuckets {
  map: Map<string, { tokens: number; last: number }>;
}

const registry: RateLimitBuckets[] = [];

export function rateLimit(opts: { key: (c: Context<{ Bindings: Env; Variables: ContextVars }>) => string; capacity: number; refillPerSecond: number }) {
  const buckets: RateLimitBuckets = { map: new Map() };
  registry.push(buckets);
  return async (c: Context<{ Bindings: Env; Variables: ContextVars }>, next: () => Promise<void>): Promise<Response | void> => {
    const key = opts.key(c);
    const now = Date.now() / 1000;
    let bucket = buckets.map.get(key);
    if (!bucket) {
      bucket = { tokens: opts.capacity, last: now };
      buckets.map.set(key, bucket);
    }
    // Refill
    const elapsed = now - bucket.last;
    bucket.tokens = Math.min(opts.capacity, bucket.tokens + elapsed * opts.refillPerSecond);
    bucket.last = now;
    if (bucket.tokens < 1) {
      return c.json(
        { error: { code: 'RATE_LIMITED', message: 'Too many requests. Please slow down.' } },
        429
      );
    }
    bucket.tokens -= 1;
    await next();
  };
}

/** Reset all rate-limit buckets — used by tests to avoid cross-test interference. */
export function resetRateLimits(): void {
  for (const b of registry) {
    b.map.clear();
  }
}