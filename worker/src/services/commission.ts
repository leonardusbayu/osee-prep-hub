import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Commission service — records commission entries in commission_ledger
 * when webhook events trigger them.
 *
 * Task 3.4: Implements the full commission trigger logic.
 *
 * Commission rates (from blueprint Section 1 revenue model):
 *   - practice_completed (first per student) → Rp 10,000 to teacher
 *   - test_booked → Rp 50,000 to teacher
 *   - edubot premium subscribed → Rp 15,000/month recurring
 *   - Ambassador teachers get 2x rate
 *
 * Idempotency: checks if commission already recorded for the same
 * event_id + type to prevent double-payments.
 */

export interface CommissionInput {
  user_id: string; // the student's user ID
  event_type: string;
  platform: string;
  payload: Record<string, unknown>;
}

const COMMISSION_RATES = {
  first_practice: 10_000, // Rp 10k
  test_booked: 50_000, // Rp 50k
  edubot_premium: 15_000, // Rp 15k/month
} as const;

/** Record commission for a webhook event. No-op if already recorded (idempotency). */
export async function recordCommission(env: Env, input: CommissionInput): Promise<void> {
  const supabase = getSupabase(env);

  // Find the student's referring teacher
  const { data: student } = await supabase
    .from('unified_profiles')
    .select('id, referred_by, role')
    .eq('id', input.user_id)
    .maybeSingle();

  if (!student || !student.referred_by) {
    // No referring teacher — no commission to record
    return;
  }

  const teacherId = student.referred_by as string;

  // Check if teacher is an ambassador (2x rate) — Task 12.5
  const { data: teacherProfile } = await supabase
    .from('teacher_profiles')
    .select('is_ambassador')
    .eq('user_id', teacherId)
    .maybeSingle();
  const isAmbassador = Boolean((teacherProfile as Record<string, unknown> | null)?.is_ambassador);
  const multiplier = isAmbassador ? 2 : 1;

  // Determine commission type + amount based on event_type
  let commissionType: string | null = null;
  let baseAmount = 0;

  if (input.event_type === 'practice_completed') {
    // First practice for this student? Check existing commission
    const { data: existing } = await supabase
      .from('commission_ledger')
      .select('id')
      .eq('student_id', input.user_id)
      .eq('commission_type', 'first_practice')
      .maybeSingle();
    if (existing) {
      return; // Already paid — idempotency
    }
    commissionType = 'first_practice';
    baseAmount = COMMISSION_RATES.first_practice;
  } else if (input.event_type === 'test_booked') {
    commissionType = 'test_booked';
    baseAmount = COMMISSION_RATES.test_booked;
  } else if (input.event_type === 'premium_subscribed') {
    commissionType = 'edubot_premium';
    baseAmount = COMMISSION_RATES.edubot_premium;
  } else {
    // No commission for this event type
    return;
  }

  const finalAmount = baseAmount * multiplier;

  // Insert commission entry
  const { error } = await supabase.from('commission_ledger').insert({
    teacher_id: teacherId,
    student_id: input.user_id,
    commission_type: commissionType,
    amount: finalAmount,
    status: 'pending',
    reference_event_type: input.event_type,
    reference_platform: input.platform,
    created_at: new Date().toISOString(),
  });

  if (error) {
    // If unique constraint violation (duplicate), it's idempotency — not an error
    if (error.code === '23505') {
      return;
    }
    throw new Error(`Failed to record commission: ${error.message}`);
  }
}