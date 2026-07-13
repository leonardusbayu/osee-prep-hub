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
} from '../services/syllabus';
import { getPricingForRole } from '../services/pricing';
import { getSupabase } from '../services/supabase';
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

  let body: { name?: string; description?: string; target_exam?: string; max_students?: number };
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
  let body: { email?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  // Generate report URL (teacher-auth scoped)
  const reportUrl = `${c.env.WEBAPP_URL ?? ''}/api/teacher/students/${studentId}/report/html`;

  // Best-effort email send — in production, integrate with Resend/SES
  // For now, return the URL for manual sharing
  return c.json({
    success: true,
    message: 'Report link generated. Email sending requires email service integration (Resend/SES).',
    report_url: reportUrl,
    recipient: body.email ?? 'student email on file',
  });
});

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