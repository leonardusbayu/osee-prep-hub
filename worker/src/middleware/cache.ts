import type { Context } from 'hono';
import type { Env, ContextVars } from '../types';

/**
 * Cache middleware — Task 18.2.
 *
 * Uses the Cloudflare Workers Cache API (caches.put / caches.match) to cache
 * GET responses at the edge. Cache is keyed by the full URL + the user's JWT
 * subject so authenticated responses don't leak between users.
 *
 * Usage:
 *   app.get('/api/teacher/dashboard', cache({ ttl: 60 }), handler);
 *
 * Only GET requests are cached. POST/PUT/DELETE bypass the cache.
 */

interface CacheOptions {
  /** Cache TTL in seconds. Default 60. */
  ttl?: number;
  /** Whether to vary cache by user (default true — auth responses). */
  varyByUser?: boolean;
  /** Cache-Control header value for the response. Default `public, max-age=<ttl>`. */
  cacheControl?: string;
}

/** Cache middleware factory. */
export function cache(opts: CacheOptions = {}) {
  const ttl = opts.ttl ?? 60;
  const varyByUser = opts.varyByUser ?? true;
  const cacheControl = opts.cacheControl ?? `public, max-age=${ttl}`;

  return async (
    c: Context<{ Bindings: Env; Variables: ContextVars }>,
    next: () => Promise<void>
  ): Promise<Response | void> => {
    // Only cache GET
    if (c.req.method !== 'GET') {
      await next();
      return;
    }

    // Build cache key — includes user subject (if varyByUser) and URL
    let cacheKey = c.req.url;
    if (varyByUser) {
      try {
        const user = c.get('user');
        if (user?.id) {
          cacheKey = `${cacheKey}#user=${user.id}`;
        }
      } catch {
        // user not set yet — skip vary-by-user
      }
    }

    const cache = caches.default;
    const request = new Request(new URL(cacheKey), { method: 'GET' });

    // Try cache hit
    try {
      const cached = await cache.match(request);
      if (cached) {
        // Return cached response with cache-control header
        const headers = new Headers(cached.headers);
        headers.set('Cache-Control', cacheControl);
        headers.set('X-Cache', 'HIT');
        return new Response(cached.body, {
          status: cached.status,
          statusText: cached.statusText,
          headers,
        });
      }
    } catch {
      // Cache miss or error — fall through to handler
    }

    // Run handler
    await next();

    // Cache the response if it's a 2xx JSON response
    const res = c.res;
    if (res.status >= 200 && res.status < 300) {
      try {
        const contentType = res.headers.get('Content-Type') ?? '';
        if (contentType.includes('application/json')) {
          // Clone the response — can't consume the original twice
          const cloned = res.clone();
          const cachedResponse = new Response(cloned.body, {
            status: cloned.status,
            statusText: cloned.statusText,
            headers: cloned.headers,
          });
          cachedResponse.headers.set('Cache-Control', cacheControl);
          // Don't await — fire-and-forget so we don't block the response
          c.executionCtx.waitUntil(cache.put(request, cachedResponse));
        }
      } catch (err) {
        console.error('Cache put failed:', err);
      }
    }

    // Mark as miss
    res.headers.set('X-Cache', 'MISS');
  };
}