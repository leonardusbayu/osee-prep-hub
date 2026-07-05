import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Ambassador program service — Task 17.x.
 *
 * Manages ambassador recruitment, bonuses, and dashboard.
 */

export interface AmbassadorStats {
  is_ambassador: boolean;
  recruited_teachers: number;
  total_bonus_earned: number;
  this_month_bonus: number;
  downline_activity: number;
}

/** Get ambassador stats for a teacher. */
export async function getAmbassadorStats(env: Env, userId: string): Promise<AmbassadorStats> {
  const supabase = getSupabase(env);

  // Check if ambassador
  const { data: profile } = await supabase
    .from('unified_profiles')
    .select('role')
    .eq('id', userId)
    .maybeSingle();

  const isAmbassador = (profile as Record<string, unknown>)?.role === 'ambassador' ||
    (profile as Record<string, unknown>)?.role === 'admin';

  // Count recruited teachers (referred_by = userId)
  const { count: recruitedCount } = await supabase
    .from('unified_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('referred_by', userId)
    .eq('role', 'teacher');

  // Sum commission from recruited teachers' activity
  const { data: commissions } = await supabase
    .from('commission_ledger')
    .select('amount, created_at')
    .eq('teacher_id', userId)
    .eq('commission_type', 'ambassador_bonus');

  const now = new Date();
  const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
  let totalBonus = 0;
  let thisMonthBonus = 0;
  for (const c of commissions ?? []) {
    const amount = (c as Record<string, unknown>).amount as number;
    const created = new Date((c as Record<string, unknown>).created_at as string);
    totalBonus += amount;
    if (created >= thisMonthStart) thisMonthBonus += amount;
  }

  return {
    is_ambassador: isAmbassador,
    recruited_teachers: recruitedCount ?? 0,
    total_bonus_earned: totalBonus,
    this_month_bonus: thisMonthBonus,
    downline_activity: recruitedCount ?? 0,
  };
}