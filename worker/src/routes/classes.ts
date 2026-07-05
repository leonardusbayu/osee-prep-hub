import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { listUpcomingClasses, registerForClass } from '../services/live-class';

export const classRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

classRoutes.use('*', requireAuth());

/** GET /api/classes/upcoming — list upcoming live classes (Task 14.2) */
classRoutes.get('/upcoming', async (c) => {
  try {
    const classes = await listUpcomingClasses(c.env);
    return c.json({ classes });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/classes/:id/register — register for a class */
classRoutes.post('/:id/register', async (c) => {
  const user = getAuthedUser(c);
  try {
    await registerForClass(c.env, user.id, c.req.param('id'));
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'REGISTER_FAILED', message: (err as Error).message } }, 400);
  }
});