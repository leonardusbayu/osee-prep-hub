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
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select(`
      classroom:classrooms!classroom_enrollments_classroom_id_fkey (
        teacher_id
      )
    `)
    .eq('student_id', studentId)
    .eq('is_active', true);

  // Check if any enrollment belongs to this teacher
  const teacherOwnsStudent = (enrollments ?? []).some((e: Record<string, unknown>) => {
    const classroom = e.classroom as Record<string, unknown>;
    return classroom?.teacher_id === teacherId;
  });

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
// ============================================================
// Batch report generation — Task 8.4
// ============================================================

/** Generate reports for ALL students in a classroom at once.
 *  Returns array of student reports (same structure as generateStudentReport). */
export async function generateBatchStudentReports(
  env: Env,
  teacherId: string,
  classroomId: string
): Promise<Array<{ student_id: string; student_name: string; report: StudentReport | null; error?: string }>> {
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

  // Get enrolled students
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select(`
      student:unified_profiles!classroom_enrollments_student_id_fkey (
        id, display_name
      )
    `)
    .eq('classroom_id', classroomId)
    .eq('is_active', true);

  const students = ((enrollments ?? []) as Array<Record<string, unknown>>).map((e) => {
    const s = e.student as Record<string, unknown>;
    return { id: s.id as string, name: s.display_name as string };
  });

  const results: Array<{ student_id: string; student_name: string; report: StudentReport | null; error?: string }> = [];

  for (const s of students) {
    try {
      const report = await generateStudentReport(env, teacherId, s.id);
      results.push({ student_id: s.id, student_name: s.name, report });
    } catch (err) {
      results.push({
        student_id: s.id,
        student_name: s.name,
        report: null,
        error: err instanceof Error ? err.message : 'Unknown error',
      });
    }
  }

  return results;
}

// ============================================================
// Teacher effectiveness metrics — Task 9.4
// ============================================================

export interface TeacherEffectiveness {
  total_students: number;
  active_students: number;       // students with > 0 practice
  avg_improvement: number;        // avg score change (latest - first) across students
  engagement_rate: number;        // active_students / total_students * 100
  avg_class_score: number;        // mean of all latest scores
  top_performers: number;         // students scoring >= 80% of target
  needs_attention: number;         // students with low or no progress
  teaching_duration_weeks: number; // weeks since first student enrollment
}

/** Calculate teacher effectiveness metrics for a classroom — Task 9.4. */
export async function getTeacherEffectiveness(
  env: Env,
  teacherId: string,
  classroomId: string
): Promise<TeacherEffectiveness> {
  const supabase = getSupabase(env);

  // Verify ownership
  const { data: classroom } = await supabase
    .from('classrooms')
    .select('id, teacher_id, created_at')
    .eq('id', classroomId)
    .eq('teacher_id', teacherId)
    .maybeSingle();
  if (!classroom) throw new Error('Classroom not found');

  // Get enrollments with progress
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select(`
      enrolled_at,
      student:unified_profiles!classroom_enrollments_student_id_fkey (id)
    `)
    .eq('classroom_id', classroomId)
    .eq('is_active', true);

  const students = (enrollments ?? []) as Array<Record<string, unknown>>;
  const totalStudents = students.length;
  if (totalStudents === 0) {
    return {
      total_students: 0,
      active_students: 0,
      avg_improvement: 0,
      engagement_rate: 0,
      avg_class_score: 0,
      top_performers: 0,
      needs_attention: 0,
      teaching_duration_weeks: 0,
    };
  }

  // Get progress for each student
  const studentIds = students.map((s) => {
    const student = s.student as Record<string, unknown>;
    return student.id as string;
  });

  const { data: progressRows } = await supabase
    .from('student_progress_unified')
    .select('*')
    .in('student_id', studentIds);

  const progresses = (progressRows ?? []) as Array<Record<string, unknown>>;

  // Fetch score history for improvement calc (latest − first per student).
  const { data: historyRows } = await supabase
    .from('student_progress_history')
    .select('student_id, exam_type, score, completed_at')
    .in('student_id', studentIds)
    .order('completed_at', { ascending: true });

  // Group history by student → per-exam first + last score.
  const historyByStudent = new Map<string, Map<string, { first: number; last: number }>>();
  for (const h of (historyRows ?? []) as Array<Record<string, unknown>>) {
    const sid = h.student_id as string;
    const exam = (h.exam_type as string) ?? 'unknown';
    const score = h.score as number | null;
    if (score === null) continue;
    let examMap = historyByStudent.get(sid);
    if (!examMap) { examMap = new Map(); historyByStudent.set(sid, examMap); }
    const entry = examMap.get(exam);
    if (!entry) {
      examMap.set(exam, { first: score, last: score });
    } else {
      entry.last = score;
    }
  }

  let activeCount = 0;
  let totalScore = 0;
  let scoreCount = 0;
  let topPerformers = 0;
  let needsAttention = 0;
  let totalImprovement = 0;
  let improvementCount = 0;

  for (const p of progresses) {
    const scores = [
      p.ibt_latest_score as number | null,
      p.itp_latest_score as number | null,
      p.ielts_latest_band as number | null,
      p.toeic_latest_score as number | null,
    ].filter((s): s is number => s !== null);

    const practiceCount =
      (p.ibt_practice_count as number ?? 0) +
      (p.itp_practice_count as number ?? 0) +
      (p.ielts_practice_count as number ?? 0) +
      (p.toeic_practice_count as number ?? 0) +
      (p.edubot_practice_count as number ?? 0);

    if (practiceCount > 0) activeCount++;

    if (scores.length > 0) {
      const avg = scores.reduce((a, b) => a + b, 0) / scores.length;
      totalScore += avg;
      scoreCount++;

      // Real improvement = latest − first (per exam, averaged).
      const examMap = historyByStudent.get(p.student_id as string);
      if (examMap) {
        let studentImprovement = 0;
        let examImprovements = 0;
        for (const entry of examMap.values()) {
          studentImprovement += entry.last - entry.first;
          examImprovements++;
        }
        if (examImprovements > 0) {
          totalImprovement += studentImprovement / examImprovements;
          improvementCount++;
        }
      }

      const readiness = (p.readiness_pct as number) ?? 0;
      if (readiness >= 80) topPerformers++;
      if (readiness < 40 || practiceCount === 0) needsAttention++;
    } else {
      needsAttention++;
    }
  }

  // Teaching duration
  const firstEnrolled = students
    .map((s) => new Date(s.enrolled_at as string).getTime())
    .filter((t) => !Number.isNaN(t))
    .sort((a, b) => a - b)[0];
  const weeks = firstEnrolled
    ? Math.max(1, Math.round((Date.now() - firstEnrolled) / (7 * 24 * 60 * 60 * 1000)))
    : 0;

  return {
    total_students: totalStudents,
    active_students: activeCount,
    avg_improvement: improvementCount > 0 ? Math.round((totalImprovement / improvementCount) * 10) / 10 : 0,
    engagement_rate: totalStudents > 0 ? Math.round((activeCount / totalStudents) * 100) : 0,
    avg_class_score: scoreCount > 0 ? Math.round((totalScore / scoreCount) * 10) / 10 : 0,
    top_performers: topPerformers,
    needs_attention: needsAttention,
    teaching_duration_weeks: weeks,
  };
}
