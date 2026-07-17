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

/** GET /api/videos/lessons/:id — get single lesson detail (blueprint line 1462)
 *
 *  Premium gating (Task 13.5):
 *  - If lesson.is_free_preview = true → anyone can access (YouTube ID only)
 *  - If lesson is premium (not free preview):
 *    - Students: check if they have an active premium subscription (via teacher Pro/Institution or EduBot premium)
 *    - Teachers/admins: always access (they manage content)
 *  - video_url_r2 is only returned if user has access; otherwise only youtube_id (if any) */
videoRoutes.get('/lessons/:id', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('video_lessons')
    .select('*')
    .eq('id', c.req.param('id'))
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Lesson not found' } }, 404);
  }

  const lesson = data as Record<string, unknown>;

  // Teachers and admins always have access
  if (user.role === 'teacher' || user.role === 'admin' || user.role === 'partner') {
    return c.json(lesson);
  }

  // Free preview lessons — anyone can access
  if (lesson.is_free_preview === true) {
    return c.json(lesson);
  }

  // Premium lesson — check student access
  // Check if student's teacher has Pro/Institution tier
  const { data: enrollment } = await supabase
    .from('classroom_enrollments')
    .select(`
      classroom:classrooms!classroom_enrollments_classroom_id_fkey (
        teacher_id
      )
    `)
    .eq('student_id', user.id)
    .eq('is_active', true)
    .limit(1)
    .maybeSingle();

  let hasAccess = false;

  if (enrollment) {
    const classroom = (enrollment as Record<string, unknown>).classroom as Record<string, unknown>;
    const teacherId = classroom?.teacher_id as string | undefined;
    if (teacherId) {
      // Check teacher's tier
      const { data: teacherProfile } = await supabase
        .from('teacher_profiles')
        .select('tier, tier_expires_at, is_ambassador')
        .eq('user_id', teacherId)
        .maybeSingle();
      const tp = (teacherProfile as Record<string, unknown> | null) ?? {};
      const tier = (tp.tier as string) ?? 'free';
      const isAmbassador = Boolean(tp.is_ambassador);
      const expiresAt = tp.tier_expires_at as string | null;
      const notExpired = !expiresAt || new Date(expiresAt).getTime() > Date.now();
      if ((tier === 'pro' || tier === 'institution' || isAmbassador) && notExpired) {
        hasAccess = true;
      }
    }
  }

  if (!hasAccess) {
    // Return lesson without premium video URL — only YouTube preview if available
    return c.json({
      ...lesson,
      video_url_r2: null,  // strip premium URL
      _premium_locked: true,
      _message: 'This is a premium lesson. Ask your teacher to upgrade to Pro.',
    });
  }

  return c.json(lesson);
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

    // Notify the student's teacher(s) that they completed a video lesson
    // (Blueprint line 1466: "Notifies teacher if student in classroom").
    // The student's teacher(s) are the teachers of the classrooms the
    // student is enrolled in.
    try {
      const { data: enrollments } = await supabase
        .from('classroom_enrollments')
        .select('classroom:classrooms!classroom_enrollments_classroom_id_fkey(teacher:unified_profiles!classrooms_teacher_id_fkey(teacher_id, telegram_id, display_name))')
        .eq('student_id', user.id)
        .eq('is_active', true);
      const teachers = ((enrollments ?? []) as Array<Record<string, unknown>>)
        .map((row) => row.classroom as Record<string, unknown>)
        .map((cl) => cl?.teacher as Record<string, unknown> | undefined)
        .filter((t): t is Record<string, unknown> => t !== undefined);
      const teacherIds = [...new Set(teachers.map((t) => t.teacher_id as string))];
      const teacherChatIds = teachers
        .map((t) => t.telegram_id as string | null)
        .filter((id): id is string => id !== null);

      if (c.env.TELEGRAM_BOT_TOKEN && teacherChatIds.length > 0) {
        const msg = `${user.display_name} completed a video lesson (quiz score: ${quizScore ?? 'n/a'}).`;
        for (const chatId of teacherChatIds) {
          await fetch(`https://api.telegram.org/bot${c.env.TELEGRAM_BOT_TOKEN}/sendMessage`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ chat_id: chatId, text: msg }),
          }).catch(() => {});
        }
      }
      // Log the notification for teachers without telegram
      if (teacherIds.length > 0) {
        console.log(`video complete: notified teacher(s) ${teacherIds.join(',')} that ${user.id} completed lesson ${c.req.param('id')}`);
      }
    } catch (notifErr) {
      // Notification is best-effort; don't fail the completion.
      console.error('notify teacher failed:', notifErr);
    }

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