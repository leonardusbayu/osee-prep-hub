import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { verifyStudent, receiveProgress, getTeacherSyllabusForTutor } from '../services/edubot-bridge';

/**
 * EduBot bridge routes — Task 16.x.
 *
 * These endpoints are called by EduBot (not by Flutter).
 * Auth via EDUBOT_INTERNAL_SECRET header (NOT requireAuth middleware).
 */
export const externalRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

/** Simple internal-secret auth middleware for EduBot bridge */
const requireEdubotSecret = () => {
  return async (
    c: import('hono').Context<{ Bindings: Env; Variables: ContextVars }>,
    next: () => Promise<void>
  ): Promise<Response | void> => {
    const provided = c.req.header('X-Internal-Secret');
    if (!provided || provided !== c.env.EDUBOT_INTERNAL_SECRET) {
      return c.json({ error: { code: 'UNAUTHORIZED', message: 'Invalid internal secret' } }, 401);
    }
    await next();
  };
};

externalRoutes.use('*', requireEdubotSecret());

/** POST /api/external/verify-student — EduBot verifies a Telegram user (Task 16.2) */
externalRoutes.post('/verify-student', async (c) => {
  let body: { telegram_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.telegram_id) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'telegram_id required' } }, 400);
  }
  try {
    const student = await verifyStudent(c.env, body.telegram_id);
    if (!student) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Student not found' } }, 404);
    }
    return c.json(student);
  } catch (err) {
    return c.json({ error: { code: 'FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/external/student-progress — EduBot reports progress (Task 16.5) */
externalRoutes.post('/student-progress', async (c) => {
  let body: { user_id?: string; activity_type?: string; score?: number; topic?: string; metadata?: Record<string, unknown> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.user_id || !body.activity_type) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'user_id and activity_type required' } }, 400);
  }
  try {
    await receiveProgress(c.env, body.user_id, {
      activity_type: body.activity_type,
      score: body.score,
      topic: body.topic,
      metadata: body.metadata,
    });
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/external/teacher-syllabus/:teacher_id — EduBot reads syllabus topics (Task 16.4) */
externalRoutes.get('/teacher-syllabus/:teacher_id', async (c) => {
  try {
    const data = await getTeacherSyllabusForTutor(c.env, c.req.param('teacher_id'));
    return c.json({ students: data });
  } catch (err) {
    return c.json({ error: { code: 'FAILED', message: (err as Error).message } }, 500);
  }
});