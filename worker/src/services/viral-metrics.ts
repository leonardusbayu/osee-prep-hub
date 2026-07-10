/**
 * Viral loop metrics — T40 (Wave 5).
 *
 * Aggregates share/click/conversion data into actionable metrics.
 * Powers the growth dashboard.
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface ViralMetrics {
  total_shares: number;
  total_clicks: number;
  total_conversions: number;
  click_to_conversion_rate: number;
  shares_by_surface: Record<string, number>;
  shares_by_channel: Record<string, number>;
  top_sharers: Array<{ user_id: string; shares: number }>;
  top_referrers: Array<{ user_id: string; conversions: number; reward_idr: number }>;
}

/** Compute viral metrics over the last `days` days. */
export async function getViralMetrics(env: Env, days = 30): Promise<ViralMetrics> {
  const supabase = getSupabase(env);
  const since = new Date();
  since.setDate(since.getDate() - days);

  const { data: shares } = await supabase
    .from('viral_share_events')
    .select('*')
    .gte('created_at', since.toISOString());
  const shareList = (shares ?? []) as any[];

  // Shares by surface.
  const sharesBySurface: Record<string, number> = {};
  const sharesByChannel: Record<string, number> = {};
  for (const s of shareList) {
    sharesBySurface[s.surface] = (sharesBySurface[s.surface] ?? 0) + 1;
    if (s.channel) sharesByChannel[s.channel] = (sharesByChannel[s.channel] ?? 0) + 1;
  }

  // Top sharers.
  const sharerCounts = new Map<string, number>();
  for (const s of shareList) {
    sharerCounts.set(s.user_id, (sharerCounts.get(s.user_id) ?? 0) + 1);
  }
  const topSharers = Array.from(sharerCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([user_id, shares]) => ({ user_id, shares }));

  // Referrals (conversions).
  const { data: referrals } = await supabase
    .from('referrals')
    .select('*')
    .gte('created_at', since.toISOString());
  const refList = (referrals ?? []) as any[];

  const converted = refList.filter(r => r.status === 'signed_up' || r.status === 'converted');
  const referrerCounts = new Map<string, number>();
  for (const r of converted) {
    referrerCounts.set(r.referrer_id, (referrerCounts.get(r.referrer_id) ?? 0) + 1);
  }
  const { calculateReferralReward } = await import('./viral');
  const topReferrers = Array.from(referrerCounts.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(([user_id, conversions]) => ({
      user_id,
      conversions,
      reward_idr: calculateReferralReward(conversions),
    }));

  // Clicks (all time — share events include click as one surface).
  const totalClicks = shareList.filter(s => s.surface === 'syllabus_share' && s.channel === 'copy_link').length;
  const clickToConversionRate = totalClicks > 0 ? converted.length / totalClicks : 0;

  return {
    total_shares: shareList.length,
    total_clicks: totalClicks,
    total_conversions: converted.length,
    click_to_conversion_rate: Math.round(clickToConversionRate * 1000) / 1000,
    shares_by_surface: sharesBySurface,
    shares_by_channel: sharesByChannel,
    top_sharers: topSharers,
    top_referrers: topReferrers,
  };
}