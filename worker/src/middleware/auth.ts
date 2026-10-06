import type { Context } from 'hono';
import type { Env, ContextVars, JwtPayload, User, UserRole } from '../types';
import { verifyJwt, extractBearerToken } from '../services/jwt';

/** Auth middleware — verifies JWT from cookie or Authorization header.
 *  Sets c.set('user', user) on success; throws 401 on missing/invalid token.
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

/** Build a User from a JWT payload, suitable for middleware context. */
function userFromPayload(payload: JwtPayload): User {
  return {
    id: payload.sub,
    email: payload.email,
    display_name: payload.email, // JWT doesn't carry display_name; callers that need it should fetch from DB
    role: payload.role,
    avatar_url: null,
    telegram_id: null,
    target_exam: null,
    target_score: null,
    current_level: null,
    teacher_institution: null,
    created_at: '',
    updated_at: '',
  };
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
      // Fast path: derive user from JWT payload without a DB round-trip.
      // This covers role checks and most endpoints. Routes that need DB-backed
      // fields (e.g., teacher_institution) can still fetch the full profile.
      c.set('user', userFromPayload(payload));
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
        c.set('user', userFromPayload(payload));
      } catch {
        // Ignore invalid token — treat as unauthenticated
      }
    }
    await next();
  };
};

/** Fetch a fresh user profile from Supabase. Use when a route needs DB-backed
 *  fields that are not stored in the JWT (e.g., display_name, teacher_institution). */
export async function fetchUserProfile(env: Env, userId: string): Promise<User | null> {
  const { getSupabase } = await import('../services/supabase');
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('unified_profiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error || !data) return null;
  return data as User;
}

/**
 * Helper to get the authenticated user from context.
 * Throws 500-style error if user is null (shouldn't happen after requireAuth,
 * but TypeScript can't know that).
 */
export function getAuthedUser(c: Context<{ Bindings: Env; Variables: ContextVars }>): User {
  const user = c.get('user');
  if (!user) {
    throw new Error('User not authenticated — requireAuth middleware missing?');
  }
  return user;
}

export { COOKIE_NAME };