import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  listUpcomingClasses,
  registerForClass,
  sendUpcomingClassReminders,
  sendClassReminder,
} from '../services/live-class';
import { cache } from '../middleware/cache';

export const classRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

/** Cron entrypoint — send reminders for classes starting in the next hour.
 *  Public endpoint gated by EDUBOT_INTERNAL_SECRET header. */
classRoutes.post('/cron/remind', async (c) => {
  const provided = c.req.header('X-Internal-Secret');
  if (!provided || provided !== c.env.EDUBOT_INTERNAL_SECRET) {
    return c.json({ error: { code: 'UNAUTHORIZED', message: 'Invalid internal secret' } }, 401);
  }
  try {
    const result = await sendUpcomingClassReminders(c.env);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'CRON_FAILED', message: (err as Error).message } }, 500);
  }
});

// All other class routes require authentication
classRoutes.use('*', requireAuth());

/** GET /api/classes/upcoming — list upcoming live classes (Task 14.2) */
classRoutes.get('/upcoming', cache({ ttl: 60, varyByUser: false }), async (c) => {
  try {
    const classes = await listUpcomingClasses(c.env);
    return c.json({ classes });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/classes/:id — single class detail */
classRoutes.get('/:id', async (c) => {
  const supabase = (await import('../services/supabase')).getSupabase(c.env);
  const { data, error } = await supabase
    .from('live_classes')
    .select('*')
    .eq('id', c.req.param('id'))
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Class not found' } }, 404);
  }
  return c.json(data);
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

/** POST /api/classes/:id/remind — manually trigger reminder (admin/teacher only) */
classRoutes.post('/:id/remind', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher or admin role required' } }, 403);
  }
  try {
    const result = await sendClassReminder(c.env, c.req.param('id'));
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'REMIND_FAILED', message: (err as Error).message } }, 500);
  }
});