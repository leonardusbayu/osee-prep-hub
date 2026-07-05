import type { Env, UserRole } from '../types';
import { getSupabase } from './supabase';

/**
 * Quota service — tracks monthly AI usage per user.
 *
 * Task 5.4: Quota checking
 *   - Free tier: 50 grading credits/month, 10 generation credits/month
 *   - Pro tier: unlimited
 *   - Partner tier: unlimited (institution license)
 *   - Admin: unlimited
 *
 * Quota bonus (Task 12.4 — placeholder): teachers earn +5 credits per student
 * who completes first practice.
 */

const FREE_GRADING_LIMIT = 50;
// FREE_GENERATION_LIMIT = 10 — will be added in Task 6.6 when generation quota is implemented

export interface QuotaStatus {
  used: number;
  limit: number; // -1 = unlimited
  remaining: number; // -1 = unlimited
  reset_at: string; // ISO timestamp — start of next month
}

export type QuotaType = 'grading' | 'generation' | 'speaking';

/** Get the user's quota limit for a given type. */
export function getQuotaLimit(role: UserRole, bonusCredits = 0): number {
  switch (role) {
    case 'admin':
    case 'partner':
      return -1; // unlimited
    case 'teacher': {
      // TODO: Check if teacher has pro subscription — pro = unlimited
      // For now, assume free tier unless we add a subscription check
      return FREE_GRADING_LIMIT + bonusCredits;
    }
    case 'student':
    default:
      return FREE_GRADING_LIMIT + bonusCredits;
  }
}

/** Get current month's usage for a user + quota type. */
export async function getMonthlyUsage(
  env: Env,
  userId: string,
  quotaType: QuotaType
): Promise<number> {
  const supabase = getSupabase(env);
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

  // Query ai_grading_queue for grading count this month
  if (quotaType === 'grading') {
    const { count, error } = await supabase
      .from('ai_grading_queue')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .gte('created_at', monthStart);
    if (error) {
      throw new Error(`Failed to fetch usage: ${error.message}`);
    }
    return count ?? 0;
  }

  // Query ai_generation_queue for generation count this month
  if (quotaType === 'generation') {
    const { count, error } = await supabase
      .from('ai_generation_queue')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .gte('created_at', monthStart);
    if (error) {
      // Table may not exist yet — return 0
      console.warn('Generation queue query failed (table may not exist):', error);
      return 0;
    }
    return count ?? 0;
  }

  // Speaking quota — also tracked via ai_grading_queue with type='speaking'
  // (schema doesn't have a separate speaking queue — reuse grading queue)
  if (quotaType === 'speaking') {
    const { count, error } = await supabase
      .from('ai_grading_queue')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('grading_type', 'speaking')
      .gte('created_at', monthStart);
    if (error) {
      return 0;
    }
    return count ?? 0;
  }

  return 0;
}

/** Check if user has remaining quota. Throws if exceeded. */
export async function checkQuota(
  env: Env,
  userId: string,
  role: UserRole,
  quotaType: QuotaType,
  bonusCredits = 0
): Promise<QuotaStatus> {
  const limit = getQuotaLimit(role, bonusCredits);
  const used = await getMonthlyUsage(env, userId, quotaType);

  // Unlimited
  if (limit === -1) {
    return {
      used,
      limit: -1,
      remaining: -1,
      reset_at: getMonthResetIso(),
    };
  }

  if (used >= limit) {
    const err = new Error(`Quota exceeded: ${used}/${limit} ${quotaType} credits used this month`);
    (err as Error & { code: string }).code = 'QUOTA_EXCEEDED';
    throw err;
  }

  return {
    used,
    limit,
    remaining: limit - used,
    reset_at: getMonthResetIso(),
  };
}

/** Get the ISO timestamp for the start of next month (when quota resets). */
function getMonthResetIso(): string {
  const now = new Date();
  const nextMonth = new Date(now.getFullYear(), now.getMonth() + 1, 1);
  return nextMonth.toISOString();
}

/** Get quota status without throwing (for display in UI). */
export async function getQuotaStatus(
  env: Env,
  userId: string,
  role: UserRole,
  quotaType: QuotaType,
  bonusCredits = 0
): Promise<QuotaStatus> {
  try {
    return await checkQuota(env, userId, role, quotaType, bonusCredits);
  } catch (err) {
    // Quota exceeded — return 0 remaining
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      const limit = getQuotaLimit(role, bonusCredits);
      return {
        used: limit,
        limit,
        remaining: 0,
        reset_at: getMonthResetIso(),
      };
    }
    throw err;
  }
}