/**
 * Agent cost guards + production hardening — T26 (Wave 4).
 *
 * Tracks per-user + per-day token usage, enforces daily limits,
 * adds failover for OpenAI rate limits.
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface CostGuard {
  /** Per-user per-day limit (free tier). */
  freeTierDailyTokens: number;
  /** Per-user per-day limit (pro tier). */
  proTierDailyTokens: number;
  /** Hard daily spend cap (USD-equivalent in tokens). */
  globalDailyTokens: number;
  /** Per-invocation timeout in ms. */
  invocationTimeoutMs: number;
  /** Max retries on 429. */
  maxRetries: number;
}

export const DEFAULT_COST_GUARD: CostGuard = {
  freeTierDailyTokens: 200_000,      // ~$0.30/day in gpt-4o-mini tokens
  proTierDailyTokens: 5_000_000,     // ~$7.50/day
  globalDailyTokens: 100_000_000,    // ~$150/day platform-wide
  invocationTimeoutMs: 30_000,
  maxRetries: 2,
};

/** Check if user has tokens remaining today. */
export async function checkDailyTokenBudget(
  env: Env,
  userId: string,
  isPro: boolean
): Promise<{ allowed: boolean; used: number; limit: number; resetAt: Date }> {
  const supabase = getSupabase(env);
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const { data } = await supabase
    .from('agent_traces')
    .select('tokens_used')
    .eq('user_id', userId)
    .gte('created_at', today.toISOString());

  const used = (data ?? []).reduce((sum: number, r: any) => sum + (r.tokens_used ?? 0), 0);
  const limit = isPro ? DEFAULT_COST_GUARD.proTierDailyTokens : DEFAULT_COST_GUARD.freeTierDailyTokens;
  const resetAt = new Date(today);
  resetAt.setUTCDate(resetAt.getUTCDate() + 1);

  return { allowed: used < limit, used, limit, resetAt };
}

/** Check global daily budget (all users). */
export async function checkGlobalDailyBudget(env: Env): Promise<{ allowed: boolean; used: number; limit: number }> {
  const supabase = getSupabase(env);
  const today = new Date();
  today.setUTCHours(0, 0, 0, 0);

  const { data } = await supabase
    .from('agent_traces')
    .select('tokens_used')
    .gte('created_at', today.toISOString());

  const used = (data ?? []).reduce((sum: number, r: any) => sum + (r.tokens_used ?? 0), 0);
  const limit = DEFAULT_COST_GUARD.globalDailyTokens;
  return { allowed: used < limit, used, limit };
}

/** Wrap a fetch call with timeout + 429 retry. */
export async function fetchWithRetry(
  url: string,
  init: RequestInit,
  options: Partial<CostGuard> = {}
): Promise<Response> {
  const cfg = { ...DEFAULT_COST_GUARD, ...options };
  let attempt = 0;
  let lastError: unknown;

  while (attempt <= cfg.maxRetries) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), cfg.invocationTimeoutMs);
    try {
      const response = await fetch(url, { ...init, signal: controller.signal });
      clearTimeout(timeout);
      if (response.status === 429 && attempt < cfg.maxRetries) {
        const retryAfter = response.headers.get('Retry-After');
        const waitMs = retryAfter ? parseInt(retryAfter, 10) * 1000 : 1000 * (attempt + 1);
        await new Promise(resolve => setTimeout(resolve, waitMs));
        attempt++;
        continue;
      }
      return response;
    } catch (err) {
      clearTimeout(timeout);
      lastError = err;
      if (attempt < cfg.maxRetries) {
        attempt++;
        continue;
      }
      throw err;
    }
  }
  throw lastError ?? new Error('fetchWithRetry: exhausted retries');
}