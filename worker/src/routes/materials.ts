import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  listPackages,
  getPackage,
  listQuestions,
  getQuestion,
  listSkills,
  searchQuestions,
  recordAnswer,
  getStudentAnswers,
  getClassroomProgress,
  getPracticeSession,
  submitPracticeSession,
  getPracticeHistory,
} from '../services/material-bank';

export const materialRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

materialRoutes.use('*', requireAuth());

/** GET /api/materials/packages — list packages (query: exam_type, product_line) */
materialRoutes.get('/packages', async (c) => {
  const examType = c.req.query('exam_type');
  const productLine = c.req.query('product_line');
  try {
    const packages = await listPackages(c.env, { examType, productLine });
    return c.json({ packages, count: packages.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/packages/:id — get a package */
materialRoutes.get('/packages/:id', async (c) => {
  const packageId = c.req.param('id');
  try {
    const pkg = await getPackage(c.env, packageId);
    if (!pkg) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Package not found' } }, 404);
    }
    return c.json(pkg);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/questions — list questions */
materialRoutes.get('/questions', async (c) => {
  const packageId = c.req.query('package_id');
  const examType = c.req.query('exam_type');
  const part = c.req.query('part');
  const section = c.req.query('section');
  const cefrLevel = c.req.query('cefr_level');
  const skillTag = c.req.query('skill_tag');
  const limit = c.req.query('limit') ? parseInt(c.req.query('limit') as string, 10) : undefined;
  const offset = c.req.query('offset') ? parseInt(c.req.query('offset') as string, 10) : undefined;
  try {
    const result = await listQuestions(c.env, {
      packageId, examType, part, section, cefrLevel, skillTag, limit, offset,
    });
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/questions/:id — get a single question */
materialRoutes.get('/questions/:id', async (c) => {
  const questionId = c.req.param('id');
  try {
    const question = await getQuestion(c.env, questionId);
    if (!question) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Question not found' } }, 404);
    }
    return c.json(question);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/skills — list skill taxonomy (query: exam_type) */
materialRoutes.get('/skills', async (c) => {
  const examType = c.req.query('exam_type');
  try {
    const skills = await listSkills(c.env, { examType });
    return c.json({ skills, count: skills.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/search — search questions (query: q, exam_type) */
materialRoutes.get('/search', async (c) => {
  const q = c.req.query('q');
  const examType = c.req.query('exam_type');
  if (!q?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'q query parameter required' } }, 400);
  }
  try {
    const questions = await searchQuestions(c.env, q, { examType });
    return c.json({ questions, count: questions.length });
  } catch (err) {
    return c.json({ error: { code: 'SEARCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/materials/answers — record a student's answer */
materialRoutes.post('/answers', async (c) => {
  const user = getAuthedUser(c);
  let body: {
    question_id?: string;
    student_answer?: string;
    is_correct?: boolean;
    time_spent_seconds?: number;
    classroom_id?: string;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.question_id || body.student_answer === undefined || body.is_correct === undefined) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'question_id, student_answer, is_correct required' } }, 400);
  }
  try {
    const answer = await recordAnswer(c.env, {
      student_id: user.id,
      question_id: body.question_id,
      student_answer: body.student_answer,
      is_correct: body.is_correct,
      time_spent_seconds: body.time_spent_seconds,
      classroom_id: body.classroom_id,
    });
    return c.json(answer, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/answers/:studentId — get student answer history (teacher or self only) */
materialRoutes.get('/answers/:studentId', async (c) => {
  const user = getAuthedUser(c);
  const studentId = c.req.param('studentId');
  if (user.role !== 'admin' && user.role !== 'teacher' && user.id !== studentId) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Can only view own answers or as teacher/admin' } }, 403);
  }
  try {
    const result = await getStudentAnswers(c.env, studentId);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/progress/:classroomId — classroom progress summary (teacher only) */
materialRoutes.get('/progress/:classroomId', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  const classroomId = c.req.param('classroomId');
  try {
    const progress = await getClassroomProgress(c.env, user.id, classroomId);
    return c.json({ progress, count: progress.length });
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found') || message.includes('not owned')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'FETCH_FAILED', message } }, 500);
  }
});

// ============================================================
// Practice sessions — student interactive practice
// ============================================================

/** GET /api/materials/practice/:packageId — get a shuffled practice session (student) */
materialRoutes.get('/practice/:packageId', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'student' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Student role required' } }, 403);
  }
  const packageId = c.req.param('packageId');
  const count = c.req.query('count') ? parseInt(c.req.query('count') as string, 10) : 20;
  try {
    const session = await getPracticeSession(c.env, packageId, count);
    return c.json(session);
  } catch (err) {
    return c.json({ error: { code: 'PRACTICE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/materials/practice/submit — submit practice answers (student) */
materialRoutes.post('/practice/submit', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'student' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Student role required' } }, 403);
  }
  let body: { answers?: Array<{ question_id: string; student_answer: string }>; classroom_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.answers || !Array.isArray(body.answers) || body.answers.length === 0) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'answers array required' } }, 400);
  }
  try {
    const result = await submitPracticeSession(c.env, user.id, body.answers, body.classroom_id);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'SUBMIT_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/practice/history — get practice session history (student) */
materialRoutes.get('/practice/history', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'student' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Student role required' } }, 403);
  }
  try {
    const history = await getPracticeHistory(c.env, user.id);
    return c.json({ history, count: history.length });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});