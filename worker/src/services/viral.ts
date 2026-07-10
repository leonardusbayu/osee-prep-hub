/**
 * Viral growth service — T25 (Wave 3).
 *
 * Referral codes, share tracking, conversion rewards. Powers the
 * "share your Passport" / "refer a teacher" loops that drive OSEE
 * growth in Indonesia.
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

/** Generate a short URL-safe referral code for a user. */
export function generateReferralCode(): string {
  // 8 chars base36 — collision probability ~1M users before 50%.
  return Math.random().toString(36).slice(2, 10).toUpperCase();
}

/** Reward calculation for conversions — T25 helper. */
export function calculateReferralReward(conversions: number): number {
  // 25k IDR per conversion, capped at 500k IDR/month.
  const perConversion = 25000;
  const monthlyCap = 500000;
  return Math.min(conversions * perConversion, monthlyCap);
}

/** Get or create the user's referral code. */
export async function getOrCreateReferralCode(
  env: Env,
  userId: string
): Promise<{ code: string; shareUrl: string; totalReferrals: number }> {
  const supabase = getSupabase(env);

  // Check existing code.
  const { data: existing } = await supabase
    .from('referrals')
    .select('referral_code')
    .eq('referrer_id', userId)
    .order('created_at', { ascending: true })
    .limit(1)
    .maybeSingle();

  let code = existing?.referral_code;
  if (!code) {
    code = generateReferralCode();
    // Ensure unique — retry on collision.
    let attempts = 0;
    while (attempts < 5) {
      const { data: dup } = await supabase
        .from('referrals')
        .select('id')
        .eq('referral_code', code)
        .maybeSingle();
      if (!dup) break;
      code = generateReferralCode();
      attempts++;
    }
    await supabase.from('referrals').insert({
      referrer_id: userId,
      referral_code: code,
      source: 'direct_link',
      status: 'pending',
    });
  }

  // Count referrals.
  const { count } = await supabase
    .from('referrals')
    .select('id', { count: 'exact', head: true })
    .eq('referrer_id', userId)
    .in('status', ['signed_up', 'converted']);

  return {
    code: code!,
    shareUrl: `https://osee.co.id/r/${code}`,
    totalReferrals: count ?? 0,
  };
}

/** Record a share event (when user shares their Passport, Coach result, etc.). */
export async function recordShareEvent(
  env: Env,
  userId: string,
  surface: 'passport_share' | 'coach_recommend' | 'syllabus_share' | 'marketplace_listing',
  entityId: string,
  channel?: 'whatsapp' | 'twitter' | 'email' | 'copy_link' | 'instagram'
): Promise<void> {
  const supabase = getSupabase(env);
  await supabase.from('viral_share_events').insert({
    user_id: userId,
    surface,
    entity_id: entityId,
    channel: channel ?? null,
  });
}

/** Record click on a share link (called when someone hits the /r/:code landing). */
export async function recordShareClick(
  env: Env,
  referralCode: string
): Promise<{ referrerId: string | null }> {
  const supabase = getSupabase(env);
  // Increment click count.
  const { data: ref } = await supabase
    .from('referrals')
    .select('id, referrer_id')
    .eq('referral_code', referralCode)
    .maybeSingle();
  if (!ref) return { referrerId: null };
  // We don't have a clicks column on referrals — record click as viral_share_events with surface='referral_click'.
  await supabase.from('viral_share_events').insert({
    user_id: ref.referrer_id,
    surface: 'syllabus_share',
    entity_id: referralCode,
    channel: 'copy_link',
  });
  return { referrerId: ref.referrer_id };
}

/** Convert a referral (when referee signs up). */
export async function convertReferral(
  env: Env,
  referralCode: string,
  refereeId: string
): Promise<void> {
  const supabase = getSupabase(env);
  await supabase
    .from('referrals')
    .update({
      referee_id: refereeId,
      status: 'signed_up',
      converted_at: new Date().toISOString(),
    })
    .eq('referral_code', referralCode)
    .is('referee_id', null);
}