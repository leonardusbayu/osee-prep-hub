import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { enrollStudentByJoinCode, getStudentClassrooms } from '../services/classroom';
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