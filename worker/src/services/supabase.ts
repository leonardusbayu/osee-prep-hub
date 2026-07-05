import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { Env } from '../types';

/**
 * Supabase client factory.
 *
 * Uses service key for full access (server-side only — never expose to client).
 * For client-facing operations that should respect RLS, use getAnonClient.
 */
export function getSupabase(env: Env): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

/** Anon client — respects RLS. Use for user-scoped queries where RLS applies. */
export function getAnonSupabase(env: Env): SupabaseClient {
  return createClient(env.SUPABASE_URL, env.SUPABASE_ANON_KEY, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}