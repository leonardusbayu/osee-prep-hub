import type { Context } from 'hono';
import type { Env, ContextVars, User, UserRole } from '../types';
import { verifyJwt, extractBearerToken } from '../services/jwt';
import { getSupabase } from '../services/supabase';
import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Auth middleware — verifies JWT from cookie or Authorization header.
 * Sets c.set('user', user) on success; throws 401 on missing/invalid token.
 */

const COOKIE_NAME = 'osee_token';

/** Extract JWT from request — checks Authorization header first, then cookie. */
function extractTokenFromRequest(req: {
  header: (name: string) => string | undefined;
}): string | null {
  // Try Authorization header first
  const authHeader = req.header('Authorization');
  const bearer = extractBearerToken(authHeader);
  if (bearer) return bearer;

  // Fall back to cookie
  const cookieHeader = req.header('Cookie');
  if (!cookieHeader) return null;
  for (const part of cookieHeader.split(';')) {
    const [name, ...valueParts] = part.trim().split('=');
    if (name === COOKIE_NAME) {
      return valueParts.join('=').trim();
    }
  }
  return null;
}

/** Look up user by ID in Supabase. Returns null if not found. */
async function getUserById(supabase: SupabaseClient, userId: string): Promise<User | null> {
  const { data, error } = await supabase
    .from('unified_profiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error || !data) return null;
  return data as User;
}

/** Auth middleware — requires valid JWT. Use on protected routes. */
export const requireAuth = () => {
  return async (c: Context<{ Bindings: Env; Variables: ContextVars }>, next: () => Promise<void>): Promise<Response | void> => {
    const token = extractTokenFromRequest(c.req);
    if (!token) {
      return c.json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } }, 401);
    }
    try {
      const payload = await verifyJwt(c.env, token);
      const supabase = getSupabase(c.env);
      const user = await getUserById(supabase, payload.sub);
      if (!user) {
        return c.json({ error: { code: 'USER_NOT_FOUND', message: 'User no longer exists' } }, 401);
      }
      c.set('user', user);
      await next();
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Invalid token';
      return c.json({ error: { code: 'INVALID_TOKEN', message } }, 401);
    }
  };
};

/** Role guard middleware — requires requireAuth to have run first. */
export const requireRole = (...roles: UserRole[]) => {
  return async (c: Context<{ Bindings: Env; Variables: ContextVars }>, next: () => Promise<void>): Promise<Response | void> => {
    const user = c.get('user');
    if (!user) {
      return c.json({ error: { code: 'UNAUTHORIZED', message: 'Authentication required' } }, 401);
    }
    if (!roles.includes(user.role)) {
      return c.json({ error: { code: 'FORBIDDEN', message: `Requires role: ${roles.join(' or ')}` } }, 403);
    }
    await next();
  };
};

/** Optional auth — sets user if token valid, but doesn't block if absent/invalid. */
export const optionalAuth = () => {
  return async (c: Context<{ Bindings: Env; Variables: ContextVars }>, next: () => Promise<void>): Promise<Response | void> => {
    const token = extractTokenFromRequest(c.req);
    if (token) {
      try {
        const payload = await verifyJwt(c.env, token);
        const supabase = getSupabase(c.env);
        const user = await getUserById(supabase, payload.sub);
        if (user) c.set('user', user);
      } catch {
        // Ignore invalid token — treat as unauthenticated
      }
    }
    await next();
  };
};

export { COOKIE_NAME };