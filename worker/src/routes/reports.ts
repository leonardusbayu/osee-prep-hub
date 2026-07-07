import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  generateReport,
  listReports,
  getReport,
  sendReport,
  listReportsForStudent,
} from '../services/parent-report';

export const reportRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

reportRoutes.use('*', requireAuth());

/** POST /api/reports/generate — generate a parent report (teacher only) */
reportRoutes.post('/generate', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  let body: {
    student_id?: string;
    classroom_id?: string;
    report_type?: string;
    period_start?: string;
    period_end?: string;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.student_id?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'student_id required' } }, 400);
  }
  try {
    const report = await generateReport(c.env, user.id, {
      student_id: body.student_id,
      classroom_id: body.classroom_id,
      report_type: body.report_type as 'progress' | 'weakness' | 'summary' | 'recommendation' | undefined,
      period_start: body.period_start,
      period_end: body.period_end,
    });
    return c.json(report, 201);
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('Not authorized')) {
      return c.json({ error: { code: 'FORBIDDEN', message } }, 403);
    }
    if (message.includes('not found')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'GENERATE_FAILED', message } }, 500);
  }
});

/** GET /api/reports — list reports (teacher sees own students' reports) */
reportRoutes.get('/', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  const studentId = c.req.query('student_id');
  const classroomId = c.req.query('classroom_id');
  try {
    const reports = await listReports(c.env, user.id, { studentId, classroomId });
    return c.json({ reports, count: reports.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/reports/student/:studentId — list reports for a student */
reportRoutes.get('/student/:studentId', async (c) => {
  const user = getAuthedUser(c);
  const studentId = c.req.param('studentId');
  try {
    if (user.role === 'student') {
      if (user.id !== studentId) {
        return c.json({ error: { code: 'FORBIDDEN', message: 'Can only view your own reports' } }, 403);
      }
      const reports = await listReportsForStudent(c.env, studentId);
      return c.json({ reports, count: reports.length });
    }
    if (user.role === 'teacher' || user.role === 'admin') {
      const reports = await listReports(c.env, user.id, { studentId });
      return c.json({ reports, count: reports.length });
    }
    return c.json({ error: { code: 'FORBIDDEN', message: 'Access denied' } }, 403);
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/reports/:id — get a single report (teacher or student owner) */
reportRoutes.get('/:id', async (c) => {
  const user = getAuthedUser(c);
  const reportId = c.req.param('id');
  try {
    const report = await getReport(c.env, user.id, reportId);
    if (!report) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Report not found or access denied' } }, 404);
    }
    return c.json(report);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/reports/:id/send — mark report as sent to parent (teacher only) */
reportRoutes.post('/:id/send', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  const reportId = c.req.param('id');
  let body: { parent_email?: string; parent_name?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.parent_email?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'parent_email required' } }, 400);
  }
  try {
    const report = await sendReport(c.env, user.id, reportId, {
      parent_email: body.parent_email,
      parent_name: body.parent_name,
    });
    return c.json(report);
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    if (message.includes('not owned')) {
      return c.json({ error: { code: 'FORBIDDEN', message } }, 403);
    }
    return c.json({ error: { code: 'SEND_FAILED', message } }, 500);
  }
});