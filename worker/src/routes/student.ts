import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { enrollStudentByJoinCode, getStudentClassrooms } from '../services/classroom';

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

/** GET /api/student/progress — student's progress across all platforms (placeholder — Task 3.3) */
studentRoutes.get('/progress', async (c) => {
  const user = getAuthedUser(c);
  // TODO: Task 3.3 student-facing progress endpoint (uses student-progress service)
  return c.json({
    student_id: user.id,
    progress: [],
    note: 'Full progress data — implemented in Task 3.3 (service exists, endpoint wiring pending)',
  });
});