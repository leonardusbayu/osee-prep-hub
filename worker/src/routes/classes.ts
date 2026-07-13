import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  listUpcomingClasses,
  registerForClass,
  sendUpcomingClassReminders,
  sendClassReminder,
  sendClassRecordingNotification,
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

// ---------- Admin CRUD for live_classes (Task 14.1) ----------

/** POST /api/classes/admin/create — admin create a live class */
classRoutes.post('/admin/create', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  let body: {
    title?: string;
    description?: string;
    teacher_name?: string;
    exam_type?: string;
    section?: string;
    cefr_level?: string;
    scheduled_at?: string;
    duration_minutes?: number;
    zoom_link?: string;
    is_free?: boolean;
    is_premium_only?: boolean;
    max_participants?: number;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.title || !body.scheduled_at || !body.zoom_link) {
    return c.json(
      { error: { code: 'INVALID_INPUT', message: 'title, scheduled_at, zoom_link required' } },
      400
    );
  }
  const { getSupabase } = await import('../services/supabase');
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('live_classes')
    .insert({
      title: body.title,
      description: body.description,
      teacher_name: body.teacher_name ?? 'OSEE Instructor',
      exam_type: body.exam_type,
      section: body.section,
      cefr_level: body.cefr_level,
      scheduled_at: body.scheduled_at,
      duration_minutes: body.duration_minutes ?? 90,
      zoom_link: body.zoom_link,
      is_free: body.is_free ?? true,
      is_premium_only: body.is_premium_only ?? false,
      max_participants: body.max_participants,
      status: 'scheduled',
    })
    .select()
    .single();
  if (error || !data) {
    return c.json({ error: { code: 'CREATE_FAILED', message: error?.message ?? 'unknown' } }, 500);
  }
  return c.json(data, 201);
});

/** PUT /api/classes/admin/:id — admin update a live class (e.g. upload recording) */
classRoutes.put('/admin/:id', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  let body: Record<string, unknown>;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const { getSupabase } = await import('../services/supabase');
  const supabase = getSupabase(c.env);
  const update: Record<string, unknown> = {};
  for (const k of ['title', 'description', 'teacher_name', 'exam_type', 'section', 'cefr_level', 'scheduled_at', 'duration_minutes', 'zoom_link', 'zoom_meeting_id', 'zoom_password', 'recording_url', 'recording_available', 'is_free', 'is_premium_only', 'max_participants', 'status']) {
    if (body[k] !== undefined) update[k] = body[k];
  }
  const { data, error } = await supabase
    .from('live_classes')
    .update(update)
    .eq('id', c.req.param('id'))
    .select()
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error?.message ?? 'not found' } }, 500);
  }
  // If recording_url uploaded + status completed → send Telegram notification
  if (body.recording_url && body.status === 'completed') {
    try {
      await sendClassRecordingNotification(c.env, c.req.param('id'), body.recording_url as string);
    } catch (err) {
      console.error('Recording notification failed:', err);
    }
  }
  return c.json(data);
});

/** DELETE /api/classes/admin/:id — admin cancel/delete a live class */
classRoutes.delete('/admin/:id', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  const { getSupabase } = await import('../services/supabase');
  const supabase = getSupabase(c.env);
  const { error } = await supabase
    .from('live_classes')
    .update({ status: 'cancelled' })
    .eq('id', c.req.param('id'));
  if (error) {
    return c.json({ error: { code: 'DELETE_FAILED', message: error.message } }, 500);
  }
  return c.json({ success: true });
});