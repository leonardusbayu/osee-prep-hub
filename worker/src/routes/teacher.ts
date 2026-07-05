import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  createClassroom,
  getClassroomsByTeacher,
  getClassroomDetail,
} from '../services/classroom';

export const teacherRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// All teacher routes require authentication + teacher role
teacherRoutes.use('*', requireAuth());

// ---------- Classroom endpoints ----------

/** POST /api/teacher/classrooms — create a new classroom */
teacherRoutes.post('/classrooms', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }

  let body: { name?: string; description?: string; target_exam?: string; max_students?: number };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  if (!body.name || body.name.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_NAME', message: 'Classroom name required' } }, 400);
  }

  try {
    const classroom = await createClassroom(c.env, user.id, {
      name: body.name,
      description: body.description,
      target_exam: body.target_exam,
      max_students: body.max_students,
    });
    return c.json(classroom, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Create failed';
    return c.json({ error: { code: 'CREATE_FAILED', message } }, 500);
  }
});

/** GET /api/teacher/classrooms — list teacher's classrooms */
teacherRoutes.get('/classrooms', async (c) => {
  const user = getAuthedUser(c);
  try {
    const classrooms = await getClassroomsByTeacher(c.env, user.id);
    return c.json({ classrooms });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fetch failed';
    return c.json({ error: { code: 'FETCH_FAILED', message } }, 500);
  }
});

/** GET /api/teacher/classrooms/:id — classroom detail with students */
teacherRoutes.get('/classrooms/:id', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const detail = await getClassroomDetail(c.env, user.id, classroomId);
    return c.json(detail);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fetch failed';
    return c.json({ error: { code: 'FETCH_FAILED', message } }, 404);
  }
});

// ---------- Dashboard endpoint (placeholder — full impl in Task 2.1) ----------

/** GET /api/teacher/dashboard — stats overview */
teacherRoutes.get('/dashboard', async (c) => {
  const user = getAuthedUser(c);
  // TODO: Task 2.1 will implement full dashboard stats
  return c.json({
    user: { id: user.id, name: user.display_name, role: user.role },
    classrooms_count: 0,
    total_students: 0,
    commission_this_month: 0,
    ai_quota_remaining: 0,
    note: 'Full dashboard stats — Task 2.1 (Flutter UI)',
  });
});