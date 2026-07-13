import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { listVideoCourses, getCourse, trackProgress } from '../services/video';
import { cache } from '../middleware/cache';
import { getSupabase } from '../services/supabase';

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

/** GET /api/videos/lessons/:id — get single lesson detail (blueprint line 1462) */
videoRoutes.get('/lessons/:id', async (c) => {
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('video_lessons')
    .select('*')
    .eq('id', c.req.param('id'))
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Lesson not found' } }, 404);
  }
  // Free preview gating: if not free preview, check teacher subscription via branding service
  // For now, return lesson data — frontend gating decides whether to show
  return c.json(data);
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

/** POST /api/videos/lessons/:id/complete — record completion + quiz answers (blueprint line 1466) */
videoRoutes.post('/lessons/:id/complete', async (c) => {
  const user = getAuthedUser(c);
  let body: { quiz_answers?: Record<string, unknown>; time_spent?: number };
  try { body = await c.req.json().catch(() => ({})); } catch {
    body = {};
  }
  const supabase = getSupabase(c.env);

  // Fetch lesson to grade quiz
  const { data: lesson } = await supabase
    .from('video_lessons')
    .select('comprehension_questions')
    .eq('id', c.req.param('id'))
    .maybeSingle();
  const questions = ((lesson as Record<string, unknown>)?.comprehension_questions as Array<Record<string, unknown>>) ?? [];
  let quizScore: number | undefined;
  if (body.quiz_answers && questions.length > 0) {
    let correct = 0;
    for (const q of questions) {
      const qId = String(q.q_idx ?? q.id ?? '');
      const userAns = body.quiz_answers[qId];
      if (userAns !== undefined && Number(userAns) === Number(q.answer_idx)) {
        correct++;
      }
    }
    quizScore = questions.length > 0 ? Math.round((correct / questions.length) * 100) : undefined;
  }

  try {
    await trackProgress(c.env, user.id, c.req.param('id'), {
      watched_seconds: body.time_spent ?? 0,
      completed: true,
      quiz_score: quizScore,
    });
    return c.json({ success: true, quiz_score: quizScore });
  } catch (err) {
    return c.json({ error: { code: 'TRACK_FAILED', message: (err as Error).message } }, 500);
  }
});

// ---------- Admin CRUD for video_courses + video_lessons (Task 13.1) ----------

/** POST /api/videos/admin/courses — admin create video course */
videoRoutes.post('/admin/courses', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  let body: { title?: string; description?: string; exam_type?: string; difficulty?: string; thumbnail_url?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.title || !body.exam_type) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'title + exam_type required' } }, 400);
  }
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('video_courses')
    .insert({
      title: body.title,
      description: body.description,
      exam_type: body.exam_type,
      difficulty: body.difficulty,
      thumbnail_url: body.thumbnail_url,
      is_published: false,
    })
    .select()
    .single();
  if (error || !data) {
    return c.json({ error: { code: 'CREATE_FAILED', message: error?.message ?? 'unknown' } }, 500);
  }
  return c.json(data, 201);
});

/** PUT /api/videos/admin/courses/:id — admin update course */
videoRoutes.put('/admin/courses/:id', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  let body: Record<string, unknown>;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const supabase = getSupabase(c.env);
  const update: Record<string, unknown> = { updated_at: new Date().toISOString() };
  for (const k of ['title', 'description', 'exam_type', 'difficulty', 'thumbnail_url', 'total_lessons', 'is_published', 'is_free_preview', 'free_preview_lessons', 'price_idr']) {
    if (body[k] !== undefined) update[k] = body[k];
  }
  const { data, error } = await supabase
    .from('video_courses')
    .update(update)
    .eq('id', c.req.param('id'))
    .select()
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error?.message ?? 'not found' } }, 500);
  }
  return c.json(data);
});

/** POST /api/videos/admin/lessons — admin create lesson in a course */
videoRoutes.post('/admin/lessons', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  let body: { course_id?: string; lesson_number?: number; title?: string; description?: string; section?: string; cefr_level?: string; duration_seconds?: number; video_url_r2?: string; youtube_id?: string; comprehension_questions?: unknown; key_vocabulary?: unknown; practice_links?: unknown; is_published?: boolean; is_free_preview?: boolean };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.course_id || !body.title) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'course_id + title required' } }, 400);
  }
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('video_lessons')
    .insert({
      course_id: body.course_id,
      lesson_number: body.lesson_number ?? 1,
      title: body.title,
      description: body.description,
      section: body.section,
      cefr_level: body.cefr_level,
      duration_seconds: body.duration_seconds,
      video_url_r2: body.video_url_r2,
      youtube_id: body.youtube_id,
      comprehension_questions: body.comprehension_questions ?? [],
      key_vocabulary: body.key_vocabulary ?? [],
      practice_links: body.practice_links ?? [],
      is_published: body.is_published ?? false,
      is_free_preview: body.is_free_preview ?? false,
    })
    .select()
    .single();
  if (error || !data) {
    return c.json({ error: { code: 'CREATE_FAILED', message: error?.message ?? 'unknown' } }, 500);
  }
  return c.json(data, 201);
});

/** PUT /api/videos/admin/lessons/:id — admin update lesson */
videoRoutes.put('/admin/lessons/:id', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  let body: Record<string, unknown>;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const supabase = getSupabase(c.env);
  const update: Record<string, unknown> = {};
  for (const k of ['lesson_number', 'title', 'description', 'section', 'cefr_level', 'duration_seconds', 'video_url_r2', 'youtube_id', 'comprehension_questions', 'key_vocabulary', 'practice_links', 'is_published', 'is_free_preview', 'views_count']) {
    if (body[k] !== undefined) update[k] = body[k];
  }
  const { data, error } = await supabase
    .from('video_lessons')
    .update(update)
    .eq('id', c.req.param('id'))
    .select()
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error?.message ?? 'not found' } }, 500);
  }
  return c.json(data);
});