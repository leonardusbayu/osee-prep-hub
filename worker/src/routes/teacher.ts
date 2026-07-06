import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  createClassroom,
  getClassroomsByTeacher,
  getClassroomDetail,
} from '../services/classroom';
import {
  generateStudentReport,
  generateClassroomReport,
} from '../services/reports';
import {
  createSyllabus,
  listSyllabi,
  getSyllabus,
  listSyllabusItems,
  batchSaveSyllabusItems,
  addSyllabusItem,
} from '../services/syllabus';
import { getPricingForRole } from '../services/pricing';
import { buildTeacherDashboard } from '../services/teacher-dashboard';
import {
  assignSyllabusToStudent,
  assignSyllabusToClassroom,
  unassignSyllabusFromStudent,
  getSyllabusAssignments,
} from '../services/syllabus-assignment';

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

// ---------- Dashboard endpoint (unified classes + students + reporting) ----------

/** GET /api/teacher/dashboard — unified stats: classrooms, students, commission, AI quota, activity */
teacherRoutes.get('/dashboard', async (c) => {
  const user = getAuthedUser(c);
  try {
    const report = await buildTeacherDashboard(c.env, user.id);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Dashboard failed';
    return c.json({ error: { code: 'DASHBOARD_FAILED', message } }, 500);
  }
});

// ---------- Report endpoints (Task 8.1, 9.1) ----------

/** GET /api/teacher/students/:id/report — generate student report */
teacherRoutes.get('/students/:id/report', async (c) => {
  const user = getAuthedUser(c);
  const studentId = c.req.param('id');
  try {
    const report = await generateStudentReport(c.env, user.id, studentId);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

/** GET /api/teacher/classrooms/:id/report — generate classroom report */
teacherRoutes.get('/classrooms/:id/report', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const report = await generateClassroomReport(c.env, user.id, classroomId);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

// ---------- Syllabus endpoints (Task 10.x) ----------

/** POST /api/teacher/syllabi — create syllabus */
teacherRoutes.post('/syllabi', async (c) => {
  const user = getAuthedUser(c);
  let body: { name?: string; description?: string; target_exam?: string; classroom_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.name?.trim()) {
    return c.json({ error: { code: 'INVALID_NAME', message: 'name required' } }, 400);
  }
  try {
    const syllabus = await createSyllabus(c.env, user.id, {
      name: body.name,
      description: body.description,
      target_exam: body.target_exam,
      classroom_id: body.classroom_id,
    });
    return c.json(syllabus, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/syllabi — list teacher's syllabi */
teacherRoutes.get('/syllabi', async (c) => {
  const user = getAuthedUser(c);
  try {
    const syllabi = await listSyllabi(c.env, user.id);
    return c.json({ syllabi });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/syllabi/:id — get syllabus with items */
teacherRoutes.get('/syllabi/:id', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  try {
    const syllabus = await getSyllabus(c.env, user.id, syllabusId);
    if (!syllabus) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
    }
    const items = await listSyllabusItems(c.env, syllabusId);
    return c.json({ syllabus, items });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** PUT /api/teacher/syllabi/:id/items — batch save syllabus items (Task 10.4) */
teacherRoutes.put('/syllabi/:id/items', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: { items?: Array<Record<string, unknown>> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  // Verify syllabus belongs to teacher
  const syllabus = await getSyllabus(c.env, user.id, syllabusId);
  if (!syllabus) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
  }
  try {
    await batchSaveSyllabusItems(c.env, syllabusId, (body.items ?? []) as never);
    return c.json({ success: true, count: body.items?.length ?? 0 });
  } catch (err) {
    return c.json({ error: { code: 'SAVE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/teacher/syllabi/:id/items — add single item */
teacherRoutes.post('/syllabi/:id/items', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: Record<string, unknown>;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const syllabus = await getSyllabus(c.env, user.id, syllabusId);
  if (!syllabus) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
  }
  try {
    const item = await addSyllabusItem(c.env, syllabusId, body as never);
    return c.json(item, 201);
  } catch (err) {
    return c.json({ error: { code: 'ADD_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/pricing — pricing for the calling teacher's role */
teacherRoutes.get('/pricing', async (c) => {
  const user = getAuthedUser(c);
  try {
    const pricing = await getPricingForRole(c.env, user.role);
    return c.json({ pricing });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

// ---------- Syllabus assignment endpoints ----------

/** POST /api/teacher/syllabi/:id/assign/student — assign syllabus to one student */
teacherRoutes.post('/syllabi/:id/assign/student', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: { student_id?: string; notes?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.student_id) {
    return c.json({ error: { code: 'INVALID_STUDENT', message: 'student_id required' } }, 400);
  }
  try {
    const result = await assignSyllabusToStudent(c.env, syllabusId, body.student_id, user.id, body.notes);
    return c.json(result, 201);
  } catch (err) {
    const message = (err as Error).message;
    const status = message.includes('not found') || message.includes('Not your') ? 404 : 400;
    return c.json({ error: { code: 'ASSIGN_FAILED', message } }, status);
  }
});

/** POST /api/teacher/syllabi/:id/assign/classroom — link syllabus to a classroom */
teacherRoutes.post('/syllabi/:id/assign/classroom', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: { classroom_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.classroom_id) {
    return c.json({ error: { code: 'INVALID_CLASSROOM', message: 'classroom_id required' } }, 400);
  }
  try {
    const result = await assignSyllabusToClassroom(c.env, syllabusId, body.classroom_id, user.id);
    return c.json(result);
  } catch (err) {
    const message = (err as Error).message;
    const status = message.includes('not found') || message.includes('Not your') ? 404 : 400;
    return c.json({ error: { code: 'ASSIGN_FAILED', message } }, status);
  }
});

/** DELETE /api/teacher/syllabi/:id/assign/student/:studentId — unassign */
teacherRoutes.delete('/syllabi/:id/assign/student/:studentId', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  const studentId = c.req.param('studentId');
  try {
    await unassignSyllabusFromStudent(c.env, syllabusId, studentId, user.id);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'UNASSIGN_FAILED', message: (err as Error).message } }, 400);
  }
});

/** GET /api/teacher/syllabi/:id/assignments — who sees this syllabus */
teacherRoutes.get('/syllabi/:id/assignments', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  try {
    const result = await getSyllabusAssignments(c.env, syllabusId, user.id);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 400);
  }
});