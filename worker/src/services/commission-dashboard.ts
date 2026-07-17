import type { Env } from '../types';
import { getSupabase } from './supabase';
import { getPartnerTeacherIds } from './partner';

/**
 * Commission service — Task 12.x.
 *
 * Wraps the existing `commission.ts` (Task 3.4) with dashboard-querying functionality.
 */

export interface CommissionStats {
  total_earned: number;
  this_month: number;
  pending_amount: number;
  paid_amount: number;
  by_type: Record<string, number>;
  recent_entries: Array<{
    id: string;
    type: string;
    amount: number;
    status: string;
    student_name: string | null;
    created_at: string;
  }>;
}

/** Get commission stats for a teacher (or partner via combined teachers). */
export async function getCommissionStats(env: Env, teacherId: string): Promise<CommissionStats> {
  const supabase = getSupabase(env);

  const { data: entries } = await supabase
    .from('commission_ledger')
    .select('id, action, amount_idr, status, created_at, student_id')
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false })
    .limit(100);

  const rows = (entries ?? []) as Array<Record<string, unknown>>;
  const now = new Date();
  const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);

  let totalEarned = 0;
  let thisMonth = 0;
  let pendingAmount = 0;
  let paidAmount = 0;
  const byType: Record<string, number> = {};

  for (const r of rows) {
    const amount = r.amount_idr as number;
    const status = r.status as string;
    const type = r.action as string;
    const createdAt = new Date(r.created_at as string);

    totalEarned += amount;
    if (createdAt >= thisMonthStart) thisMonth += amount;
    if (status === 'pending') pendingAmount += amount;
    if (status === 'paid') paidAmount += amount;
    byType[type] = (byType[type] ?? 0) + amount;
  }

  // Get student names for recent entries
  const studentIds = Array.from(new Set(rows.slice(0, 10).map((r) => r.student_id as string)));
  let studentMap: Record<string, string> = {};
  if (studentIds.length > 0) {
    const { data: students } = await supabase
      .from('unified_profiles')
      .select('id, display_name')
      .in('id', studentIds);
    if (students) {
      studentMap = Object.fromEntries(
        (students as Array<Record<string, unknown>>).map((s) => [s.id as string, s.display_name as string])
      );
    }
  }

  return {
    total_earned: totalEarned,
    this_month: thisMonth,
    pending_amount: pendingAmount,
    paid_amount: paidAmount,
    by_type: byType,
    recent_entries: rows.slice(0, 20).map((r) => ({
      id: r.id as string,
      type: r.action as string,
      amount: r.amount_idr as number,
      status: r.status as string,
      student_name: studentMap[r.student_id as string] ?? null,
      created_at: r.created_at as string,
    })),
  };
}

/** Get commission stats aggregated across all teachers in a partner's
 *  institution. Used by the partner portal commission dashboard (Goal 9). */
export async function getPartnerCommissionStats(env: Env, partnerId: string): Promise<CommissionStats> {
  const supabase = getSupabase(env);
  const teacherIds = await getPartnerTeacherIds(env, partnerId);
  if (teacherIds.length === 0) {
    return {
      total_earned: 0,
      this_month: 0,
      pending_amount: 0,
      paid_amount: 0,
      by_type: {},
      recent_entries: [],
    };
  }

  const { data: entries } = await supabase
    .from('commission_ledger')
    .select('id, action, amount_idr, status, created_at, student_id, teacher_id')
    .in('teacher_id', teacherIds)
    .order('created_at', { ascending: false })
    .limit(200);

  const rows = (entries ?? []) as Array<Record<string, unknown>>;
  const now = new Date();
  const thisMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);

  let totalEarned = 0;
  let thisMonth = 0;
  let pendingAmount = 0;
  let paidAmount = 0;
  const byType: Record<string, number> = {};

  for (const r of rows) {
    const amount = r.amount_idr as number;
    const status = r.status as string;
    const type = r.action as string;
    const createdAt = new Date(r.created_at as string);

    totalEarned += amount;
    if (createdAt >= thisMonthStart) thisMonth += amount;
    if (status === 'pending') pendingAmount += amount;
    if (status === 'paid') paidAmount += amount;
    byType[type] = (byType[type] ?? 0) + amount;
  }

  // Get student names for recent entries
  const studentIds = Array.from(new Set(rows.slice(0, 10).map((r) => r.student_id as string)));
  let studentMap: Record<string, string> = {};
  if (studentIds.length > 0) {
    const { data: students } = await supabase
      .from('unified_profiles')
      .select('id, display_name')
      .in('id', studentIds);
    if (students) {
      studentMap = Object.fromEntries(
        (students as Array<Record<string, unknown>>).map((s) => [s.id as string, s.display_name as string])
      );
    }
  }

  return {
    total_earned: totalEarned,
    this_month: thisMonth,
    pending_amount: pendingAmount,
    paid_amount: paidAmount,
    by_type: byType,
    recent_entries: rows.slice(0, 20).map((r) => ({
      id: r.id as string,
      type: r.action as string,
      amount: r.amount_idr as number,
      status: r.status as string,
      student_name: studentMap[r.student_id as string] ?? null,
      created_at: r.created_at as string,
    })),
  };
}

/** Request a payout (move pending commission to payout_paid status). */
export async function requestPayout(
  env: Env,
  teacherId: string,
  amount: number,
  method: string = 'bank_transfer'
): Promise<{ payout_id: string }> {
  const supabase = getSupabase(env);
  if (amount <= 0) throw new Error('Amount must be positive');

  // Verify available balance
  const stats = await getCommissionStats(env, teacherId);
  if (stats.pending_amount < amount) {
    throw new Error(`Insufficient balance: ${stats.pending_amount} available, ${amount} requested`);
  }

  // Create payout request
  const { data, error } = await supabase
    .from('commission_payouts')
    .insert({
      teacher_id: teacherId,
      amount,
      method,
      status: 'pending',
      requested_at: new Date().toISOString(),
    })
    .select()
    .single();

  if (error || !data) {
    throw new Error(`Payout request failed: ${error?.message ?? 'unknown'}`);
  }

  return { payout_id: data.id as string };
}

/** List payout history for a teacher (Task 12.3). */
export async function listPayouts(
  env: Env,
  teacherId: string
): Promise<Array<Record<string, unknown>>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('commission_payouts')
    .select('id, amount, method, status, reference, notes, requested_at, processed_at, paid_at')
    .eq('teacher_id', teacherId)
    .order('requested_at', { ascending: false })
    .limit(50);

  if (error) throw new Error(`Failed to fetch payouts: ${error.message}`);
  return (data ?? []) as Array<Record<string, unknown>>;
}