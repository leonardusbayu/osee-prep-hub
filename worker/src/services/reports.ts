import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Report generation service — Task 8.1.
 *
 * Aggregates student progress into a structured report including:
 * - Overall scores per platform (ibt, itp, ielts, toeic)
 * - Section breakdowns (reading, listening, speaking, writing)
 * - Weakness areas
 * - Progress over time
 * - Recommendations
 */

export interface StudentReport {
  student: {
    id: string;
    name: string;
    email: string;
    target_exam: string | null;
    current_level: string | null;
  };
  progress: {
    ibt_latest_score: number | null;
    itp_latest_score: number | null;
    ielts_latest_band: number | null;
    toeic_latest_score: number | null;
    edubot_streak_days: number;
    total_practice_count: number;
  };
  weaknesses: Array<{ area: string; score: number; recommendation: string }>;
  recent_activity: Array<{ date: string; event: string; platform: string }>;
  generated_at: string;
}

/** Generate a comprehensive student report. */
export async function generateStudentReport(
  env: Env,
  teacherId: string,
  studentId: string
): Promise<StudentReport> {
  const supabase = getSupabase(env);

  // Verify the teacher owns this student (via classroom enrollment)
  const { data: enrollment } = await supabase
    .from('classroom_enrollments')
    .select(`
      id,
      classroom:classrooms!classroom_enrollments_classroom_id_fkey (
        teacher_id
      )
    `)
    .eq('student_id', studentId)
    .eq('is_active', true)
    .maybeSingle();

  // Check if any enrollment belongs to this teacher
  const teacherOwnsStudent = Array.isArray(enrollment)
    ? enrollment.some((e: Record<string, unknown>) => {
        const classroom = e.classroom as Record<string, unknown>;
        return classroom?.teacher_id === teacherId;
      })
    : (enrollment as Record<string, unknown> | null)?.classroom
        ? ((enrollment as Record<string, unknown>).classroom as Record<string, unknown>)?.teacher_id === teacherId
        : false;

  if (!teacherOwnsStudent && teacherId !== studentId) {
    throw new Error('Not authorized to view this student');
  }

  // Get student profile
  const { data: student, error: studentErr } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email, target_exam, current_level')
    .eq('id', studentId)
    .maybeSingle();

  if (studentErr || !student) {
    throw new Error('Student not found');
  }

  // Get progress data
  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', studentId)
    .maybeSingle();

  // Get recent webhook events
  const { data: recentEvents } = await supabase
    .from('webhook_events')
    .select('event_type, platform, created_at')
    .eq('user_id', studentId)
    .order('created_at', { ascending: false })
    .limit(10);

  // Build weaknesses array from scores
  const weaknesses: Array<{ area: string; score: number; recommendation: string }> = [];
  if (progress) {
    const p = progress as Record<string, unknown>;
    const scores = {
      ibt: p.ibt_latest_score as number | null,
      itp: p.itp_latest_score as number | null,
      ielts: p.ielts_latest_band as number | null,
      toeic: p.toeic_latest_score as number | null,
    };
    for (const [area, score] of Object.entries(scores)) {
      if (score !== null && score < 50) {
        weaknesses.push({
          area: area.toUpperCase(),
          score,
          recommendation: `Focus on ${area} practice — current score is below 50. Recommend 3-5 practice sessions per week.`,
        });
      }
    }
  }

  return {
    student: {
      id: student.id as string,
      name: student.display_name as string,
      email: student.email as string,
      target_exam: (student.target_exam as string) ?? null,
      current_level: (student.current_level as string) ?? null,
    },
    progress: {
      ibt_latest_score: (progress as Record<string, unknown>)?.ibt_latest_score as number | null ?? null,
      itp_latest_score: (progress as Record<string, unknown>)?.itp_latest_score as number | null ?? null,
      ielts_latest_band: (progress as Record<string, unknown>)?.ielts_latest_band as number | null ?? null,
      toeic_latest_score: (progress as Record<string, unknown>)?.toeic_latest_score as number | null ?? null,
      edubot_streak_days: (progress as Record<string, unknown>)?.edubot_streak_days as number ?? 0,
      total_practice_count:
        ((progress as Record<string, unknown>)?.ibt_practice_count as number ?? 0) +
        ((progress as Record<string, unknown>)?.itp_practice_count as number ?? 0) +
        ((progress as Record<string, unknown>)?.ielts_practice_count as number ?? 0) +
        ((progress as Record<string, unknown>)?.toeic_practice_count as number ?? 0),
    },
    weaknesses,
    recent_activity: (recentEvents ?? []).map((e: Record<string, unknown>) => ({
      date: e.created_at as string,
      event: e.event_type as string,
      platform: e.platform as string,
    })),
    generated_at: new Date().toISOString(),
  };
}

/** Generate a classroom report — Task 9.1. */
export interface ClassroomReport {
  classroom: { id: string; name: string; teacher_id: string };
  summary: {
    total_students: number;
    active_students: number;
    avg_progress: number;
    common_weaknesses: string[];
  };
  students: Array<{
    id: string;
    name: string;
    latest_scores: Record<string, number | null>;
    practice_count: number;
  }>;
  generated_at: string;
}

export async function generateClassroomReport(
  env: Env,
  teacherId: string,
  classroomId: string
): Promise<ClassroomReport> {
  const supabase = getSupabase(env);

  // Verify classroom belongs to teacher
  const { data: classroom, error: classErr } = await supabase
    .from('classrooms')
    .select('id, name, teacher_id')
    .eq('id', classroomId)
    .eq('teacher_id', teacherId)
    .maybeSingle();

  if (classErr || !classroom) {
    throw new Error('Classroom not found or not owned by teacher');
  }

  // Get enrolled students with progress
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select(`
      student:unified_profiles!classroom_enrollments_student_id_fkey (
        id, display_name
      )
    `)
    .eq('classroom_id', classroomId)
    .eq('is_active', true);

  const students = (enrollments ?? []).map((e: Record<string, unknown>) => {
    const student = e.student as Record<string, unknown>;
    return { id: student.id as string, name: student.display_name as string };
  });

  // Get progress for each student
  const studentsWithProgress = await Promise.all(
    students.map(async (s) => {
      const { data: progress } = await supabase
        .from('student_progress_unified')
        .select('*')
        .eq('student_id', s.id)
        .maybeSingle();
      const p = (progress as Record<string, unknown>) ?? {};
      return {
        id: s.id,
        name: s.name,
        latest_scores: {
          ibt: (p.ibt_latest_score as number) ?? null,
          itp: (p.itp_latest_score as number) ?? null,
          ielts: (p.ielts_latest_band as number) ?? null,
          toeic: (p.toeic_latest_score as number) ?? null,
        },
        practice_count:
          ((p.ibt_practice_count as number) ?? 0) +
          ((p.itp_practice_count as number) ?? 0) +
          ((p.ielts_practice_count as number) ?? 0) +
          ((p.toeic_practice_count as number) ?? 0),
      };
    })
  );

  // Calculate aggregate stats
  const activeStudents = studentsWithProgress.filter((s) => s.practice_count > 0).length;
  const allScores = studentsWithProgress.flatMap((s) =>
    Object.values(s.latest_scores).filter((v): v is number => v !== null)
  );
  const avgProgress = allScores.length > 0 ? allScores.reduce((a, b) => a + b, 0) / allScores.length : 0;

  // Common weaknesses (areas where most students score low)
  const weaknessAreas: Record<string, number> = {};
  for (const s of studentsWithProgress) {
    for (const [area, score] of Object.entries(s.latest_scores)) {
      if (score !== null && score < 60) {
        weaknessAreas[area] = (weaknessAreas[area] ?? 0) + 1;
      }
    }
  }
  const commonWeaknesses = Object.entries(weaknessAreas)
    .filter(([, count]) => count >= Math.max(1, Math.floor(students.length / 3)))
    .map(([area]) => area.toUpperCase())
    .sort();

  return {
    classroom: { id: classroom.id as string, name: classroom.name as string, teacher_id: classroom.teacher_id as string },
    summary: {
      total_students: students.length,
      active_students: activeStudents,
      avg_progress: Math.round(avgProgress * 10) / 10,
      common_weaknesses: commonWeaknesses,
    },
    students: studentsWithProgress,
    generated_at: new Date().toISOString(),
  };
}