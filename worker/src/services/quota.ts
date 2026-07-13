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
const FREE_GENERATION_LIMIT = 10;

export interface QuotaStatus {
  used: number;
  limit: number; // -1 = unlimited
  remaining: number; // -1 = unlimited
  reset_at: string; // ISO timestamp — start of next month
}

export type QuotaType = 'grading' | 'generation' | 'speaking';

/** Check if a teacher has an active Pro/Institution subscription OR is an ambassador (Appendix B). */
async function isTeacherPro(env: Env, userId: string): Promise<boolean> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('teacher_profiles')
    .select('tier, tier_expires_at, is_ambassador')
    .eq('user_id', userId)
    .maybeSingle();
  const p = (data as Record<string, unknown> | null) ?? {};
  // Ambassadors get unlimited AI (blueprint Appendix B line 2915)
  if (p.is_ambassador === true) return true;
  const tier = (p.tier as string) ?? 'free';
  if (tier === 'free') return false;
  // Check not expired
  const expiresAt = p.tier_expires_at as string | null;
  if (expiresAt && new Date(expiresAt).getTime() < Date.now()) return false;
  return true;
}

/** Quota bonus system — Task 12.4.
 *
 * Teachers earn extra generation credits when their students take real actions:
 *   +5 credits per student who registers via referral code
 *   +5 credits per student who completes first practice test
 *   +10 credits per student who books official test
 *   +10 credits per student who subscribes to EduBot premium
 */
const BONUS_MAP: Record<string, { type: QuotaType; amount: number }> = {
  student_registered: { type: 'generation', amount: 5 },
  test_completed: { type: 'generation', amount: 5 },
  official_booking: { type: 'generation', amount: 10 },
  premium_subscribed: { type: 'generation', amount: 10 },
};

/** Award bonus credits to a teacher when their student performs an action. */
export async function awardQuotaBonus(
  env: Env,
  teacherId: string,
  eventType: string
): Promise<void> {
  const bonus = BONUS_MAP[eventType];
  if (!bonus) return;

  const supabase = getSupabase(env);

  // Find existing quota_usage row for this teacher + quota_type
  const { data: existing } = await supabase
    .from('ai_quota_usage')
    .select('id, earned_bonus')
    .eq('user_id', teacherId)
    .eq('quota_type', bonus.type)
    .maybeSingle();

  if (existing) {
    const row = existing as Record<string, unknown>;
    const newBonus = (row.earned_bonus as number) + bonus.amount;
    await supabase
      .from('ai_quota_usage')
      .update({ earned_bonus: newBonus, updated_at: new Date().toISOString() })
      .eq('id', row.id as string);
  } else {
    // Create new row with bonus as initial earned_bonus
    await supabase.from('ai_quota_usage').insert({
      user_id: teacherId,
      quota_type: bonus.type,
      used_count: 0,
      max_count: bonus.type === 'generation' ? 10 : 50,
      earned_bonus: bonus.amount,
      period_start: new Date().toISOString(),
    });
  }
}

/** Get the earned bonus credits for a user + quota type (from DB). */
async function getEarnedBonus(env: Env, userId: string, quotaType: QuotaType): Promise<number> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('ai_quota_usage')
    .select('earned_bonus')
    .eq('user_id', userId)
    .eq('quota_type', quotaType)
    .maybeSingle();
  return ((data as Record<string, unknown> | null)?.earned_bonus as number) ?? 0;
}

/** Get the user's quota limit for a given type. */
export async function getQuotaLimit(
  env: Env,
  role: UserRole,
  userId: string,
  quotaType: QuotaType,
  bonusCredits = 0
): Promise<number> {
  switch (role) {
    case 'admin':
    case 'partner':
      return -1; // unlimited — skip DB lookups
    case 'teacher': {
      const isPro = await isTeacherPro(env, userId);
      if (isPro) return -1;
      const dbBonus = bonusCredits > 0 ? bonusCredits : await getEarnedBonus(env, userId, quotaType);
      const base = quotaType === 'generation' ? FREE_GENERATION_LIMIT : FREE_GRADING_LIMIT;
      return base + dbBonus;
    }
    case 'student':
    default: {
      const dbBonus = bonusCredits > 0 ? bonusCredits : await getEarnedBonus(env, userId, quotaType);
      return (quotaType === 'generation' ? FREE_GENERATION_LIMIT : FREE_GRADING_LIMIT) + dbBonus;
    }
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
  // Table uses teacher_id (blueprint schema) not user_id
  if (quotaType === 'grading') {
    const { count, error } = await supabase
      .from('ai_grading_queue')
      .select('id', { count: 'exact', head: true })
      .eq('teacher_id', userId)
      .gte('created_at', monthStart);
    if (error) {
      // If teacher_id doesn't match, try student_id as fallback
      const { count: altCount } = await supabase
        .from('ai_grading_queue')
        .select('id', { count: 'exact', head: true })
        .eq('student_id', userId)
        .gte('created_at', monthStart);
      return altCount ?? 0;
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
  // Table uses teacher_id (blueprint schema) not user_id
  if (quotaType === 'speaking') {
    const { count, error } = await supabase
      .from('ai_grading_queue')
      .select('id', { count: 'exact', head: true })
      .eq('teacher_id', userId)
      .eq('submission_type', 'speaking')
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
  const limit = await getQuotaLimit(env, role, userId, quotaType, bonusCredits);
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
      const limit = await getQuotaLimit(env, role, userId, quotaType, bonusCredits);
      return {
        used: limit === -1 ? 0 : limit,
        limit,
        remaining: 0,
        reset_at: getMonthResetIso(),
      };
    }
    throw err;
  }
}