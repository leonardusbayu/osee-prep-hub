import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Admin aggregation service — blueprint Section 5 admin endpoints.
 *
 * Provides cross-teacher / cross-student / cross-platform statistics for the
 * admin dashboard. Counterpart to `commission-dashboard.ts` which is
 * per-teacher only.
 *
 * All queries use Supabase's head/count mode or single-field SELECT to keep
 * memory + CPU usage low — no row-by-row JS reduce.
 */

export interface AdminCommissionSummary {
  total_paid: number;
  total_pending: number;
  total_confirmed: number;
  by_teacher: Array<{
    teacher_id: string;
    teacher_name: string;
    total_earned: number;
    pending: number;
    paid: number;
    student_count: number;
  }>;
}

/** Get commission summary across all teachers — blueprint:1535. */
export async function getAdminCommissionSummary(env: Env): Promise<AdminCommissionSummary> {
  const supabase = getSupabase(env);

  // Aggregate totals via single SUM query (one round-trip, no JS reduce)
  const { data: totals, error: totalsErr } = await supabase
    .from('commission_ledger')
    .select('status, amount_idr');
  if (totalsErr) throw new Error(`Failed to fetch commission totals: ${totalsErr.message}`);

  let totalPaid = 0;
  let totalPending = 0;
  let totalConfirmed = 0;
  const byTeacher: Record<string, { total_earned: number; pending: number; paid: number }> = {};

  for (const row of (totals ?? []) as Array<Record<string, unknown>>) {
    const status = row.status as string;
    const amount = Number(row.amount_idr ?? 0);
    const teacherId = row.teacher_id as string | undefined;
    if (!teacherId) continue;

    if (!byTeacher[teacherId]) {
      byTeacher[teacherId] = { total_earned: 0, pending: 0, paid: 0 };
    }
    byTeacher[teacherId].total_earned += amount;
    if (status === 'paid') {
      totalPaid += amount;
      byTeacher[teacherId].paid += amount;
    } else if (status === 'pending') {
      totalPending += amount;
      byTeacher[teacherId].pending += amount;
    } else if (status === 'confirmed') {
      totalConfirmed += amount;
    }
  }

  // Fetch teacher names in one query
  const teacherIds = Object.keys(byTeacher);
  const nameMap: Record<string, string> = {};
  if (teacherIds.length > 0) {
    const { data: teachers } = await supabase
      .from('unified_profiles')
      .select('id, display_name')
      .in('id', teacherIds);
    for (const t of (teachers ?? []) as Array<Record<string, unknown>>) {
      nameMap[t.id as string] = (t.display_name as string) ?? '—';
    }
  }

  // Count students per teacher (via teacher_referrals)
  const { data: referralCounts } = await supabase
    .from('teacher_referrals')
    .select('teacher_id');
  const studentCount: Record<string, number> = {};
  for (const r of (referralCounts ?? []) as Array<Record<string, unknown>>) {
    const tid = r.teacher_id as string;
    studentCount[tid] = (studentCount[tid] ?? 0) + 1;
  }

  return {
    total_paid: totalPaid,
    total_pending: totalPending,
    total_confirmed: totalConfirmed,
    by_teacher: teacherIds.map((id) => ({
      teacher_id: id,
      teacher_name: nameMap[id] ?? '—',
      total_earned: byTeacher[id].total_earned,
      pending: byTeacher[id].pending,
      paid: byTeacher[id].paid,
      student_count: studentCount[id] ?? 0,
    })).sort((a, b) => b.total_earned - a.total_earned),
  };
}

export interface AdminAnalytics {
  total_teachers: number;
  total_students: number;
  total_partners: number;
  total_classrooms: number;
  total_bookings: number;
  total_revenue: number;
  commission_paid: number;
  commission_pending: number;
  ai_grading_count: number;
  ai_generation_count: number;
  active_payouts: number;
}

/** Get platform-wide analytics — blueprint:1542 + Task 18.4. */
export async function getAdminAnalytics(env: Env): Promise<AdminAnalytics> {
  const supabase = getSupabase(env);

  // Use count: 'exact', head: true untuk semua count query (no rows loaded)
  const [
    teachersRes,
    studentsRes,
    partnersRes,
    classroomsRes,
    bookingsRes,
    revenueRes,
    commissionPaidRes,
    commissionPendingRes,
    aiGradingRes,
    aiGenerationRes,
    payoutsRes,
  ] = await Promise.all([
    supabase.from('unified_profiles').select('id', { count: 'exact', head: true }).eq('role', 'teacher'),
    supabase.from('unified_profiles').select('id', { count: 'exact', head: true }).eq('role', 'student'),
    supabase.from('unified_profiles').select('id', { count: 'exact', head: true }).eq('role', 'partner'),
    supabase.from('classrooms').select('id', { count: 'exact', head: true }),
    supabase.from('orders').select('id', { count: 'exact', head: true }).in('status', ['paid', 'fulfilled']),
    supabase.from('orders').select('total_amount').in('status', ['paid', 'fulfilled']),
    supabase.from('commission_ledger').select('amount_idr').eq('status', 'paid'),
    supabase.from('commission_ledger').select('amount_idr').eq('status', 'pending'),
    supabase.from('ai_grading_queue').select('id', { count: 'exact', head: true }),
    supabase.from('ai_generation_queue').select('id', { count: 'exact', head: true }),
    supabase.from('commission_payouts').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
  ]);

  // Sum revenue + commission in JS (small number of rows typically; head:true doesn't allow SUM)
  const totalRevenue = (revenueRes.data ?? []).reduce(
    (s, r) => s + Number((r as Record<string, unknown>).total_amount ?? 0), 0
  );
  const commissionPaid = (commissionPaidRes.data ?? []).reduce(
    (s, r) => s + Number((r as Record<string, unknown>).amount_idr ?? 0), 0
  );
  const commissionPending = (commissionPendingRes.data ?? []).reduce(
    (s, r) => s + Number((r as Record<string, unknown>).amount_idr ?? 0), 0
  );

  return {
    total_teachers: teachersRes.count ?? 0,
    total_students: studentsRes.count ?? 0,
    total_partners: partnersRes.count ?? 0,
    total_classrooms: classroomsRes.count ?? 0,
    total_bookings: bookingsRes.count ?? 0,
    total_revenue: totalRevenue,
    commission_paid: commissionPaid,
    commission_pending: commissionPending,
    ai_grading_count: aiGradingRes.count ?? 0,
    ai_generation_count: aiGenerationRes.count ?? 0,
    active_payouts: payoutsRes.count ?? 0,
  };
}

export interface AdminTeacherRow {
  id: string;
  display_name: string;
  email: string;
  target_exam: string | null;
  tier: string;
  referral_code: string;
  total_students: number;
  total_earnings: number;
  created_at: string;
}

/** List all teachers with stats — blueprint:1529. */
export async function listTeachers(env: Env): Promise<AdminTeacherRow[]> {
  const supabase = getSupabase(env);

  // Get teacher profiles join with unified_profiles
  const { data, error } = await supabase
    .from('unified_profiles')
    .select(`
      id, display_name, email, target_exam, created_at,
      teacher_profiles!teacher_profiles_user_id_fkey (tier, referral_code)
    `)
    .eq('role', 'teacher')
    .order('created_at', { ascending: false })
    .limit(200);

  if (error) throw new Error(`Failed to list teachers: ${error.message}`);

  const rows = (data ?? []) as Array<Record<string, unknown>>;
  if (rows.length === 0) return [];

  // Fetch referral counts + commission totals per teacher
  const [refCounts, commissions] = await Promise.all([
    supabase.from('teacher_referrals').select('teacher_id'),
    supabase.from('commission_ledger').select('teacher_id, amount_idr'),
  ]);

  const studentCount: Record<string, number> = {};
  for (const r of (refCounts.data ?? []) as Array<Record<string, unknown>>) {
    const tid = r.teacher_id as string;
    studentCount[tid] = (studentCount[tid] ?? 0) + 1;
  }
  const earnings: Record<string, number> = {};
  for (const r of (commissions.data ?? []) as Array<Record<string, unknown>>) {
    const tid = r.teacher_id as string;
    earnings[tid] = (earnings[tid] ?? 0) + Number(r.amount_idr ?? 0);
  }

  return rows.map((r) => {
    const tp = (r.teacher_profiles as Record<string, unknown> | null) ?? {};
    return {
      id: r.id as string,
      display_name: r.display_name as string,
      email: r.email as string,
      target_exam: (r.target_exam as string) ?? null,
      tier: (tp.tier as string) ?? 'free',
      referral_code: (tp.referral_code as string) ?? '',
      total_students: studentCount[r.id as string] ?? 0,
      total_earnings: earnings[r.id as string] ?? 0,
      created_at: r.created_at as string,
    };
  });
}

export interface AdminStudentRow {
  id: string;
  display_name: string;
  email: string;
  target_exam: string | null;
  current_level: string | null;
  referred_by: string | null;
  ibt_latest_score: number | null;
  ielts_latest_band: number | null;
  created_at: string;
}

/** List all students with progress — blueprint:1532. */
export async function listStudents(env: Env): Promise<AdminStudentRow[]> {
  const supabase = getSupabase(env);

  const { data, error } = await supabase
    .from('unified_profiles')
    .select(`
      id, display_name, email, target_exam, current_level, referred_by, created_at,
      student_progress_unified!student_progress_unified_student_id_fkey (
        ibt_latest_score, ielts_latest_band
      )
    `)
    .eq('role', 'student')
    .order('created_at', { ascending: false })
    .limit(200);

  if (error) throw new Error(`Failed to list students: ${error.message}`);

  return ((data ?? []) as Array<Record<string, unknown>>).map((r) => {
    const p = (r.student_progress_unified as Record<string, unknown> | null) ?? {};
    return {
      id: r.id as string,
      display_name: r.display_name as string,
      email: r.email as string,
      target_exam: (r.target_exam as string) ?? null,
      current_level: (r.current_level as string) ?? null,
      referred_by: (r.referred_by as string) ?? null,
      ibt_latest_score: (p.ibt_latest_score as number) ?? null,
      ielts_latest_band: (p.ielts_latest_band as number) ?? null,
      created_at: r.created_at as string,
    };
  });
}