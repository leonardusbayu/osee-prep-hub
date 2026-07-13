import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Branding + tier management service — Task 15.1, 15.2, 15.3, 15.4.
 *
 * Handles:
 * - White-label branding config (logo, colors, hide OSEE branding)
 * - Pro / Institution tier subscription creation
 */

export interface BrandingConfig {
  id: string;
  logo_url: string | null;
  primary_color: string;
  secondary_color: string;
  custom_subdomain: string | null;
  hide_osee_branding: boolean;
  custom_copyright: string | null;
  active: boolean;
}

export interface TierInfo {
  tier: 'free' | 'pro' | 'institution';
  tier_expires_at: string | null;
  monthly_fee_idr: number;
  features: string[];
}

const TIER_PRICING: Record<string, number> = {
  pro: 50000,
  institution: 350000,
};

/** Get current branding config for a teacher (or null if none). */
export async function getBrandingConfig(env: Env, teacherId: string): Promise<BrandingConfig | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('branding_configs')
    .select('id, logo_url, primary_color, secondary_color, custom_subdomain, hide_osee_branding, custom_copyright, active')
    .eq('teacher_id', teacherId)
    .eq('active', true)
    .maybeSingle();
  return (data as BrandingConfig | null) ?? null;
}

/** Upsert branding config for a teacher (only pro/institution can hide OSEE branding). */
export async function upsertBrandingConfig(
  env: Env,
  teacherId: string,
  patch: Partial<BrandingConfig>
): Promise<BrandingConfig> {
  const supabase = getSupabase(env);

  // Check teacher tier — only pro/institution can hide OSEE branding or set custom subdomain
  const tier = await getTeacherTier(env, teacherId);
  const canHideBranding = tier.tier !== 'free';
  const canUseSubdomain = tier.tier === 'institution';

  const insert: Record<string, unknown> = {
    teacher_id: teacherId,
    logo_url: patch.logo_url ?? null,
    primary_color: patch.primary_color ?? '#CCFF00',
    secondary_color: patch.secondary_color ?? '#000000',
    custom_subdomain: canUseSubdomain ? (patch.custom_subdomain ?? null) : null,
    hide_osee_branding: canHideBranding ? Boolean(patch.hide_osee_branding) : false,
    custom_copyright: patch.custom_copyright ?? null,
    active: true,
  };

  // Deactivate previous configs then insert new one
  await supabase.from('branding_configs').update({ active: false }).eq('teacher_id', teacherId);
  const { data, error } = await supabase
    .from('branding_configs')
    .insert(insert)
    .select()
    .single();

  if (error || !data) {
    throw new Error(`Branding upsert failed: ${error?.message ?? 'unknown'}`);
  }
  return data as unknown as BrandingConfig;
}

/** Get current tier for a teacher (reads teacher_profiles + teacher_subscriptions). */
export async function getTeacherTier(env: Env, teacherId: string): Promise<TierInfo> {
  const supabase = getSupabase(env);
  const { data: profile } = await supabase
    .from('teacher_profiles')
    .select('tier, tier_expires_at')
    .eq('user_id', teacherId)
    .maybeSingle();
  const p = (profile as Record<string, unknown> | null) ?? {};
  const tier = (p.tier as 'free' | 'pro' | 'institution') ?? 'free';
  const expiresAt = (p.tier_expires_at as string) ?? null;

  const features =
    tier === 'free'
      ? ['AI grading: 50/month', 'AI generation: 10/month', 'OSEE branding visible']
      : tier === 'pro'
        ? ['Unlimited AI grading', 'Unlimited AI generation', 'Classroom reports', 'Hide OSEE branding', 'Priority support']
        : ['Everything in Pro', 'Custom subdomain', 'Multi-teacher accounts', 'Admin dashboard', 'White-label fully'];

  return {
    tier,
    tier_expires_at: expiresAt,
    monthly_fee_idr: TIER_PRICING[tier] ?? 0,
    features,
  };
}

/** Upgrade teacher to Pro or Institution tier (Task 15.2). */
export async function upgradeTeacherTier(
  env: Env,
  teacherId: string,
  newTier: 'pro' | 'institution',
  paymentReference?: string
): Promise<{ success: boolean; tier: string; expires_at: string }> {
  const supabase = getSupabase(env);
  const monthlyFee = TIER_PRICING[newTier] ?? 0;
  const now = new Date();
  const expiresAt = new Date(now);
  expiresAt.setMonth(expiresAt.getMonth() + 1);

  // Update teacher_profiles.tier
  const { error: profileErr } = await supabase
    .from('teacher_profiles')
    .update({
      tier: newTier,
      tier_expires_at: expiresAt.toISOString(),
      updated_at: now.toISOString(),
    })
    .eq('user_id', teacherId);
  if (profileErr) {
    throw new Error(`Tier update failed: ${profileErr.message}`);
  }

  // Create teacher_subscriptions row
  await supabase.from('teacher_subscriptions').insert({
    teacher_id: teacherId,
    tier: newTier,
    monthly_fee_idr: monthlyFee,
    started_at: now.toISOString(),
    expires_at: expiresAt.toISOString(),
    auto_renew: true,
    payment_reference: paymentReference ?? null,
    is_active: true,
  });

  return { success: true, tier: newTier, expires_at: expiresAt.toISOString() };
}

/** Cancel subscription — revert to free tier. */
export async function cancelTeacherTier(env: Env, teacherId: string): Promise<{ success: boolean }> {
  const supabase = getSupabase(env);
  const now = new Date().toISOString();
  await supabase
    .from('teacher_profiles')
    .update({ tier: 'free', tier_expires_at: null, updated_at: now })
    .eq('user_id', teacherId);
  await supabase
    .from('teacher_subscriptions')
    .update({ is_active: false, expires_at: now })
    .eq('teacher_id', teacherId)
    .eq('is_active', true);
  return { success: true };
}