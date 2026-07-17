import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  generateStudentReport,
  generateClassroomReport,
} from '../services/reports';
import {
  generateStudentReportHtml,
  generateClassroomReportHtml,
} from '../services/pdf';
import { checkQuota } from '../services/quota';

/**
 * Reports routes — Blueprint Section 5 lines 1391-1401.
 *
 * POST /api/reports/student/:student_id   — generate a student report
 * POST /api/reports/classroom/:classroom_id — generate a classroom report
 * Body: { format: 'json'|'pdf', include_recommendations?: boolean }
 *
 * These are the Blueprint-canonical report paths. The /api/teacher/students/:id/report
 * and /api/teacher/classrooms/:id/report GET endpoints remain for backward compat.
 */
export const reportRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

reportRoutes.use('*', requireAuth());

/** POST /api/reports/student/:student_id — generate a student report. */
reportRoutes.post('/student/:student_id', async (c) => {
  const user = getAuthedUser(c);
  const studentId = c.req.param('student_id');
  let body: { format?: string; include_recommendations?: boolean };
  try { body = await c.req.json(); } catch {
    body = {};
  }
  const format = (body.format ?? 'json').toLowerCase();
  if (!['json', 'pdf'].includes(format)) {
    return c.json({ error: { code: 'INVALID_FORMAT', message: 'format must be json or pdf' } }, 400);
  }

  // Enforce report quota (Blueprint line 646: free tier = 10/month)
  try { await checkQuota(c.env, user.id, user.role, 'report'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }

  try {
    if (format === 'pdf') {
      const { html, filename } = await generateStudentReportHtml(c.env, user.id, studentId);
      c.header('Content-Type', 'text/html; charset=utf-8');
      c.header('Content-Disposition', `inline; filename="${filename}"`);
      return c.body(html);
    }
    const report = await generateStudentReport(c.env, user.id, studentId);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

/** POST /api/reports/classroom/:classroom_id — generate a classroom report. */
reportRoutes.post('/classroom/:classroom_id', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('classroom_id');
  let body: { format?: string; include_recommendations?: boolean };
  try { body = await c.req.json(); } catch {
    body = {};
  }
  const format = (body.format ?? 'json').toLowerCase();
  if (!['json', 'pdf'].includes(format)) {
    return c.json({ error: { code: 'INVALID_FORMAT', message: 'format must be json or pdf' } }, 400);
  }

  try { await checkQuota(c.env, user.id, user.role, 'report'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }

  try {
    if (format === 'pdf') {
      const { html, filename } = await generateClassroomReportHtml(c.env, user.id, classroomId);
      c.header('Content-Type', 'text/html; charset=utf-8');
      c.header('Content-Disposition', `inline; filename="${filename}"`);
      return c.body(html);
    }
    const report = await generateClassroomReport(c.env, user.id, classroomId);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});