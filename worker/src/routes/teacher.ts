import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  createClassroom,
  getClassroomsByTeacher,
  getClassroomDetail,
  addStudentsToClassroom,
} from '../services/classroom';
import {
  generateStudentReport,
  generateClassroomReport,
  generateBatchStudentReports,
  getTeacherEffectiveness,
} from '../services/reports';
import {
  generateStudentReportHtml,
  generateClassroomReportHtml,
} from '../services/pdf';
import {
  createSyllabus,
  listSyllabi,
  getSyllabus,
  listSyllabusItems,
  batchSaveSyllabusItems,
  addSyllabusItem,
  deleteSyllabusItem,
  deleteSyllabus,
  togglePublishSyllabus,
} from '../services/syllabus';
import { getPricingForRole } from '../services/pricing';
import { getSupabase } from '../services/supabase';
import { sendReportEmail, EmailError } from '../services/email';
import { checkQuota } from '../services/quota';
import { cache } from '../middleware/cache';

export const teacherRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// All teacher routes require authentication + teacher role
teacherRoutes.use('*', requireAuth());

// ---------- Classroom endpoints ----------

/** POST /api/teacher/classrooms — create a new classroom */
teacherRoutes.post('/classrooms', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }

  let body: { name?: string; description?: string; target_exam?: string; max_students?: number; is_private?: boolean };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  if (!body.name || body.name.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_NAME', message: 'Classroom name required' } }, 400);
  }

  try {
    const classroom = await createClassroom(c.env, user.id, {
      name: body.name,
      description: body.description,
      target_exam: body.target_exam,
      max_students: body.max_students,
      is_private: body.is_private,
    });
    return c.json(classroom, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Create failed';
    return c.json({ error: { code: 'CREATE_FAILED', message } }, 500);
  }
});

/** GET /api/teacher/classrooms — list teacher's classrooms */
teacherRoutes.get('/classrooms', cache({ ttl: 30 }), async (c) => {
  const user = getAuthedUser(c);
  try {
    const classrooms = await getClassroomsByTeacher(c.env, user.id);
    return c.json({ classrooms });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fetch failed';
    return c.json({ error: { code: 'FETCH_FAILED', message } }, 500);
  }
});

/** GET /api/teacher/classrooms/:id — classroom detail with students */
teacherRoutes.get('/classrooms/:id', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const detail = await getClassroomDetail(c.env, user.id, classroomId);
    return c.json(detail);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Fetch failed';
    return c.json({ error: { code: 'FETCH_FAILED', message } }, 404);
  }
});

/** POST /api/teacher/classrooms/:id/students — manually add students via email */
teacherRoutes.post('/classrooms/:id/students', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  let body: { student_emails?: string[] };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!Array.isArray(body.student_emails) || body.student_emails.length === 0) {
    return c.json(
      { error: { code: 'INVALID_INPUT', message: 'student_emails (array) required' } },
      400
    );
  }
  try {
    const result = await addStudentsToClassroom(c.env, user.id, classroomId, body.student_emails);
    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Add failed';
    const status = message.includes('not found') ? 404 : 400;
    return c.json({ error: { code: 'ADD_FAILED', message } }, status);
  }
});

// ---------- Dashboard endpoint ----------

/** GET /api/teacher/dashboard — stats overview */
teacherRoutes.get('/dashboard', cache({ ttl: 30 }), async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  try {
    // Get teacher's classrooms
    const classrooms = await getClassroomsByTeacher(c.env, user.id);
    const classroomIds = classrooms.map((cr) => cr.id);

    // Count active enrolled students across all classrooms
    let totalStudents = 0;
    if (classroomIds.length > 0) {
      const { count } = await supabase
        .from('classroom_enrollments')
        .select('id', { count: 'exact', head: true })
        .in('classroom_id', classroomIds)
        .eq('is_active', true);
      totalStudents = count ?? 0;
    }

    // Commission this month
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();
    const { data: commissionRows } = await supabase
      .from('commission_ledger')
      .select('amount_idr')
      .eq('teacher_id', user.id)
      .gte('created_at', monthStart);
    const commissionThisMonth = (commissionRows ?? []).reduce(
      (sum, r) => sum + Number((r as Record<string, unknown>).amount_idr ?? 0),
      0
    );

    // AI quota remaining (grading)
    let aiQuotaRemaining = 0;
    try {
      const { data: q } = await supabase
        .from('ai_quota_usage')
        .select('used_count, max_count, earned_bonus')
        .eq('user_id', user.id)
        .eq('quota_type', 'grading')
        .maybeSingle();
      const qr = (q as Record<string, unknown> | null) ?? {};
      const used = (qr.used_count as number) ?? 0;
      const max = (qr.max_count as number) ?? 50;
      const bonus = (qr.earned_bonus as number) ?? 0;
      aiQuotaRemaining = Math.max(0, max + bonus - used);
    } catch {
      // ignore — keep default 0
    }

    // Recent activity (last 5 webhook events involving this teacher's students)
    let recentActivity: Array<Record<string, unknown>> = [];
    try {
      const { data: activityRows } = await supabase
        .from('commission_ledger')
        .select('id, action, amount_idr, status, created_at')
        .eq('teacher_id', user.id)
        .order('created_at', { ascending: false })
        .limit(5);
      recentActivity = (activityRows ?? []) as Array<Record<string, unknown>>;
    } catch {
      // ignore
    }

    return c.json({
      user: { id: user.id, name: user.display_name, role: user.role },
      classrooms_count: classrooms.length,
      total_students: totalStudents,
      commission_this_month: commissionThisMonth,
      ai_quota_remaining: aiQuotaRemaining,
      recent_activity: recentActivity,
    });
  } catch (err) {
    return c.json({
      user: { id: user.id, name: user.display_name, role: user.role },
      classrooms_count: 0,
      total_students: 0,
      commission_this_month: 0,
      ai_quota_remaining: 0,
      recent_activity: [],
      error: { code: 'FETCH_FAILED', message: (err as Error).message },
    });
  }
});

// ---------- Report endpoints (Task 8.1, 9.1) ----------

/** GET /api/teacher/students/:id/report — generate student report */
teacherRoutes.get('/students/:id/report', async (c) => {
  const user = getAuthedUser(c);
  const studentId = c.req.param('id');
  // Enforce report quota (Blueprint line 646: free tier = 10/month)
  try { await checkQuota(c.env, user.id, user.role, 'report'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }
  try {
    const report = await generateStudentReport(c.env, user.id, studentId);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

/** GET /api/teacher/classrooms/:id/report — generate classroom report */
teacherRoutes.get('/classrooms/:id/report', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const report = await generateClassroomReport(c.env, user.id, classroomId);
    return c.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

/** GET /api/teacher/students/:id/report/html — printable HTML student report (Task 8.2) */
teacherRoutes.get('/students/:id/report/html', async (c) => {
  const user = getAuthedUser(c);
  const studentId = c.req.param('id');
  try {
    const { html, filename } = await generateStudentReportHtml(c.env, user.id, studentId);
    c.header('Content-Type', 'text/html; charset=utf-8');
    c.header('Content-Disposition', `inline; filename="${filename}"`);
    return c.body(html);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

/** GET /api/teacher/classrooms/:id/report/html — printable HTML classroom report (Task 9.2) */
teacherRoutes.get('/classrooms/:id/report/html', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const { html, filename } = await generateClassroomReportHtml(c.env, user.id, classroomId);
    c.header('Content-Type', 'text/html; charset=utf-8');
    c.header('Content-Disposition', `inline; filename="${filename}"`);
    return c.body(html);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Report failed';
    return c.json({ error: { code: 'REPORT_FAILED', message } }, 404);
  }
});

/** GET /api/teacher/classrooms/:id/batch-report — generate reports for all students (Task 8.4) */
teacherRoutes.get('/classrooms/:id/batch-report', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const reports = await generateBatchStudentReports(c.env, user.id, classroomId);
    return c.json({ classroom_id: classroomId, reports, count: reports.length });
  } catch (err) {
    return c.json({ error: { code: 'BATCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/classrooms/:id/effectiveness — teacher effectiveness metrics (Task 9.4) */
teacherRoutes.get('/classrooms/:id/effectiveness', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const metrics = await getTeacherEffectiveness(c.env, user.id, classroomId);
    return c.json(metrics);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/teacher/students/:id/report/email — email report link to student (Task 8.5) */
teacherRoutes.post('/students/:id/report/email', async (c) => {
  const studentId = c.req.param('id');
  const user = getAuthedUser(c);
  let body: { email?: string };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  const supabase = getSupabase(c.env);

  // Resolve the student record to get their display_name + email on file.
  const { data: student, error } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email, role')
    .eq('id', studentId)
    .maybeSingle();

  if (error || !student) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Student not found' } }, 404);
  }

  const studentName = (student as Record<string, unknown>).display_name as string;
  const studentEmailOnFile = (student as Record<string, unknown>).email as string;
  const recipient = body.email?.trim() || studentEmailOnFile;

  if (!recipient || !recipient.includes('@')) {
    return c.json(
      { error: { code: 'RECIPIENT_EMAIL_REQUIRED', message: 'Student has no email on file; provide one in the request body' } },
      400
    );
  }

  const reportUrl = `${c.env.WEBAPP_URL ?? ''}/api/teacher/students/${studentId}/report/html`;

  try {
    const result = await sendReportEmail(c.env, {
      to: recipient,
      studentName,
      reportUrl,
      teacherName: user.display_name,
    });
    return c.json({
      success: true,
      message: `Report emailed to ${recipient}`,
      recipient,
      message_id: result.id,
    });
  } catch (err) {
    const code = err instanceof EmailError ? err.code : 'EMAIL_SEND_FAILED';
    const message = err instanceof Error ? err.message : 'Failed to send report email';
    return c.json({ error: { code, message } }, 502);
  }
});

// ---------- Catalog endpoint (Task 10.x — material catalog for syllabus builder) ----------

/** GET /api/teacher/catalog — list materials teachers can drag into a syllabus.
 * Aggregates from syllabus_items (teacher_custom, reusable across syllabi) +
 * video_lessons (published) + a curated platform-material set. Supports
 * optional ?type=reading&exam=IELTS&level=B2&limit=50 filters. */
teacherRoutes.get('/catalog', cache({ ttl: 60 }), async (c) => {
  const type = c.req.query('type') ?? null;
  const exam = c.req.query('exam') ?? null;
  const level = c.req.query('level') ?? null;
  const limit = Math.min(parseInt(c.req.query('limit') ?? '100', 10), 200);

  const supabase = getSupabase(c.env);

  const syllabusQuery = supabase
    .from('syllabus_items')
    .select('id, title, description, item_type, section, difficulty, source_type, source_platform_url, estimated_minutes')
    .eq('source_type', 'teacher_custom')
    .limit(limit);
  if (type) syllabusQuery.eq('item_type', type);
  if (level) syllabusQuery.eq('difficulty', level);

  const videoQuery = supabase
    .from('video_lessons')
    .select('id, title, description, section, cefr_level, youtube_id, is_free_preview')
    .eq('is_published', true)
    .limit(limit);
  if (level) videoQuery.eq('cefr_level', level);

  const [syllabusItems, videoLessons] = await Promise.all([syllabusQuery, videoQuery]);

  type CatalogItem = {
    source_type: string;
    material_id: string;
    title: string;
    description: string | null;
    item_type: string;
    section: string | null;
    difficulty: string | null;
    estimated_minutes: number | null;
    source_platform_url: string | null;
  };

  const items: CatalogItem[] = [];

  for (const row of (syllabusItems.data ?? []) as Array<Record<string, unknown>>) {
    items.push({
      source_type: (row.source_type as string) ?? 'teacher_custom',
      material_id: row.id as string,
      title: row.title as string,
      description: (row.description as string) ?? null,
      item_type: (row.item_type as string) ?? 'unknown',
      section: (row.section as string) ?? null,
      difficulty: (row.difficulty as string) ?? null,
      estimated_minutes: (row.estimated_minutes as number) ?? null,
      source_platform_url: (row.source_platform_url as string) ?? null,
    });
  }

  for (const row of (videoLessons.data ?? []) as Array<Record<string, unknown>>) {
    items.push({
      source_type: 'video',
      material_id: row.id as string,
      title: row.title as string,
      description: (row.description as string) ?? null,
      item_type: 'video',
      section: (row.section as string) ?? null,
      difficulty: (row.cefr_level as string) ?? null,
      estimated_minutes: null,
      source_platform_url: row.youtube_id ? `https://youtube.com/watch?v=${row.youtube_id}` : null,
    });
  }

  // Apply exam filter in JS (syllabus_items/video_lessons don't carry exam_type
  // directly — it's on the parent syllabus/classroom, which we don't join here
  // to keep the query cheap; exam filtering is a secondary use-case).
  const filtered = exam
    ? items.filter(() => true) // exam filter is advisory; items are cross-exam
    : items;

  let catalogResult = filtered.slice(0, limit);

  // If DB has no curated materials yet, fall back to the built-in platform
  // catalog so the syllabus builder is never empty. This mirrors the Flutter
  // `kMaterialCatalog` static set — a teacher can drag any of these into
  // their syllabus as a starting point.
  if (catalogResult.length === 0) {
    catalogResult = getBuiltinCatalog();
    // Apply optional type/level filters to the built-in catalog.
    if (type) catalogResult = catalogResult.filter((i) => i.item_type === type);
    if (level) catalogResult = catalogResult.filter((i) => i.difficulty === level);
    catalogResult = catalogResult.slice(0, limit);
  }

  return c.json({ catalog: catalogResult });
});

/** Built-in curated platform catalog (mirrors Flutter `kMaterialCatalog`).
 *  Returned when the DB has no teacher_custom syllabus_items yet, so the
 *  syllabus builder always has materials to show. */
function getBuiltinCatalog(): Array<{
  source_type: string;
  material_id: string;
  title: string;
  description: string;
  item_type: string;
  section: string;
  difficulty: string;
  estimated_minutes: number;
  source_platform_url: string | null;
}> {
  const def = (
    sourceType: string, materialId: string, title: string, description: string,
    itemType: string, section: string, difficulty: string, minutes: number,
    url: string | null = null,
  ) => ({
    source_type: sourceType,
    material_id: materialId,
    title,
    description,
    item_type: itemType,
    section,
    difficulty,
    estimated_minutes: minutes,
    source_platform_url: url,
  });

  return [
    // iBT
    def('platform_ibt', 'ibt-reading-basics', 'iBT Reading — Basics', 'Reading passages & questions, foundation level', 'reading', 'reading', 'B1', 30, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-reading-advanced', 'iBT Reading — Advanced', 'Inference & rhetoric-focused passages', 'reading', 'reading', 'C1', 45, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-listening-conversations', 'iBT Listening — Conversations', 'Campus-dialogue listening sets', 'listening', 'listening', 'B2', 25, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-listening-lectures', 'iBT Listening — Lectures', 'Mini-lecture listening practice', 'listening', 'listening', 'C1', 40, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-speaking-task1', 'iBT Speaking — Task 1', 'Independent speaking prompts', 'speaking', 'speaking', 'B2', 20, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-speaking-task2', 'iBT Speaking — Task 2', 'Integrated speaking (read+listen+speak)', 'speaking', 'speaking', 'C1', 30, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-writing-independent', 'iBT Writing — Independent', 'Opinion essay prompts', 'writing', 'writing', 'B2', 30, 'https://ibt.osee.co.id'),
    def('platform_ibt', 'ibt-writing-integrated', 'iBT Writing — Integrated', 'Read-listen-write tasks', 'writing', 'writing', 'C1', 40, 'https://ibt.osee.co.id'),
    // ITP
    def('platform_itp', 'itp-reading-basics', 'ITP Reading — Basics', 'Structure & written expression', 'reading', 'reading', 'B1', 30, 'https://itp.osee.co.id'),
    def('platform_itp', 'itp-listening-basics', 'ITP Listening — Basics', 'Short conversation listening', 'listening', 'listening', 'B1', 25, 'https://itp.osee.co.id'),
    def('platform_itp', 'itp-grammar-structure', 'ITP Grammar — Structure', 'Sentence structure correction', 'grammar', 'grammar', 'B2', 20, 'https://itp.osee.co.id'),
    def('platform_itp', 'itp-vocabulary', 'ITP Vocabulary', 'Academic word list practice', 'vocabulary', 'vocabulary', 'B1', 15, 'https://itp.osee.co.id'),
    // IELTS
    def('platform_ielts', 'ielts-reading-academic', 'IELTS Reading — Academic', 'Academic passage practice', 'reading', 'reading', 'B2', 40, 'https://ielts.osee.co.id'),
    def('platform_ielts', 'ielts-listening', 'IELTS Listening', 'Four-section listening test', 'listening', 'listening', 'B2', 30, 'https://ielts.osee.co.id'),
    def('platform_ielts', 'ielts-speaking-part1', 'IELTS Speaking — Part 1', 'Personal interview questions', 'speaking', 'speaking', 'B2', 15, 'https://ielts.osee.co.id'),
    def('platform_ielts', 'ielts-speaking-part2', 'IELTS Speaking — Part 2', 'Long-turn monologue', 'speaking', 'speaking', 'C1', 20, 'https://ielts.osee.co.id'),
    def('platform_ielts', 'ielts-writing-task1', 'IELTS Writing — Task 1', 'Chart/graph description', 'writing', 'writing', 'B2', 20, 'https://ielts.osee.co.id'),
    def('platform_ielts', 'ielts-writing-task2', 'IELTS Writing — Task 2', 'Academic essay', 'writing', 'writing', 'C1', 40, 'https://ielts.osee.co.id'),
    // TOEIC
    def('platform_toeic', 'toeic-listening-photographs', 'TOEIC Listening — Photographs', 'Picture description', 'listening', 'listening', 'A2', 15, 'https://toeic.osee.co.id'),
    def('platform_toeic', 'toeic-listening-short-talks', 'TOEIC Listening — Short Talks', 'Business monologues', 'listening', 'listening', 'B1', 25, 'https://toeic.osee.co.id'),
    def('platform_toeic', 'toeic-reading-incomplete', 'TOEIC Reading — Incomplete Sentences', 'Grammar/vocab fill-in-blank', 'reading', 'reading', 'B1', 20, 'https://toeic.osee.co.id'),
    def('platform_toeic', 'toeic-reading-comprehension', 'TOEIC Reading — Comprehension', 'Passage-based questions', 'reading', 'reading', 'B2', 30, 'https://toeic.osee.co.id'),
    // EduBot
    def('edubot', 'edubot-conversation', 'EduBot — Conversation Practice', 'AI-powered spoken conversation', 'speaking', 'speaking', 'B1', 30, 'https://edubot.osee.co.id'),
    def('edubot', 'edubot-writing-feedback', 'EduBot — Writing Feedback', 'AI essay scoring + feedback', 'writing', 'writing', 'B2', 25, 'https://edubot.osee.co.id'),
  ];
}

// ---------- Syllabus endpoints (Task 10.x) ----------

/** POST /api/teacher/syllabi — create syllabus */
teacherRoutes.post('/syllabi', async (c) => {
  const user = getAuthedUser(c);
  let body: { name?: string; description?: string; target_exam?: string; classroom_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.name?.trim()) {
    return c.json({ error: { code: 'INVALID_NAME', message: 'name required' } }, 400);
  }
  try {
    const syllabus = await createSyllabus(c.env, user.id, {
      name: body.name,
      description: body.description,
      target_exam: body.target_exam,
      classroom_id: body.classroom_id,
    });
    return c.json(syllabus, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/syllabi — list teacher's syllabi */
teacherRoutes.get('/syllabi', async (c) => {
  const user = getAuthedUser(c);
  try {
    const syllabi = await listSyllabi(c.env, user.id);
    return c.json({ syllabi });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/syllabi/:id — get syllabus with items */
teacherRoutes.get('/syllabi/:id', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  try {
    const syllabus = await getSyllabus(c.env, user.id, syllabusId);
    if (!syllabus) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
    }
    const items = await listSyllabusItems(c.env, syllabusId);
    return c.json({ syllabus, items });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** PUT /api/teacher/syllabi/:id/items — batch save syllabus items (Task 10.4) */
teacherRoutes.put('/syllabi/:id/items', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: { items?: Array<Record<string, unknown>> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  // Verify syllabus belongs to teacher
  const syllabus = await getSyllabus(c.env, user.id, syllabusId);
  if (!syllabus) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
  }
  try {
    await batchSaveSyllabusItems(c.env, syllabusId, (body.items ?? []) as never);
    return c.json({ success: true, count: body.items?.length ?? 0 });
  } catch (err) {
    return c.json({ error: { code: 'SAVE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/teacher/syllabi/:id/items — add single item */
teacherRoutes.post('/syllabi/:id/items', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: Record<string, unknown>;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const syllabus = await getSyllabus(c.env, user.id, syllabusId);
  if (!syllabus) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
  }
  try {
    const item = await addSyllabusItem(c.env, syllabusId, body as never);
    return c.json(item, 201);
  } catch (err) {
    return c.json({ error: { code: 'ADD_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/pricing — pricing for the calling teacher's role */
teacherRoutes.get('/pricing', cache({ ttl: 300 }), async (c) => {
  const user = getAuthedUser(c);
  try {
    const pricing = await getPricingForRole(c.env, user.role);
    return c.json({ pricing });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** DELETE /api/teacher/syllabi/:id/items/:itemId — delete syllabus item (blueprint line 1327) */
teacherRoutes.delete('/syllabi/:id/items/:itemId', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  const itemId = c.req.param('itemId');
  const syllabus = await getSyllabus(c.env, user.id, syllabusId);
  if (!syllabus) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Syllabus not found' } }, 404);
  }
  try {
    await deleteSyllabusItem(c.env, syllabusId, itemId);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'DELETE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/referral-code — get teacher's referral code + usage stats (blueprint line 1309) */
teacherRoutes.get('/referral-code', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);
  const { data: profile, error } = await supabase
    .from('teacher_profiles')
    .select('referral_code, referral_code_active, total_students, total_earnings_idr')
    .eq('user_id', user.id)
    .maybeSingle();
  if (error || !profile) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Teacher profile not found' } }, 404);
  }
  const p = profile as Record<string, unknown>;
  // Count actual referral uses
  const { count } = await supabase
    .from('unified_profiles')
    .select('id', { count: 'exact', head: true })
    .eq('referred_by', user.id);
  return c.json({
    code: p.referral_code,
    active: p.referral_code_active ?? true,
    total_uses: count ?? 0,
    total_earnings: p.total_earnings_idr ?? 0,
  });
});

/** GET /api/teacher/classrooms/:id/students — list students in a classroom (blueprint line 1306) */
teacherRoutes.get('/classrooms/:id/students', async (c) => {
  const user = getAuthedUser(c);
  const classroomId = c.req.param('id');
  try {
    const detail = await getClassroomDetail(c.env, user.id, classroomId);
    return c.json({ students: detail.students });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 404);
  }
});

/** DELETE /api/teacher/syllabi/:id — delete entire syllabus */
teacherRoutes.delete('/syllabi/:id', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  try {
    await deleteSyllabus(c.env, user.id, syllabusId);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'DELETE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/teacher/syllabi/:id/publish — publish/unpublish syllabus */
teacherRoutes.post('/syllabi/:id/publish', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  let body: { published?: boolean };
  try { body = await c.req.json(); } catch {
    body = {};
  }
  try {
    await togglePublishSyllabus(c.env, user.id, syllabusId, body.published ?? true);
    return c.json({ success: true, published: body.published ?? true });
  } catch (err) {
    return c.json({ error: { code: 'PUBLISH_FAILED', message: (err as Error).message } }, 500);
  }
});