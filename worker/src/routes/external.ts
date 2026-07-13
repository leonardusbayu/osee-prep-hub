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

/** GET /api/external/student-deep-links/:student_id — EduBot gets deep-links to practice platforms (Task 16.3).
 *
 * Returns the URLs of all OSEE practice platforms tailored to the student's
 * target_exam + current syllabus items. EduBot uses these to deep-link the
 * student directly into the relevant practice set.
 */
externalRoutes.get('/student-deep-links/:student_id', async (c) => {
  const studentId = c.req.param('student_id');
  const { getSupabase } = await import('../services/supabase');
  const supabase = getSupabase(c.env);

  // Get student profile
  const { data: student } = await supabase
    .from('unified_profiles')
    .select('id, target_exam, current_level')
    .eq('id', studentId)
    .maybeSingle();
  if (!student) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Student not found' } }, 404);
  }
  const s = student as Record<string, unknown>;
  const targetExam = (s.target_exam as string) ?? 'GENERAL';

  // Get student's active syllabus items
  const { data: enrollments } = await supabase
    .from('classroom_enrollments')
    .select('classroom:classrooms!classroom_enrollments_classroom_id_fkey (id)')
    .eq('student_id', studentId)
    .eq('is_active', true);
  const classroomIds = ((enrollments ?? []) as Array<Record<string, unknown>>).map((e) => {
    const c = e.classroom as Record<string, unknown>;
    return c.id as string;
  });

  let syllabusItems: Array<Record<string, unknown>> = [];
  if (classroomIds.length > 0) {
    const { data: syllabi } = await supabase
      .from('syllabi')
      .select('id')
      .in('classroom_id', classroomIds)
      .eq('is_published', true);
    const syllabusIds = ((syllabi ?? []) as Array<Record<string, unknown>>).map((s) => s.id as string);
    if (syllabusIds.length > 0) {
      const { data: items } = await supabase
        .from('syllabus_items')
        .select('id, title, source_type, source_platform_url, item_type, section')
        .in('syllabus_id', syllabusIds)
        .order('sort_order', { ascending: true })
        .limit(20);
      syllabusItems = (items ?? []) as Array<Record<string, unknown>>;
    }
  }

  // Base platform URLs
  const platformUrls: Record<string, string> = {
    TOEFL_IBT: 'https://ibt.osee.co.id',
    TOEFL_ITP: 'https://test.osee.co.id',
    IELTS: 'https://ielts.osee.co.id',
    TOEIC: 'https://toeic.osee.co.id',
    GENERAL: 'https://test.osee.co.id',
  };

  // Build deep-links from syllabus items (use source_platform_url if set)
  type DeepLink = { title: string; url: string; type: string; section: string | null };
  const deepLinks: DeepLink[] = [];
  for (const item of syllabusItems) {
    const url = item.source_platform_url as string | null;
    if (!url) continue;
    deepLinks.push({
      title: item.title as string,
      url,
      type: item.item_type as string,
      section: (item.section as string) ?? null,
    });
  }

  return c.json({
    student_id: studentId,
    target_exam: targetExam,
    current_level: (s.current_level as string) ?? null,
    platform_home: platformUrls[targetExam] ?? platformUrls.GENERAL,
    practice_platforms: {
      ibt: 'https://ibt.osee.co.id',
      itp: 'https://test.osee.co.id',
      ielts: 'https://ielts.osee.co.id',
      toeic: 'https://toeic.osee.co.id',
      edubot: 'https://t.me/osee_edubot',
      osee_booking: 'https://osee.co.id',
    },
    syllabus_deep_links: deepLinks,
  });
});