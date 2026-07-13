import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { listVideoCourses, getCourse, trackProgress } from '../services/video';
import { cache } from '../middleware/cache';

export const videoRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

videoRoutes.use('*', requireAuth());

/** GET /api/videos/courses — list video courses */
videoRoutes.get('/courses', cache({ ttl: 120, varyByUser: false }), async (c) => {
  try {
    const courses = await listVideoCourses(c.env);
    return c.json({ courses });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/videos/courses/:id — get course + lessons */
videoRoutes.get('/courses/:id', async (c) => {
  try {
    const course = await getCourse(c.env, c.req.param('id'));
    if (!course) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Course not found' } }, 404);
    }
    return c.json(course);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/videos/lessons/:id/progress — track watch progress (Task 13.3) */
videoRoutes.post('/lessons/:id/progress', async (c) => {
  const user = getAuthedUser(c);
  let body: { watched_seconds?: number; completed?: boolean; quiz_score?: number };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    await trackProgress(c.env, user.id, c.req.param('id'), {
      watched_seconds: body.watched_seconds ?? 0,
      completed: body.completed ?? false,
      quiz_score: body.quiz_score,
    });
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'TRACK_FAILED', message: (err as Error).message } }, 500);
  }
});