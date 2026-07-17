import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Recurring premium-commission service — Blueprint line 64.
 *
 * "Rp 15k/month per student on EduBot premium (recurring)"
 *
 * The `premium_subscribed` webhook event credits the FIRST Rp 15k + records
 * `premium_commission_monthly = 15000` on the student's progress row. This
 * service credits the Rp 15k again each subsequent month for active premium
 * subscribers, so the recurring monthly commission actually recurs.
 *
 * Idempotent: uses a `last_premium_credit_at` timestamp on the student's
 * progress row to ensure we only credit once per 30-day window.
 */

const PREMIUM_COMMISSION_IDR = 15000;
const CREDIT_WINDOW_DAYS = 30;

export async function creditRecurringPremiumCommission(env: Env): Promise<{ credited: number; skipped: number }> {
  const supabase = getSupabase(env);

  // Find students with an active premium subscription (last_premium_credit_at
  // is null OR older than 30 days). Join unified_profiles to get referred_by.
  const cutoff = new Date(Date.now() - CREDIT_WINDOW_DAYS * 24 * 60 * 60 * 1000).toISOString();
  const { data: eligibleStudents, error } = await supabase
    .from('student_progress_unified')
    .select(`
      student_id,
      last_premium_credit_at,
      student:unified_profiles!student_progress_unified_student_id_fkey (referred_by)
    `)
    .eq('has_premium', true)
    .or(`last_premium_credit_at.is.null,last_premium_credit_at.lt.${cutoff}`)
    .limit(500);

  if (error) {
    throw new Error(`premium commission query failed: ${error.message}`);
  }

  let credited = 0;
  let skipped = 0;
  const rows = (eligibleStudents ?? []) as Array<Record<string, unknown>>;
  for (const row of rows) {
    const studentId = row.student_id as string;
    const studentObj = row.student as Record<string, unknown> | null;
    const referredBy = (studentObj?.referred_by as string | null) ?? null;
    if (!referredBy) {
      // No referring teacher — no commission to credit.
      skipped++;
      continue;
    }
    const now = new Date().toISOString();
    // Credit the recurring Rp 15k to the referring teacher.
    const { error: ledgerErr } = await supabase.from('commission_ledger').insert({
      teacher_id: referredBy,
      student_id: studentId,
      action: 'premium_monthly_recurring',
      amount_idr: PREMIUM_COMMISSION_IDR,
      notes: 'Monthly recurring EduBot premium commission (auto-credited by cron)',
    });
    if (ledgerErr) {
      console.error(`premium commission ledger insert failed for student ${studentId}:`, ledgerErr.message);
      skipped++;
      continue;
    }
    // Mark the credit timestamp so we don't double-credit within 30 days.
    await supabase
      .from('student_progress_unified')
      .update({ last_premium_credit_at: now })
      .eq('student_id', studentId);
    credited++;
  }

  return { credited, skipped };
}