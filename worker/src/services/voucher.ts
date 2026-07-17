import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Voucher redemption service — Task 15.9.
 *
 * Validates voucher codes, marks as redeemed, grants platform access.
 * For mock-test vouchers: sends webhook to practice platform granting session access.
 * For Tutor Bot premium: bridges to EduBot to activate premium subscription.
 */

const PLATFORM_WEBHOOK_URLS: Record<string, string> = {
  mock_itp: 'https://test.osee.co.id/api/voucher/redeem',
  mock_ibt: 'https://ibt.osee.co.id/api/voucher/redeem',
  mock_ielts: 'https://ielts.osee.co.id/api/voucher/redeem',
  mock_toeic: 'https://toeic.osee.co.id/api/voucher/redeem',
  tutor_bot_premium: 'https://edubot-webapp.pages.dev/api/voucher/redeem',
};

export interface VoucherValidation {
  valid: boolean;
  item_type: string | null;
  status: string | null;
  expires_at: string | null;
  assigned_student_id: string | null;
}

/** Validate a voucher code without redeeming. */
export async function validateVoucher(env: Env, code: string): Promise<VoucherValidation> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('vouchers')
    .select('item_type, status, expires_at, order_items(assigned_student_id)')
    .eq('code', code.toUpperCase())
    .maybeSingle();

  if (error || !data) {
    return { valid: false, item_type: null, status: null, expires_at: null, assigned_student_id: null };
  }

  const voucher = data as Record<string, unknown>;
  const orderItem = voucher.order_items as Record<string, unknown> | null;
  const status = voucher.status as string;
  const expiresAt = voucher.expires_at as string;

  const isExpired = expiresAt && new Date(expiresAt).getTime() < Date.now();
  const isValid = status === 'active' && !isExpired;

  return {
    valid: isValid,
    item_type: voucher.item_type as string,
    status,
    expires_at: expiresAt,
    assigned_student_id: (orderItem?.assigned_student_id as string) ?? null,
  };
}

/** Redeem a voucher — marks as redeemed, grants platform access. */
export async function redeemVoucher(
  env: Env,
  code: string,
  studentId: string
): Promise<{ redeemed: boolean; item_type: string; access_granted: boolean }> {
  const supabase = getSupabase(env);

  // Validate first
  const validation = await validateVoucher(env, code);
  if (!validation.valid) {
    throw new Error(`Voucher invalid: status=${validation.status}, expired=${validation.expires_at}`);
  }

  // Check if voucher is assigned to a specific student
  if (validation.assigned_student_id && validation.assigned_student_id !== studentId) {
    throw new Error('Voucher assigned to different student');
  }

  // Mark as redeemed
  const { error: updateErr } = await supabase
    .from('vouchers')
    .update({
      status: 'redeemed',
      redeemed_by: studentId,
      redeemed_at: new Date().toISOString(),
    })
    .eq('code', code.toUpperCase())
    .eq('status', 'active');

  if (updateErr) {
    // If unique constraint or similar, it may already be redeemed
    if (updateErr.code === '23505') {
      throw new Error('Voucher already redeemed');
    }
    throw new Error(`Redeem failed: ${updateErr.message}`);
  }

  // Grant platform access (send webhook to practice platform)
  let accessGranted = false;
  try {
    const platformUrl = PLATFORM_WEBHOOK_URLS[validation.item_type ?? ''];
    if (platformUrl) {
      const response = await fetch(platformUrl, {
        method: 'POST',
        headers: {
          'X-Hub-Secret': env.EDUBOT_INTERNAL_SECRET,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          voucher_code: code.toUpperCase(),
          student_id: studentId,
          item_type: validation.item_type,
          source: 'hub-voucher-redeem',
        }),
      });
      accessGranted = response.ok;
      if (!accessGranted) {
        console.warn(`Platform webhook failed for ${validation.item_type}: ${response.status}`);
      }
    }
  } catch (err) {
    console.warn('Platform access grant failed:', err);
  }

  return {
    redeemed: true,
    item_type: validation.item_type ?? '',
    access_granted: accessGranted,
  };
}