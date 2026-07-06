import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Teacher dashboard service — unified view of classes, students, and reporting.
 *
 * Hybrid data source:
 *  1. Hub Supabase (always available): classrooms, enrollments, commission,
 *     AI quota, syllabus progress, referral stats.
 *  2. EduBot bridge (optional fallback): when EDUBOT_API_URL + EDUBOT_INTERNAL_SECRET
 *     are set, enriches each student with XP/streak/accuracy/last-active from EduBot.
 *
 * Report shape returned to GET /api/teacher/dashboard.
 */

export interface DashboardClassroom {
  id: string;
  name: string;
  target_exam: string | null;
  join_code: string;
  student_count: number;
  syllabus_count: number;
  created_at: string;
}

export interface DashboardStudent {
  id: string;
  email: string;
  display_name: string;
  current_level: string | null;
  target_exam: string | null;
  classroom_id: string | null;
  classroom_name: string | null;
  // Unified progress (Hub)
  ibt_latest_score: number | null;
  ielts_latest_band: number | null;
  toeic_latest_score: number | null;
  itp_latest_score: number | null;
  readiness_status: string;
  readiness_pct: number;
  syllabus_completion_pct: number;
  // EduBot enrichment (only if bridge configured)
  edubot_xp: number | null;
  edubot_streak_days: number | null;
  edubot_questions_answered: number | null;
  edubot_accuracy_rate: number | null;
  edubot_last_active: string | null;
}

export interface DashboardReport {
  user: { id: string; name: string; role: string };
  classrooms_count: number;
  total_students: number;
  commission_this_month: number;
  commission_total: number;
  ai_quota_remaining: number;
  ai_quota_used: number;
  referrals_count: number;
  classrooms: DashboardClassroom[];
  students: DashboardStudent[];
  recent_activity: Array<{ event_type: string; timestamp: string; platform: string | null }>;
  edubot_bridge_enabled: boolean;
}

export async function buildTeacherDashboard(env: Env, teacherId: string): Promise<DashboardReport> {
  const supabase = getSupabase(env);

  // ---- Parallel: teacher profile, classrooms, commission ledger, referrals, AI quota ----
  const [
    profileRes,
    classroomsRes,
    commissionRes,
    referralsRes,
    quotaRes,
  ] = await Promise.all([
    supabase.from('unified_profiles').select('id, display_name, role').eq('id', teacherId).maybeSingle(),
    supabase.from('classrooms').select('id, name, target_exam, join_code, created_at').eq('teacher_id', teacherId).order('created_at', { ascending: false }),
    supabase.from('commission_ledger').select('amount_idr, status, created_at').eq('teacher_id', teacherId).order('created_at', { ascending: false }).limit(50),
    supabase.from('teacher_referrals').select('id, student_id').eq('teacher_id', teacherId),
    supabase.from('ai_quota_usage').select('quota_type, used_count, max_count, period_start').eq('user_id', teacherId),
  ]);

  const profile = profileRes.data as { id: string; display_name: string; role: string } | null;
  const classrooms = (classroomsRes.data ?? []) as Array<{ id: string; name: string; target_exam: string | null; join_code: string; created_at: string }>;
  const commissionRows = (commissionRes.data ?? []) as Array<{ amount_idr: number; status: string; created_at: string }>;
  const referrals = (referralsRes.data ?? []) as Array<{ id: string; student_id: string }>;
  const quotaRows = (quotaRes.data ?? []) as Array<{ quota_type: string; used_count: number; max_count: number; period_start: string }>;

  // ---- Commission math: this month + total ----
  const now = new Date();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
  let commissionThisMonth = 0;
  let commissionTotal = 0;
  for (const c of commissionRows) {
    if (c.status === 'confirmed' || c.status === 'paid') {
      commissionTotal += Number(c.amount_idr);
      if (c.created_at >= monthStart) commissionThisMonth += Number(c.amount_idr);
    }
  }

  // ---- AI quota: sum remaining across quota types ----
  let aiQuotaUsed = 0;
  let aiQuotaMax = 0;
  for (const q of quotaRows) {
    aiQuotaUsed += q.used_count;
    aiQuotaMax += q.max_count;
  }
  const aiQuotaRemaining = Math.max(0, aiQuotaMax - aiQuotaUsed);

  // ---- Students: from classroom_enrollments joined to unified_profiles ----
  const classroomIds = classrooms.map((c) => c.id);
  let students: DashboardStudent[] = [];
  if (classroomIds.length > 0) {
    const { data: enrollments, error: enrollErr } = await supabase
      .from('classroom_enrollments')
      .select(`
        classroom_id,
        student:unified_profiles!classroom_enrollments_student_id_fkey (
          id, email, display_name, current_level, target_exam
        )
      `)
      .in('classroom_id', classroomIds)
      .eq('is_active', true);

    if (!enrollErr && enrollments) {
      const studentIds = (enrollments as Array<Record<string, unknown>>).map((e) => (e.student as Record<string, unknown>).id as string);
      const classroomNameById = new Map(classrooms.map((c) => [c.id, c.name]));

      // Fetch unified progress rows for these students in one shot
      let progressByStudent = new Map<string, Record<string, unknown>>();
      if (studentIds.length > 0) {
        const { data: progressRows } = await supabase
          .from('student_progress_unified')
          .select(`
            student_id, ibt_latest_score, ielts_latest_band, toeic_latest_score, itp_latest_score,
            readiness_status, readiness_pct, syllabus_completion_pct,
            edubot_xp, edubot_streak_days, edubot_questions_answered, edubot_accuracy_rate, edubot_last_active
          `)
          .in('student_id', studentIds);
        for (const p of (progressRows ?? []) as Array<Record<string, unknown>>) {
          progressByStudent.set(p.student_id as string, p);
        }
      }

      students = (enrollments as Array<Record<string, unknown>>).map((e) => {
        const s = e.student as Record<string, unknown>;
        const p = progressByStudent.get(s.id as string) ?? {};
        return {
          id: s.id as string,
          email: s.email as string,
          display_name: s.display_name as string,
          current_level: (s.current_level as string) ?? null,
          target_exam: (s.target_exam as string) ?? null,
          classroom_id: (e.classroom_id as string) ?? null,
          classroom_name: classroomNameById.get(e.classroom_id as string) ?? null,
          ibt_latest_score: (p.ibt_latest_score as number) ?? null,
          ielts_latest_band: (p.ielts_latest_band as number) ?? null,
          toeic_latest_score: (p.toeic_latest_score as number) ?? null,
          itp_latest_score: (p.itp_latest_score as number) ?? null,
          readiness_status: (p.readiness_status as string) ?? 'preparing',
          readiness_pct: (p.readiness_pct as number) ?? 0,
          syllabus_completion_pct: (p.syllabus_completion_pct as number) ?? 0,
          edubot_xp: (p.edubot_xp as number) ?? null,
          edubot_streak_days: (p.edubot_streak_days as number) ?? null,
          edubot_questions_answered: (p.edubot_questions_answered as number) ?? null,
          edubot_accuracy_rate: (p.edubot_accuracy_rate as number) ?? null,
          edubot_last_active: (p.edubot_last_active as string) ?? null,
        };
      });

      // Optional EduBot bridge enrichment — only if secrets are set
      if (env.EDUBOT_API_URL && env.EDUBOT_INTERNAL_SECRET) {
        students = await enrichWithEduBot(env, students);
      }
    }
  }

  // ---- Per-classroom student counts + syllabus counts ----
  const studentCountByClassroom = new Map<string, number>();
  for (const s of students) {
    if (s.classroom_id) {
      studentCountByClassroom.set(s.classroom_id, (studentCountByClassroom.get(s.classroom_id) ?? 0) + 1);
    }
  }
  let syllabusCountByClassroom = new Map<string, number>();
  if (classroomIds.length > 0) {
    const { data: syllabiRows } = await supabase
      .from('syllabi')
      .select('classroom_id')
      .in('classroom_id', classroomIds);
    for (const r of (syllabiRows ?? []) as Array<Record<string, unknown>>) {
      const cid = r.classroom_id as string;
      if (cid) syllabusCountByClassroom.set(cid, (syllabusCountByClassroom.get(cid) ?? 0) + 1);
    }
  }

  const dashboardClassrooms: DashboardClassroom[] = classrooms.map((c) => ({
    id: c.id,
    name: c.name,
    target_exam: c.target_exam,
    join_code: c.join_code,
    student_count: studentCountByClassroom.get(c.id) ?? 0,
    syllabus_count: syllabusCountByClassroom.get(c.id) ?? 0,
    created_at: c.created_at,
  }));

  // ---- Recent activity: webhook_events for this teacher's students ----
  let recentActivity: Array<{ event_type: string; timestamp: string; platform: string | null }> = [];
  const studentIds = students.map((s) => s.id);
  if (studentIds.length > 0) {
    const { data: events } = await supabase
      .from('webhook_events')
      .select('event_type, created_at, platform')
      .in('user_id', studentIds)
      .order('created_at', { ascending: false })
      .limit(10);
    recentActivity = ((events ?? []) as Array<Record<string, unknown>>).map((e) => ({
      event_type: (e.event_type as string) ?? 'event',
      timestamp: (e.created_at as string) ?? '',
      platform: (e.platform as string) ?? null,
    }));
  }

  return {
    user: {
      id: profile?.id ?? teacherId,
      name: profile?.display_name ?? 'Teacher',
      role: profile?.role ?? 'teacher',
    },
    classrooms_count: classrooms.length,
    total_students: students.length,
    commission_this_month: commissionThisMonth,
    commission_total: commissionTotal,
    ai_quota_remaining: aiQuotaRemaining,
    ai_quota_used: aiQuotaUsed,
    referrals_count: referrals.length,
    classrooms: dashboardClassrooms,
    students,
    recent_activity: recentActivity,
    edubot_bridge_enabled: !!(env.EDUBOT_API_URL && env.EDUBOT_INTERNAL_SECRET),
  };
}

/**
 * Optional EduBot bridge enrichment — fetches XP/streak/accuracy for each student
 * from EduBot's API. Fails gracefully (returns original students if EduBot is down).
 *
 * Requires env.EDUBOT_API_URL + env.EDUBOT_INTERNAL_SECRET to be set.
 */
async function enrichWithEduBot(env: Env, students: DashboardStudent[]): Promise<DashboardStudent[]> {
  const baseUrl = (env.EDUBOT_API_URL ?? '').replace(/\/$/, '');
  const secret = env.EDUBOT_INTERNAL_SECRET;
  if (!baseUrl || !secret) return students;

  try {
    // EduBot exposes a batch lookup endpoint: POST /api/external/students/progress
    // Body: { student_ids: [...] }
    // Headers: X-Hub-Secret: <secret>
    const res = await fetch(`${baseUrl}/api/external/students/progress`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Hub-Secret': secret,
      },
      body: JSON.stringify({ student_ids: students.map((s) => s.id) }),
    });
    if (!res.ok) return students;
    const payload = (await res.json()) as Record<string, {
      xp?: number;
      streak_days?: number;
      questions_answered?: number;
      accuracy_rate?: number;
      last_active?: string;
    }>;
    return students.map((s) => {
      const e = payload[s.id];
      if (!e) return s;
      return {
        ...s,
        edubot_xp: e.xp ?? s.edubot_xp,
        edubot_streak_days: e.streak_days ?? s.edubot_streak_days,
        edubot_questions_answered: e.questions_answered ?? s.edubot_questions_answered,
        edubot_accuracy_rate: e.accuracy_rate ?? s.edubot_accuracy_rate,
        edubot_last_active: e.last_active ?? s.edubot_last_active,
      };
    });
  } catch {
    // EduBot unreachable — return with Hub-only data
    return students;
  }
}