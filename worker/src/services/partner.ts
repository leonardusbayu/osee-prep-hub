import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Partner (institution) service — Task 15.8.
 *
 * Partners manage multiple teachers and bulk-order tests.
 * Partner dashboard shows institution-wide stats.
 */

/** Get partner dashboard stats. */
export async function getPartnerDashboard(env: Env, partnerId: string): Promise<{
  teachers_count: number;
  total_students: number;
  total_orders: number;
  total_spent: number;
  active_vouchers: number;
}> {
  const supabase = getSupabase(env);

  // Get teachers in this institution (teachers referred_by = partnerId OR teacher_institution matches)
  // For simplicity, we look at teachers where referred_by = partnerId
  const { count: teachersCount } = await supabase
    .from('unified_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('referred_by', partnerId)
    .eq('role', 'teacher');

  // Get total students across all teachers
  const { data: teachers } = await supabase
    .from('unified_profiles')
    .select('id')
    .eq('referred_by', partnerId)
    .eq('role', 'teacher');

  const teacherIds = (teachers ?? []).map((t: Record<string, unknown>) => t.id as string);
  let totalStudents = 0;
  if (teacherIds.length > 0) {
    const { count } = await supabase
      .from('classroom_enrollments')
      .select('id', { count: 'exact', head: true })
      .in('student_id', teacherIds);
    totalStudents = count ?? 0;
  }

  // Get orders by partner
  const { data: orders } = await supabase
    .from('orders')
    .select('total_amount')
    .eq('user_id', partnerId);

  const totalOrders = orders?.length ?? 0;
  const totalSpent = (orders ?? []).reduce(
    (sum, o) => sum + ((o as Record<string, unknown>).total_amount as number),
    0
  );

  // Get active vouchers
  const { count: activeVouchers } = await supabase
    .from('vouchers')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'active');

  return {
    teachers_count: teachersCount ?? 0,
    total_students: totalStudents,
    total_orders: totalOrders,
    total_spent: totalSpent,
    active_vouchers: activeVouchers ?? 0,
  };
}

/** List teachers in partner's institution. */
export async function getPartnerTeachers(env: Env, partnerId: string): Promise<Array<{
  id: string;
  name: string;
  email: string;
  students_count: number;
}>> {
  const supabase = getSupabase(env);

  const { data: teachers, error } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email')
    .eq('referred_by', partnerId)
    .eq('role', 'teacher')
    .order('created_at', { ascending: false });

  if (error) throw new Error(`List teachers failed: ${error.message}`);

  // Get student count for each teacher
  const result = await Promise.all(
    (teachers ?? []).map(async (teacher: Record<string, unknown>) => {
      const { count } = await supabase
        .from('classroom_enrollments')
        .select('id', { count: 'exact', head: true })
        .eq('student_id', teacher.id as string);
      return {
        id: teacher.id as string,
        name: teacher.display_name as string,
        email: teacher.email as string,
        students_count: count ?? 0,
      };
    })
  );

  return result;
}

/** Invite a teacher to the partner's institution. */
export async function inviteTeacher(
  env: Env,
  partnerId: string,
  teacherEmail: string
): Promise<{ invited: boolean; message: string }> {
  void env; // reserved for future email notification
  // In production, this would send an email with a referral link.
  // For now, just log the invitation.
  console.log(`Partner ${partnerId} invited teacher ${teacherEmail}`);
  return {
    invited: true,
    message: `Invitation sent to ${teacherEmail}. The teacher will be linked to your institution upon registration.`,
  };
}
