import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { enrollStudentByJoinCode, getStudentClassrooms } from '../services/classroom';
import { getStudentSyllabi } from '../services/syllabus-assignment';
import { getSupabase } from '../services/supabase';

export const studentRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// All student routes require authentication
studentRoutes.use('*', requireAuth());

/** POST /api/student/classrooms/join — join a classroom via code */
studentRoutes.post('/classrooms/join', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'student') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Student role required' } }, 403);
  }

  let body: { join_code?: string };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  if (!body.join_code || body.join_code.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_CODE', message: 'join_code required' } }, 400);
  }

  try {
    const result = await enrollStudentByJoinCode(c.env, user.id, body.join_code.trim());
    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Enrollment failed';
    // Distinguish "already enrolled" (409) from other errors (400)
    const status = message.toLowerCase().includes('already enrolled') ? 409 : 400;
    return c.json({ error: { code: 'ENROLL_FAILED', message } }, status);
  }
});

/** GET /api/student/classrooms — list classrooms the student is enrolled in */
studentRoutes.get('/classrooms', async (c) => {
  const user = getAuthedUser(c);
  try {
    const classrooms = await getStudentClassrooms(c.env, user.id);
    return c.json({ classrooms });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fetch failed';
    return c.json({ error: { code: 'FETCH_FAILED', message } }, 500);
  }
});

/** GET /api/student/progress — student's progress across all platforms (Task 3.3, 11.3) */
studentRoutes.get('/progress', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);
  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', user.id)
    .maybeSingle();
  return c.json({
    student_id: user.id,
    progress: progress ?? {},
  });
});

/** GET /api/student/dashboard — student dashboard data (Task 11.1) */
studentRoutes.get('/dashboard', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  // Get progress
  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', user.id)
    .maybeSingle();

  // Get enrolled classrooms
  const classrooms = await getStudentClassrooms(c.env, user.id);

  // Calculate readiness (simple heuristic)
  const p = (progress as Record<string, unknown>) ?? {};
  const scores = [
    p.ibt_latest_score as number | null,
    p.itp_latest_score as number | null,
    p.ielts_latest_band as number | null,
    p.toeic_latest_score as number | null,
  ].filter((s): s is number => s !== null);
  const avgScore = scores.length > 0 ? scores.reduce((a, b) => a + b, 0) / scores.length : 0;
  const readiness = Math.min(100, Math.round(avgScore));

  return c.json({
    student: { id: user.id, name: user.display_name, email: user.email },
    progress: progress ?? {},
    classrooms,
    readiness,
    note: 'Full student dashboard — Task 11.1 (Flutter UI)',
  });
});

/** GET /api/student/readiness — readiness assessment + recommendations.
 *  Used by the student dashboard (alongside /dashboard) and the readiness page.
 *  Returns { target_exam, readiness_pct, readiness_status, recommendations[] }.
 *  Always 200 — users with no progress yet get starter recommendations. */
studentRoutes.get('/readiness', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  const { data: profile } = await supabase
    .from('unified_profiles')
    .select('target_exam, current_level')
    .eq('id', user.id)
    .maybeSingle();

  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', user.id)
    .maybeSingle();

  const targetExam = (profile as Record<string, unknown> | null)?.target_exam as string | null ?? null;
  const p = (progress ?? {}) as Record<string, unknown>;

  const readinessPct = typeof p.readiness_pct === 'number' ? p.readiness_pct : 0;
  const readinessStatus = typeof p.readiness_status === 'string' ? p.readiness_status : 'preparing';
  const recommendations: Array<{ title: string; detail: string }> = [];
  const sectionScores: Array<{ section: string; score: number | null }> = [
    { section: 'Reading', score: (p.ibt_latest_section_scores as Record<string, number> | null)?.reading ?? (p.ielts_latest_section_scores as Record<string, number> | null)?.reading ?? null },
    { section: 'Listening', score: (p.ibt_latest_section_scores as Record<string, unknown> | null)?.listening as number | null ?? (p.ielts_latest_section_scores as Record<string, unknown> | null)?.listening as number | null ?? null },
    { section: 'Speaking', score: (p.speaking_latest_band as number | null) ?? null },
    { section: 'Writing', score: (p.writing_latest_band as number | null) ?? null },
  ];
  const known = sectionScores.filter((s) => typeof s.score === 'number');
  if (known.length === 0) {
    recommendations.push(
      { title: 'Take a diagnostic test', detail: 'Find your starting level so Coach can build your plan.' },
      { title: 'Set your target exam', detail: targetExam ? `Your target is ${targetExam.replace(/_/g, ' ')} — great, Coach will align everything to it.` : 'Pick TOEFL, IELTS, or TOEIC in your profile so recommendations stay focused.' },
      { title: 'Join a classroom', detail: 'Ask your teacher for a join code to get your syllabus.' },
    );
  } else {
    const weakest = [...known].sort((a, b) => (a.score as number) - (b.score as number))[0];
    recommendations.push({
      title: `Focus on ${weakest.section}`,
      detail: `It's your lowest section right now. Ask Coach for a ${weakest.section.toLowerCase()} drill.`,
    });
    if (known.length > 1) {
      const second = [...known].sort((a, b) => (a.score as number) - (b.score as number))[1];
      recommendations.push({
        title: `Keep ${second.section} warm`,
        detail: `One short practice set a week is enough to hold your level.`,
      });
    }
    recommendations.push({
      title: 'Review with Coach',
      detail: 'Open Coach and ask "what should I practice next?" for a personalized plan.',
    });
  }

  return c.json({
    target_exam: targetExam,
    readiness_pct: readinessPct,
    readiness_status: readinessStatus,
    recommendations,
  });
});

/** GET /api/student/syllabus — get all syllabi visible to this student
 *  (classroom-linked published + individually assigned). */
studentRoutes.get('/syllabus', async (c) => {
  const user = getAuthedUser(c);
  try {
    const syllabi = await getStudentSyllabi(c.env, user.id);
    return c.json({ syllabi });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});