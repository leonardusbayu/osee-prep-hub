import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { enrollStudentByJoinCode, getStudentClassrooms } from '../services/classroom';
import { getSupabase } from '../services/supabase';
import { cache } from '../middleware/cache';

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
studentRoutes.get('/progress', cache({ ttl: 30 }), async (c) => {
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
studentRoutes.get('/dashboard', cache({ ttl: 30 }), async (c) => {
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

/** GET /api/student/syllabus — get assigned syllabus (Task 11.2) */
studentRoutes.get('/syllabus', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  // Get student's classrooms, then find syllabi for those classrooms
  const classrooms = await getStudentClassrooms(c.env, user.id);
  const classroomIds = classrooms.map((c) => c.id);
  if (classroomIds.length === 0) {
    return c.json({ syllabi: [] });
  }

  const { data: syllabi } = await supabase
    .from('syllabi')
    .select('*, syllabus_items(*)')
    .in('classroom_id', classroomIds)
    .eq('is_published', true);

  return c.json({ syllabi: syllabi ?? [] });
});

/** GET /api/student/readiness — readiness gauge + recommendations (Task 11.4) */
studentRoutes.get('/readiness', cache({ ttl: 30 }), async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', user.id)
    .maybeSingle();

  const p = (progress as Record<string, unknown>) ?? {};

  // Get target_score from profile
  const { data: profile } = await supabase
    .from('unified_profiles')
    .select('target_exam, target_score')
    .eq('id', user.id)
    .maybeSingle();
  const prof = (profile as Record<string, unknown>) ?? {};
  const targetExam = (prof.target_exam as string) ?? null;
  const targetScore = ((prof.target_score as Record<string, unknown>) ?? {}).overall as number | undefined;

  // Use readiness_status from progress table if present; otherwise compute
  let readinessPct = (p.readiness_pct as number) ?? 0;
  let readinessStatus = (p.readiness_status as string) ?? 'preparing';
  const predictedScore = (p.predicted_score as number) ?? null;
  const weeksToTarget = (p.weeks_to_target as number) ?? null;

  if (!readinessPct && targetScore) {
    // Compute from latest score vs target
    const latest = pickLatestScoreForExam(p, targetExam);
    if (latest !== null) {
      readinessPct = Math.min(100, Math.round((latest / targetScore) * 100));
      readinessStatus = readinessPct >= 80 ? 'ready' : readinessPct >= 60 ? 'almost_ready' : 'preparing';
    }
  }

  // Recommendations
  const recommendations: string[] = [];
  if (readinessStatus === 'preparing') {
    recommendations.push('Continue daily practice to build up your skills.');
  }
  if (readinessStatus === 'almost_ready') {
    recommendations.push('You are close — focus on your weakest sections.');
  }
  if (readinessStatus === 'ready') {
    recommendations.push('You are ready to book the official test at osee.co.id.');
  }

  return c.json({
    readiness_pct: readinessPct,
    readiness_status: readinessStatus,
    predicted_score: predictedScore,
    weeks_to_target: weeksToTarget,
    target_exam: targetExam,
    target_score: targetScore ?? null,
    recommendations,
  });
});

/** GET /api/student/cross-exam-map — equivalent scores across exams (Task 11.5) */
studentRoutes.get('/cross-exam-map', cache({ ttl: 60 }), async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('ibt_latest_score, itp_latest_score, ielts_latest_band, toeic_latest_score')
    .eq('student_id', user.id)
    .maybeSingle();
  const p = (progress as Record<string, unknown>) ?? {};

  const ibt = (p.ibt_latest_score as number) ?? null;
  const itp = (p.itp_latest_score as number) ?? null;
  const ielts = (p.ielts_latest_band as number) ?? null;
  const toeic = (p.toeic_latest_score as number) ?? null;

  // Get the relevant cross-exam map rows for whichever exams student has a score in
  const sourceExams: string[] = [];
  const sourceScores: number[] = [];
  if (ibt !== null) { sourceExams.push('TOEFL_IBT'); sourceScores.push(ibt); }
  if (itp !== null) { sourceExams.push('TOEFL_ITP'); sourceScores.push(itp); }
  if (ielts !== null) { sourceExams.push('IELTS'); sourceScores.push(ielts); }
  if (toeic !== null) { sourceExams.push('TOEIC'); sourceScores.push(toeic); }

  const equivalents: Record<string, Record<string, number | null>> = {
    TOEFL_IBT: { TOEFL_IBT: ibt, TOEFL_ITP: null, IELTS: null, TOEIC: null },
    TOEFL_ITP: { TOEFL_IBT: null, TOEFL_ITP: itp, IELTS: null, TOEIC: null },
    IELTS: { TOEFL_IBT: null, TOEFL_ITP: null, IELTS: ielts, TOEIC: null },
    TOEIC: { TOEFL_IBT: null, TOEFL_ITP: null, IELTS: null, TOEIC: toeic },
  };

  if (sourceExams.length > 0) {
    const { data: mapRows } = await supabase
      .from('cross_exam_score_map')
      .select('source_exam, source_score, target_exam, target_score, confidence')
      .in('source_exam', sourceExams);

    for (const row of (mapRows ?? []) as Array<Record<string, unknown>>) {
      const sourceScore = row.source_score as number;
      const sourceExam = row.source_exam as string;
      const targetExam = row.target_exam as string;
      // Only fill if student's score is within ±5 of source_score
      const studentSourceScore =
        sourceExam === 'TOEFL_IBT' ? ibt :
        sourceExam === 'TOEFL_ITP' ? itp :
        sourceExam === 'IELTS' ? ielts :
        sourceExam === 'TOEIC' ? toeic : null;
      if (studentSourceScore !== null && Math.abs(studentSourceScore - sourceScore) <= 2) {
        equivalents[targetExam][sourceExam] = row.target_score as number;
      }
    }
  }

  return c.json({ equivalents, source_scores: { ibt, itp, ielts, toeic } });
});

/** GET /api/student/book-test — available official test dates (Task 11.6) */
studentRoutes.get('/book-test', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  // Contextual: only show booking if readiness >= 80%
  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('readiness_pct, readiness_status')
    .eq('student_id', user.id)
    .maybeSingle();
  const readiness = ((progress as Record<string, unknown>) ?? {}).readiness_pct as number | undefined;
  const readinessStatus = ((progress as Record<string, unknown>) ?? {}).readiness_status as string | undefined;
  const canBook = (readiness ?? 0) >= 80 || readinessStatus === 'ready';

  return c.json({
    ready_to_book: canBook,
    osee_booking_url: 'https://osee.co.id',
    available_dates: [],  // populated when osee.co.id booking API is integrated
    note: canBook
      ? 'You are ready to book your official test.'
      : 'Continue practicing until your readiness reaches 80%.',
  });
});

/** POST /api/student/syllabus/:itemId/start — mark syllabus item as started (Task 11.2) */
studentRoutes.post('/syllabus/:itemId/start', async (c) => {
  const user = getAuthedUser(c);
  const itemId = c.req.param('itemId');
  const supabase = getSupabase(c.env);

  // Verify the item belongs to a syllabus in the student's classroom
  const ok = await studentOwnsSyllabusItem(c.env, user.id, itemId);
  if (!ok) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Item not available for this student' } }, 403);
  }

  const { error } = await supabase
    .from('syllabus_item_progress')
    .upsert(
      {
        syllabus_item_id: itemId,
        student_id: user.id,
        status: 'started',
        started_at: new Date().toISOString(),
      },
      { onConflict: 'syllabus_item_id,student_id' }
    );

  if (error) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error.message } }, 500);
  }

  // Return deep link to the source platform if available
  const { data: item } = await supabase
    .from('syllabus_items')
    .select('source_platform_url')
    .eq('id', itemId)
    .maybeSingle();
  return c.json({ success: true, deep_link: (item as Record<string, unknown>)?.source_platform_url ?? null });
});

/** POST /api/student/syllabus/:itemId/complete — mark syllabus item as completed (Task 11.2) */
studentRoutes.post('/syllabus/:itemId/complete', async (c) => {
  const user = getAuthedUser(c);
  const itemId = c.req.param('itemId');
  let body: { score?: number };
  try { body = await c.req.json().catch(() => ({})); } catch {
    body = {};
  }

  const supabase = getSupabase(c.env);
  const ok = await studentOwnsSyllabusItem(c.env, user.id, itemId);
  if (!ok) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Item not available for this student' } }, 403);
  }

  const update: Record<string, unknown> = {
    syllabus_item_id: itemId,
    student_id: user.id,
    status: 'completed',
    completed_at: new Date().toISOString(),
  };
  if (typeof body.score === 'number') update.score = body.score;

  const { error } = await supabase
    .from('syllabus_item_progress')
    .upsert(update, { onConflict: 'syllabus_item_id,student_id' });

  if (error) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error.message } }, 500);
  }
  return c.json({ success: true });
});

// ---------- Helpers ----------

/** Pick the most recent score for the given exam type. */
function pickLatestScoreForExam(progress: Record<string, unknown>, exam: string | null): number | null {
  if (!exam) return null;
  switch (exam) {
    case 'TOEFL_IBT':
      return (progress.ibt_latest_score as number) ?? null;
    case 'TOEFL_ITP':
      return (progress.itp_latest_score as number) ?? null;
    case 'IELTS':
      return (progress.ielts_latest_band as number) ?? null;
    case 'TOEIC':
      return (progress.toeic_latest_score as number) ?? null;
    default:
      return null;
  }
}

/** Verify that a syllabus item belongs to a published syllabus in a classroom the student is enrolled in. */
async function studentOwnsSyllabusItem(env: Env, studentId: string, itemId: string): Promise<boolean> {
  const supabase = getSupabase(env);

  // Get the item's syllabus_id
  const { data: item } = await supabase
    .from('syllabus_items')
    .select('syllabus_id')
    .eq('id', itemId)
    .maybeSingle();
  if (!item) return false;
  const syllabusId = (item as Record<string, unknown>).syllabus_id as string;

  // Get the syllabus (must be published + have a classroom_id)
  const { data: syllabus } = await supabase
    .from('syllabi')
    .select('classroom_id, is_published')
    .eq('id', syllabusId)
    .maybeSingle();
  if (!syllabus) return false;
  const syl = syllabus as Record<string, unknown>;
  if (!syl.is_published || !syl.classroom_id) return false;

  // Check enrollment
  const { data: enrollment } = await supabase
    .from('classroom_enrollments')
    .select('id')
    .eq('classroom_id', syl.classroom_id as string)
    .eq('student_id', studentId)
    .eq('is_active', true)
    .maybeSingle();
  return Boolean(enrollment);
}