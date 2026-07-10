/**
 * Ambassador program v2 — T37 (Wave 5).
 *
 * 2× commission for top 20 teachers, with equity options (0.01-0.05%, 2-year vest).
 * Badges: 'partner' (default), 'ambassador' (5+ referrals), 'top_ambassador' (20+ referrals),
 *         'elite' (50+ referrals + 4.5+ avg rating).
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export type AmbassadorTier = 'partner' | 'ambassador' | 'top_ambassador' | 'elite';

export interface AmbassadorTierRecord {
  user_id: string;
  tier: AmbassadorTier;
  commission_multiplier: number;
  equity_grant_idr: number;
  equity_vest_years: number;
  badge: string | null;
  joined_at: string;
  promoted_at: string | null;
  notes: string | null;
}

export const TIER_DEFINITIONS: Record<AmbassadorTier, { multiplier: number; equity: number; vest: number; badge: string | null }> = {
  partner: { multiplier: 1.00, equity: 0, vest: 0, badge: null },
  ambassador: { multiplier: 1.25, equity: 0, vest: 0, badge: 'OSEE Ambassador' },
  top_ambassador: { multiplier: 1.50, equity: 5_000_000, vest: 2, badge: 'Top Ambassador ⭐' },
  elite: { multiplier: 2.00, equity: 25_000_000, vest: 2, badge: 'Elite Ambassador 💎' },
};

/** Compute the appropriate tier for a user based on referrals + ratings. */
export function computeTier(
  referralsConverted: number,
  averageStars: number
): AmbassadorTier {
  if (referralsConverted >= 50 && averageStars >= 4.5) return 'elite';
  if (referralsConverted >= 20) return 'top_ambassador';
  if (referralsConverted >= 5) return 'ambassador';
  return 'partner';
}

/** Get or create ambassador tier for a user. Recomputes from current data. */
export async function syncAmbassadorTier(
  env: Env,
  userId: string
): Promise<AmbassadorTierRecord> {
  const supabase = getSupabase(env);

  // Count converted referrals.
  const { count: convertedCount } = await supabase
    .from('referrals')
    .select('id', { count: 'exact', head: true })
    .eq('referrer_id', userId)
    .in('status', ['signed_up', 'converted']);

  // Compute avg stars from reviews (across all listings).
  const { data: listings } = await supabase
    .from('marketplace_listings')
    .select('id')
    .eq('seller_id', userId);
  const listingIds = (listings ?? []).map((l: any) => l.id);
  const { data: reviews } = listingIds.length > 0
    ? await supabase.from('marketplace_reviews').select('stars').in('listing_id', listingIds)
    : { data: [] };
  const reviewList = (reviews ?? []) as { stars: number }[];
  const avgStars = reviewList.length > 0
    ? reviewList.reduce((sum, r) => sum + r.stars, 0) / reviewList.length
    : 0;

  const tier = computeTier(convertedCount ?? 0, avgStars);
  const def = TIER_DEFINITIONS[tier];

  const { data, error } = await supabase
    .from('ambassador_tiers')
    .upsert({
      user_id: userId,
      tier,
      commission_multiplier: def.multiplier,
      equity_grant_idr: def.equity,
      equity_vest_years: def.vest,
      badge: def.badge,
      promoted_at: new Date().toISOString(),
    }, { onConflict: 'user_id' })
    .select()
    .single();
  if (error || !data) throw new Error(`syncAmbassadorTier failed: ${error?.message ?? 'no row'}`);
  return data as AmbassadorTierRecord;
}

/** Get the current tier for a user. */
export async function getAmbassadorTierRecord(
  env: Env,
  userId: string
): Promise<AmbassadorTierRecord | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('ambassador_tiers')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle();
  return (data as AmbassadorTierRecord) ?? null;
}

/** Apply tier multiplier to a base commission. */
export function applyTierMultiplier(baseCommissionIdr: number, tier: AmbassadorTier): number {
  return Math.round(baseCommissionIdr * TIER_DEFINITIONS[tier].multiplier);
}