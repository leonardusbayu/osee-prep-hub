import type { Env } from '../types';
import { getSupabase } from './supabase';
import { createInvitation, InvitationError } from './teacher-invitations';

/**
 * Partner (institution) service — Task 15.8.
 *
 * Partners manage multiple teachers and bulk-order tests.
 * Partner dashboard shows institution-wide stats.
 *
 * Teachers belong to an institution if EITHER:
 *   - they were referred by the partner (referred_by = partnerId), OR
 *   - they were invited by the partner and set teacher_institution on register.
 * The helper below resolves both into a single teacher-ID list.
 */

/** Resolve the partner's institution name. */
async function getPartnerInstitution(env: Env, partnerId: string): Promise<string | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('unified_profiles')
    .select('teacher_institution')
    .eq('id', partnerId)
    .maybeSingle();
  return (data as Record<string, unknown> | null)?.teacher_institution as string | null;
}

/** Resolve all teacher IDs belonging to this partner's institution. */
export async function getPartnerTeacherIds(env: Env, partnerId: string): Promise<string[]> {
  const supabase = getSupabase(env);
  const institution = await getPartnerInstitution(env, partnerId);

  // Teachers referred by this partner.
  const { data: referred } = await supabase
    .from('unified_profiles')
    .select('id')
    .eq('referred_by', partnerId)
    .eq('role', 'teacher');
  const referredIds = (referred ?? []).map((r: Record<string, unknown>) => r.id as string);

  // Teachers whose teacher_institution matches this partner's institution.
  let institutionIds: string[] = [];
  if (institution) {
    const { data: instTeachers } = await supabase
      .from('unified_profiles')
      .select('id')
      .eq('teacher_institution', institution)
      .eq('role', 'teacher');
    institutionIds = (instTeachers ?? []).map((r: Record<string, unknown>) => r.id as string);
  }

  // Union (dedupe).
  return [...new Set([...referredIds, ...institutionIds])];
}

/** Get partner dashboard stats. */
export async function getPartnerDashboard(env: Env, partnerId: string): Promise<{
  teachers_count: number;
  total_students: number;
  total_orders: number;
  total_spent: number;
  active_vouchers: number;
}> {
  const supabase = getSupabase(env);

  const teacherIds = await getPartnerTeacherIds(env, partnerId);
  let totalStudents = 0;
  if (teacherIds.length > 0) {
    // Count students enrolled in classrooms owned by these teachers
    const { data: classroomIds } = await supabase
      .from('classrooms')
      .select('id')
      .in('teacher_id', teacherIds);
    const cIds = (classroomIds ?? []).map((c: Record<string, unknown>) => c.id as string);
    if (cIds.length > 0) {
      const { count } = await supabase
        .from('classroom_enrollments')
        .select('id', { count: 'exact', head: true })
        .in('classroom_id', cIds)
        .eq('is_active', true);
      totalStudents = count ?? 0;
    }
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

  // Get active vouchers for THIS partner (scope by order_items → orders.user_id)
  let activeVouchers = 0;
  if (totalOrders > 0) {
    const { data: orderItems } = await supabase
      .from('order_items')
      .select('id')
      .eq('order_id', await supabase.from('orders').select('id').eq('user_id', partnerId).then(r => (r.data ?? []).map((o: Record<string, unknown>) => o.id as string)));
    const itemIds = (orderItems ?? []).map((i: Record<string, unknown>) => i.id as string);
    if (itemIds.length > 0) {
      const { count } = await supabase
        .from('vouchers')
        .select('id', { count: 'exact', head: true })
        .in('order_item_id', itemIds)
        .eq('status', 'active');
      activeVouchers = count ?? 0;
    }
  }

  return {
    teachers_count: teacherIds.length,
    total_students: totalStudents,
    total_orders: totalOrders,
    total_spent: totalSpent,
    active_vouchers: activeVouchers,
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
  const teacherIds = await getPartnerTeacherIds(env, partnerId);
  if (teacherIds.length === 0) return [];

  const { data: teachers, error } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email')
    .in('id', teacherIds)
    .order('created_at', { ascending: false });

  if (error) throw new Error(`List teachers failed: ${error.message}`);

  // Get student count for each teacher via classrooms → enrollments (NOT
  // classroom_enrollments.student_id = teacher.id, which counted the teacher
  // as a student — the old bug).
  const result = await Promise.all(
    (teachers ?? []).map(async (teacher: Record<string, unknown>) => {
      const { data: classrooms } = await supabase
        .from('classrooms')
        .select('id')
        .eq('teacher_id', teacher.id as string);
      const cIds = (classrooms ?? []).map((c: Record<string, unknown>) => c.id as string);
      let count = 0;
      if (cIds.length > 0) {
        const { count: c } = await supabase
          .from('classroom_enrollments')
          .select('id', { count: 'exact', head: true })
          .in('classroom_id', cIds)
          .eq('is_active', true);
        count = c ?? 0;
      }
      return {
        id: teacher.id as string,
        name: teacher.display_name as string,
        email: teacher.email as string,
        students_count: count,
      };
    })
  );

  return result;
}

/** List students belonging to this partner's institution (across all its teachers). */
export async function getPartnerStudents(env: Env, partnerId: string): Promise<Array<{
  id: string;
  name: string;
  email: string;
  classroom_name: string | null;
  teacher_name: string | null;
}>> {
  const supabase = getSupabase(env);
  const teacherIds = await getPartnerTeacherIds(env, partnerId);
  if (teacherIds.length === 0) return [];

  // classrooms owned by these teachers, with teacher name
  const { data: classrooms } = await supabase
    .from('classrooms')
    .select('id, name, teacher:unified_profiles!classrooms_teacher_id_fkey(display_name)')
    .in('teacher_id', teacherIds);
  const classroomRows = (classrooms ?? []) as Array<Record<string, unknown>>;
  const classroomIdToName = new Map(classroomRows.map((c) => [c.id as string, c.name as string]));
  const classroomIdToTeacher = new Map(
    classroomRows.map((c) => [c.id as string, (c.teacher as Record<string, unknown>)?.display_name as string | null])
  );
  const cIds = classroomRows.map((c) => c.id as string);
  if (cIds.length === 0) return [];

  // active enrollments in those classrooms
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select('student_id, classroom_id')
    .in('classroom_id', cIds)
    .eq('is_active', true);
  const enrollmentRows = (enrollments ?? []) as Array<Record<string, unknown>>;
  const studentIds = [...new Set(enrollmentRows.map((e) => e.student_id as string))];
  if (studentIds.length === 0) return [];

  // student profiles
  const { data: students } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email')
    .in('id', studentIds);
  const studentMap = new Map(
    (students ?? []).map((s: Record<string, unknown>) => [s.id as string, s])
  );

  // build the roster (one row per enrollment so classroom + teacher are visible)
  return enrollmentRows.map((e) => {
    const sid = e.student_id as string;
    const cid = e.classroom_id as string;
    const s = (studentMap.get(sid) ?? {}) as Record<string, unknown>;
    return {
      id: sid,
      name: (s.display_name as string) ?? '—',
      email: (s.email as string) ?? '—',
      classroom_name: classroomIdToName.get(cid) ?? null,
      teacher_name: classroomIdToTeacher.get(cid) ?? null,
    };
  });
}

/** Invite a teacher to the partner's institution. */
export async function inviteTeacher(
  env: Env,
  partnerId: string,
  teacherEmail: string
): Promise<{ invited: boolean; message: string; invitation_id?: string; email_sent?: boolean; email_error?: string }> {
  const supabase = getSupabase(env);

  // Check if teacher already exists
  const { data: existing } = await supabase
    .from('unified_profiles')
    .select('id, teacher_institution')
    .eq('email', teacherEmail.toLowerCase())
    .eq('role', 'teacher')
    .maybeSingle();

  if (existing) {
    // Link existing teacher to this institution
    const { data: partner } = await supabase
      .from('unified_profiles')
      .select('teacher_institution')
      .eq('id', partnerId)
      .maybeSingle();
    const institution = (partner as Record<string, unknown> | null)?.teacher_institution as string | null;
    if (institution) {
      await supabase
        .from('unified_profiles')
        .update({ teacher_institution: institution })
        .eq('id', (existing as Record<string, unknown>).id as string);
    }
    return {
      invited: true,
      message: `${teacherEmail} linked to ${institution ?? 'your institution'}`,
    };
  }

  // Teacher doesn't exist yet — create a persisted, token-gated invitation
  // and email the teacher a registration link.
  try {
    const result = await createInvitation(env, partnerId, teacherEmail);
    const message = result.email_sent
      ? `Invitation email sent to ${teacherEmail}. They will be linked to ${result.invitation.institution_name} upon registration.`
      : `Invitation created for ${teacherEmail}, but email delivery failed${result.email_error ? ` (${result.email_error})` : ''}. Share the link manually: ${result.inviteUrl}`;
    return {
      invited: true,
      message,
      invitation_id: result.invitation.id,
      email_sent: result.email_sent,
      email_error: result.email_error,
    };
  } catch (err) {
    if (err instanceof InvitationError) {
      throw new Error(`Invitation failed: ${err.message}`);
    }
    throw err;
  }
}
