import type { Context } from 'hono';
import type { Env, ContextVars } from '../types';

/**
 * CORS middleware — allows *.osee.co.id subdomains.
 * Blocks non-osee origins per Task 1.2 acceptance criteria.
 */
const ALLOWED_ORIGIN_SUFFIX = '.osee.co.id';
const ALLOWED_EXACT_ORIGINS = new Set<string>([
  'http://localhost:5173', // Vite admin dev
  'http://localhost:8080', // Flutter Web dev
  'http://localhost:8787', // Worker dev (self)
  'https://prep.osee.co.id',
  'https://osee-prep-hub.pages.dev',
]);

export function isAllowedOrigin(origin: string | undefined | null): boolean {
  if (!origin) return false;
  if (ALLOWED_EXACT_ORIGINS.has(origin)) return true;
  try {
    const url = new URL(origin);
    return url.hostname.endsWith(ALLOWED_ORIGIN_SUFFIX);
  } catch {
    return false;
  }
}

export const cors = () => {
  return async (c: Context<{ Bindings: Env; Variables: ContextVars }>, next: () => Promise<void>): Promise<Response | void> => {
    const origin = c.req.header('Origin');
    if (origin && isAllowedOrigin(origin)) {
      c.header('Access-Control-Allow-Origin', origin);
      c.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      c.header('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Webhook-Secret, X-Hub-Secret');
      c.header('Access-Control-Allow-Credentials', 'true');
      c.header('Access-Control-Max-Age', '86400');
    }
    // Handle preflight
    if (c.req.header('Access-Control-Request-Method')) {
      return new Response(null, { status: 204 });
    }
    await next();
  };
};