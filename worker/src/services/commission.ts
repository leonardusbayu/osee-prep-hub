import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Commission service — records commission entries in commission_ledger
 * when webhook events trigger them.
 *
 * Task 3.4: Implements the full commission trigger logic.
 *
 * Commission rates are read from `commission_rates` table (configurable by admin).
 * Action names match the seed in schema.sql:
 *   - first_test → Rp 10,000 (student completes first practice test)
 *   - official_booking → Rp 50,000 (student books official test)
 *   - premium_monthly → Rp 15,000/month (student subscribes EduBot premium)
 *   - practice_package → Rp 25,000 (student purchases practice package)
 *   - Ambassador actions: ambassador_first_test (2x), ambassador_booking (2x), ambassador_premium_monthly (2x)
 *
 * Idempotency: checks if commission already recorded for the same
 * student + action to prevent double-payments.
 *
 * Also updates `teacher_referrals` table with commission tracking columns.
 */

export interface CommissionInput {
  user_id: string; // the student's user ID
  event_type: string;
  platform: string;
  payload: Record<string, unknown>;
}

/** Map webhook event_type → commission_rates action name. */
const EVENT_ACTION_MAP: Record<string, { normal: string; ambassador: string }> = {
  practice_completed: { normal: 'first_test', ambassador: 'ambassador_first_test' },
  test_completed: { normal: 'first_test', ambassador: 'ambassador_first_test' },
  test_booked: { normal: 'official_booking', ambassador: 'ambassador_booking' },
  official_booking: { normal: 'official_booking', ambassador: 'ambassador_booking' },
  premium_subscribed: { normal: 'premium_monthly', ambassador: 'ambassador_premium_monthly' },
  practice_package_purchased: { normal: 'practice_package', ambassador: 'practice_package' },
};

/** Get commission rate from DB. Returns 0 if not found. */
async function getCommissionRate(
  supabase: import('@supabase/supabase-js').SupabaseClient,
  action: string
): Promise<number> {
  const { data } = await supabase
    .from('commission_rates')
    .select('rate_idr')
    .eq('action', action)
    .eq('active', true)
    .maybeSingle();
  return ((data as Record<string, unknown> | null)?.rate_idr as number) ?? 0;
}

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
    return; // No referring teacher — no commission
  }

  const teacherId = student.referred_by as string;

  // Check if teacher is an ambassador (2x rate) — Task 12.5
  const { data: teacherProfile } = await supabase
    .from('teacher_profiles')
    .select('is_ambassador')
    .eq('user_id', teacherId)
    .maybeSingle();
  const isAmbassador = Boolean((teacherProfile as Record<string, unknown> | null)?.is_ambassador);

  // Determine commission action based on event_type
  const actionMap = EVENT_ACTION_MAP[input.event_type];
  if (!actionMap) {
    return; // No commission for this event type
  }

  const action = isAmbassador ? actionMap.ambassador : actionMap.normal;

  // For first_test: check if already paid (idempotency)
  if (action === 'first_test' || action === 'ambassador_first_test') {
    const { data: existing } = await supabase
      .from('commission_ledger')
      .select('id')
      .eq('student_id', input.user_id)
      .in('action', ['first_test', 'ambassador_first_test'])
      .maybeSingle();
    if (existing) {
      return; // Already paid — idempotency
    }
  }

  // Get rate from DB (configurable by admin)
  const baseAmount = await getCommissionRate(supabase, action);
  if (baseAmount === 0) {
    console.warn(`Commission rate for action '${action}' not found or 0 — skipping`);
    return;
  }

  // Insert commission entry — schema columns: action, amount_idr, reference_id, notes
  const { error } = await supabase.from('commission_ledger').insert({
    teacher_id: teacherId,
    student_id: input.user_id,
    action,
    amount_idr: baseAmount,
    status: 'pending',
    reference_id: input.platform,
    notes: `${input.event_type} from ${input.platform}${isAmbassador ? ' (ambassador 2x)' : ''}`,
    created_at: new Date().toISOString(),
  });

  if (error) {
    if (error.code === '23505') {
      return; // Duplicate — idempotency
    }
    throw new Error(`Failed to record commission: ${error.message}`);
  }

  // Update teacher_referrals tracking columns (blueprint line 2242-2282)
  await updateTeacherReferral(supabase, teacherId, input.user_id, action, baseAmount, input.event_type);
}

/** Update teacher_referrals table with commission tracking columns. */
async function updateTeacherReferral(
  supabase: import('@supabase/supabase-js').SupabaseClient,
  teacherId: string,
  studentId: string,
  action: string,
  amount: number,
  eventType: string
): Promise<void> {
  const now = new Date().toISOString();
  const update: Record<string, unknown> = {};

  if (action === 'first_test' || action === 'ambassador_first_test') {
    update.first_test_completed_at = now;
    update.first_test_commission = amount;
  } else if (action === 'official_booking' || action === 'ambassador_booking') {
    update.official_test_booked_at = now;
    update.booking_commission = amount;
    update.booking_test_type = (eventType === 'test_booked' ? 'test' : 'official');
  } else if (action === 'premium_monthly' || action === 'ambassador_premium_monthly') {
    update.premium_subscribed_at = now;
    update.premium_commission_monthly = amount;
    update.premium_active = true;
  } else if (action === 'practice_package') {
    update.practice_package_purchased_at = now;
    update.package_commission = amount;
  }

  if (Object.keys(update).length === 0) return;

  // Update total_earned
  const { data: existing } = await supabase
    .from('teacher_referrals')
    .select('total_earned')
    .eq('teacher_id', teacherId)
    .eq('student_id', studentId)
    .maybeSingle();
  const currentTotal = ((existing as Record<string, unknown> | null)?.total_earned as number) ?? 0;
  update.total_earned = currentTotal + amount;

  await supabase
    .from('teacher_referrals')
    .update(update)
    .eq('teacher_id', teacherId)
    .eq('student_id', studentId);
}