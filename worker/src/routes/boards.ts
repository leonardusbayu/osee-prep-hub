import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getSupabase } from '../services/supabase';
import {
  createBoard,
  listBoards,
  getBoard,
  updateBoard,
  saveBoardState,
  listBoardVersions,
  getBoardVersion,
  restoreBoardVersion,
  deleteBoard,
  shareBoard,
  listBoardShares,
  revokeShare,
  listSharedWithMe,
} from '../services/lesson-board';
import {
  listMaterials,
  getMaterial,
  addMaterial,
  addMaterialFromSource,
  updateMaterial,
  deleteMaterial,
  ingestMaterialToRag,
} from '../services/teacher-materials';
import { listTemplates, getTemplate, createTemplate } from '../services/lesson-templates';
import { reviewLesson, generateAssessment } from '../services/lesson-ai';
import type { AssessmentType } from '../services/lesson-ai';
import { checkQuota } from '../services/quota';

export const boardRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

boardRoutes.use('*', requireAuth());

// ============================================================
// Boards CRUD
// ============================================================

/** POST /api/boards — create a new lesson board */
boardRoutes.post('/', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  let body: { title?: string; description?: string; syllabus_id?: string; target_exam?: string; cefr_level?: string; tags?: string[]; kp_tags?: unknown };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.title?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'title required' } }, 400);
  }
  try {
    const board = await createBoard(c.env, user.id, {
      title: body.title,
      description: body.description,
      syllabus_id: body.syllabus_id,
      target_exam: body.target_exam,
      cefr_level: body.cefr_level,
      tags: body.tags,
      kp_tags: body.kp_tags,
    });
    return c.json(board, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards — list teacher's boards */
boardRoutes.get('/', async (c) => {
  const user = getAuthedUser(c);
  const includeArchived = c.req.query('include_archived') === 'true';
  try {
    const boards = await listBoards(c.env, user.id, { includeArchived });
    return c.json({ boards, count: boards.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards/:id — get a board (full canvas_state) */
boardRoutes.get('/:id', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  try {
    const board = await getBoard(c.env, user.id, boardId);
    if (!board) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Board not found or access denied' } }, 404);
    }
    return c.json(board);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** PATCH /api/boards/:id — update board metadata */
boardRoutes.patch('/:id', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { title?: string; description?: string; tags?: string[]; kp_tags?: unknown; target_exam?: string; cefr_level?: string; status?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    const board = await updateBoard(c.env, user.id, boardId, body);
    return c.json(board);
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found') || message.includes('not owned')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'UPDATE_FAILED', message } }, 500);
  }
});

/** PUT /api/boards/:id/canvas — save canvas state (autosave or explicit) */
boardRoutes.put('/:id/canvas', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { canvas_state?: Record<string, unknown>; autosave?: boolean; label?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.canvas_state) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'canvas_state required' } }, 400);
  }
  try {
    const result = await saveBoardState(c.env, user.id, boardId, body.canvas_state, {
      autosave: body.autosave ?? false,
      label: body.label,
    });
    return c.json(result);
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found') || message.includes('not owned')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'SAVE_FAILED', message } }, 500);
  }
});

/** DELETE /api/boards/:id — delete a board */
boardRoutes.delete('/:id', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  try {
    await deleteBoard(c.env, user.id, boardId);
    return c.json({ ok: true });
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found') || message.includes('not owned')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'DELETE_FAILED', message } }, 500);
  }
});

// ============================================================
// Version history
// ============================================================

/** GET /api/boards/:id/versions — list version snapshots */
boardRoutes.get('/:id/versions', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  try {
    const versions = await listBoardVersions(c.env, user.id, boardId);
    return c.json({ versions, count: versions.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards/:id/versions/:versionId — get a version snapshot (for restore) */
boardRoutes.get('/:id/versions/:versionId', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  const versionId = c.req.param('versionId');
  try {
    const version = await getBoardVersion(c.env, user.id, boardId, versionId);
    if (!version) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Version not found' } }, 404);
    }
    return c.json(version);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/boards/:id/versions/:versionId/restore — restore a board to a previous version */
boardRoutes.post('/:id/versions/:versionId/restore', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  const versionId = c.req.param('versionId');
  try {
    const board = await restoreBoardVersion(c.env, user.id, boardId, versionId);
    return c.json(board);
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'RESTORE_FAILED', message } }, 500);
  }
});

// ============================================================
// Sharing
// ============================================================

/** POST /api/boards/:id/shares — share a board with another teacher */
boardRoutes.post('/:id/shares', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { shared_with_email?: string; permission?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.shared_with_email?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'shared_with_email required' } }, 400);
  }
  const validPerms = ['view', 'edit', 'admin'];
  if (!body.permission || !validPerms.includes(body.permission)) {
    return c.json({ error: { code: 'INVALID_PERM', message: `permission must be one of: ${validPerms.join(', ')}` } }, 400);
  }
  try {
    const share = await shareBoard(c.env, user.id, boardId, {
      shared_with_email: body.shared_with_email,
      permission: body.permission,
    });
    return c.json(share, 201);
  } catch (err) {
    return c.json({ error: { code: 'SHARE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards/:id/shares — list shares for a board */
boardRoutes.get('/:id/shares', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  try {
    const shares = await listBoardShares(c.env, user.id, boardId);
    return c.json({ shares, count: shares.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** DELETE /api/boards/:id/shares/:shareId — revoke a share */
boardRoutes.delete('/:id/shares/:shareId', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  const shareId = c.req.param('shareId');
  try {
    await revokeShare(c.env, user.id, boardId, shareId);
    return c.json({ ok: true });
  } catch (err) {
    return c.json({ error: { code: 'REVOKE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards/shared-with-me — list boards shared with the current user */
boardRoutes.get('/shared-with-me/list', async (c) => {
  const user = getAuthedUser(c);
  try {
    const shared = await listSharedWithMe(c.env, user.id);
    return c.json({ shared, count: shared.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

// ============================================================
// Comments
// ============================================================

/** GET /api/boards/:id/comments — list comments on a board (optionally filtered by node_id) */
boardRoutes.get('/:id/comments', async (c) => {
  const boardId = c.req.param('id');
  const nodeId = c.req.query('node_id');
  try {
    const supabase = getSupabase(c.env);
    let query = supabase
      .from('node_comments')
      .select('id, node_id, author_id, body, resolved, created_at, updated_at')
      .eq('board_id', boardId)
      .order('created_at', { ascending: false });
    if (nodeId) {
      query = query.eq('node_id', nodeId);
    }
    const { data, error } = await query;
    if (error) throw new Error(error.message);
    return c.json({ comments: data ?? [], count: data?.length ?? 0 });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/boards/:id/comments — add a comment to a node */
boardRoutes.post('/:id/comments', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { node_id?: string; body?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.node_id?.trim() || !body.body?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'node_id and body required' } }, 400);
  }
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('node_comments')
      .insert({ board_id: boardId, node_id: body.node_id, author_id: user.id, body: body.body })
      .select('id, node_id, author_id, body, resolved, created_at')
      .single();
    if (error) throw new Error(error.message);
    return c.json(data, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** PATCH /api/boards/:id/comments/:commentId — resolve/unresolve a comment */
boardRoutes.patch('/:id/comments/:commentId', async (c) => {
  const commentId = c.req.param('commentId');
  let body: { resolved?: boolean; body?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    const supabase = getSupabase(c.env);
    const updatePayload: Record<string, unknown> = {};
    if (body.resolved !== undefined) updatePayload.resolved = body.resolved;
    if (body.body !== undefined) updatePayload.body = body.body;
    const { data, error } = await supabase
      .from('node_comments')
      .update(updatePayload)
      .eq('id', commentId)
      .select()
      .single();
    if (error) throw new Error(error.message);
    return c.json(data);
  } catch (err) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** DELETE /api/boards/:id/comments/:commentId — delete a comment */
boardRoutes.delete('/:id/comments/:commentId', async (c) => {
  const commentId = c.req.param('commentId');
  try {
    const supabase = getSupabase(c.env);
    const { error } = await supabase.from('node_comments').delete().eq('id', commentId);
    if (error) throw new Error(error.message);
    return c.json({ ok: true });
  } catch (err) {
    return c.json({ error: { code: 'DELETE_FAILED', message: (err as Error).message } }, 500);
  }
});

// ============================================================
// Assessments
// ============================================================

/** GET /api/boards/:id/assessments — list assessments for a board */
boardRoutes.get('/:id/assessments', async (c) => {
  const boardId = c.req.param('id');
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('lesson_assessments')
      .select('id, type, node_id, content, created_at, updated_at')
      .eq('board_id', boardId)
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return c.json({ assessments: data ?? [], count: data?.length ?? 0 });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/boards/:id/assessments — generate + save an assessment */
boardRoutes.post('/:id/assessments', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { type?: string; node_id?: string; topic?: string; level?: string; exam?: string; node_content?: Record<string, unknown> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const validTypes: AssessmentType[] = ['answer_key', 'rubric', 'exit_ticket', 'auto_grade_config', 'quiz'];
  if (!body.type || !validTypes.includes(body.type as AssessmentType)) {
    return c.json({ error: { code: 'INVALID_TYPE', message: `type must be one of: ${validTypes.join(', ')}` } }, 400);
  }
  if (!body.topic?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'topic required' } }, 400);
  }
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
  }
  try {
    const content = await generateAssessment(c.env, {
      type: body.type as AssessmentType,
      node_id: body.node_id,
      topic: body.topic,
      level: body.level,
      exam: body.exam,
      node_content: body.node_content,
    });
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('lesson_assessments')
      .insert({ board_id: boardId, type: body.type, node_id: body.node_id ?? null, content })
      .select('id, type, node_id, content, created_at')
      .single();
    if (error) throw new Error(error.message);
    return c.json(data, 201);
  } catch (err) {
    return c.json({ error: { code: 'ASSESSMENT_FAILED', message: (err as Error).message } }, 500);
  }
});

// ============================================================
// AI Critic + Feedback
// ============================================================

/** POST /api/boards/:id/review — AI critic reviews the board's content */
boardRoutes.post('/:id/review', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { nodes?: Array<{ id: string; type: string; title: string; content: Record<string, unknown> }>; target_exam?: string; cefr_level?: string; kp_tags?: Array<{ code: string; label: string }> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.nodes || body.nodes.length === 0) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'nodes array required' } }, 400);
  }
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
  }
  try {
    const review = await reviewLesson(c.env, {
      board_id: boardId,
      nodes: body.nodes,
      target_exam: body.target_exam,
      cefr_level: body.cefr_level,
      kp_tags: body.kp_tags,
    });
    // Persist the critic review as feedback rows
    const supabase = getSupabase(c.env);
    for (const finding of review.findings) {
      await supabase.from('lesson_ai_feedback').insert({
        board_id: boardId,
        node_id: finding.node_id,
        feedback_type: 'critic',
        severity: finding.severity,
        body: finding.message,
        category: finding.category,
        reported_by: user.id,
        ai_response: { suggestion: finding.suggestion, ...review } as Record<string, unknown>,
      });
    }
    return c.json(review);
  } catch (err) {
    return c.json({ error: { code: 'REVIEW_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards/:id/feedback — list AI feedback + teacher flags for a board */
boardRoutes.get('/:id/feedback', async (c) => {
  const boardId = c.req.param('id');
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('lesson_ai_feedback')
      .select('id, node_id, feedback_type, severity, body, category, resolved, reported_by, ai_response, created_at')
      .eq('board_id', boardId)
      .order('created_at', { ascending: false });
    if (error) throw new Error(error.message);
    return c.json({ feedback: data ?? [], count: data?.length ?? 0 });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/boards/:id/feedback — teacher flags a node as inaccurate */
boardRoutes.post('/:id/feedback', async (c) => {
  const user = getAuthedUser(c);
  const boardId = c.req.param('id');
  let body: { node_id?: string; feedback_type?: string; severity?: string; body?: string; category?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.node_id?.trim() || !body.body?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'node_id and body required' } }, 400);
  }
  const validTypes = ['teacher_flag', 'student_flag'];
  if (!body.feedback_type || !validTypes.includes(body.feedback_type)) {
    body.feedback_type = 'teacher_flag';
  }
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('lesson_ai_feedback')
      .insert({
        board_id: boardId,
        node_id: body.node_id,
        feedback_type: body.feedback_type,
        severity: body.severity ?? 'warning',
        body: body.body,
        category: body.category ?? 'other',
        reported_by: user.id,
      })
      .select('id, node_id, feedback_type, severity, body, category, created_at')
      .single();
    if (error) throw new Error(error.message);
    return c.json(data, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** PATCH /api/boards/:id/feedback/:feedbackId — resolve a feedback item */
boardRoutes.patch('/:id/feedback/:feedbackId', async (c) => {
  const feedbackId = c.req.param('feedbackId');
  let body: { resolved?: boolean };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('lesson_ai_feedback')
      .update({ resolved: body.resolved ?? true })
      .eq('id', feedbackId)
      .select()
      .single();
    if (error) throw new Error(error.message);
    return c.json(data);
  } catch (err) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: (err as Error).message } }, 500);
  }
});

// ============================================================
// Templates
// ============================================================

/** GET /api/boards/templates — list lesson templates */
boardRoutes.get('/templates/list', async (c) => {
  const category = c.req.query('category');
  const includeUnofficial = c.req.query('include_unofficial') === 'true';
  try {
    const templates = await listTemplates(c.env, { category, includeUnofficial });
    return c.json({ templates, count: templates.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/boards/templates/:templateId — get a template (full canvas_state) */
boardRoutes.get('/templates/:templateId', async (c) => {
  const templateId = c.req.param('templateId');
  try {
    const template = await getTemplate(c.env, templateId);
    if (!template) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Template not found' } }, 404);
    }
    return c.json(template);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/boards/templates — create a custom template */
boardRoutes.post('/templates/create', async (c) => {
  const user = getAuthedUser(c);
  let body: { name?: string; description?: string; category?: string; canvas_state?: Record<string, unknown>; target_exam?: string; cefr_level?: string; kp_tags?: unknown };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.name?.trim() || !body.category?.trim() || !body.canvas_state) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'name, category, canvas_state required' } }, 400);
  }
  try {
    const template = await createTemplate(c.env, user.id, {
      name: body.name,
      description: body.description,
      category: body.category,
      canvas_state: body.canvas_state,
      target_exam: body.target_exam,
      cefr_level: body.cefr_level,
      kp_tags: body.kp_tags,
    });
    return c.json(template, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

// ============================================================
// Teacher Materials library
// ============================================================

/** GET /api/materials — list teacher's materials */
boardRoutes.get('/materials/list', async (c) => {
  const user = getAuthedUser(c);
  const type = c.req.query('type');
  try {
    const materials = await listMaterials(c.env, user.id, { type });
    return c.json({ materials, count: materials.length });
  } catch (err) {
    return c.json({ error: { code: 'LIST_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/materials/:id — get a material (including extracted_text) */
boardRoutes.get('/materials/:id', async (c) => {
  const user = getAuthedUser(c);
  const materialId = c.req.param('id');
  try {
    const material = await getMaterial(c.env, user.id, materialId);
    if (!material) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Material not found' } }, 404);
    }
    return c.json(material);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/materials — add a material (direct insert) */
boardRoutes.post('/materials', async (c) => {
  const user = getAuthedUser(c);
  let body: { name?: string; type?: string; source_url?: string; storage_key?: string; storage_url?: string; extracted_text?: string; metadata?: Record<string, unknown>; tags?: string[]; size_bytes?: number; cluster_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.name?.trim() || !body.type?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'name and type required' } }, 400);
  }
  try {
    const material = await addMaterial(c.env, user.id, {
      name: body.name!,
      type: body.type!,
      source_url: body.source_url,
      storage_key: body.storage_key,
      storage_url: body.storage_url,
      extracted_text: body.extracted_text,
      metadata: body.metadata,
      tags: body.tags,
      size_bytes: body.size_bytes,
      cluster_id: body.cluster_id,
    });
    return c.json(material, 201);
  } catch (err) {
    return c.json({ error: { code: 'CREATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/materials/ingest — ingest a source as a material (URL/YouTube/PDF/text) */
boardRoutes.post('/materials/ingest', async (c) => {
  const user = getAuthedUser(c);
  let body: { name?: string; type?: string; url?: string; content?: string; filename?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.name?.trim() || !body.type?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'name and type required' } }, 400);
  }
  try {
    const material = await addMaterialFromSource(c.env, user.id, {
      name: body.name,
      type: body.type as 'youtube' | 'url' | 'pdf' | 'text',
      url: body.url,
      content: body.content,
      filename: body.filename,
    });
    return c.json(material, 201);
  } catch (err) {
    return c.json({ error: { code: 'INGEST_FAILED', message: (err as Error).message } }, 400);
  }
});

/** POST /api/materials/:id/ingest-rag — embed a material's text into the RAG knowledge base */
boardRoutes.post('/materials/:id/ingest-rag', async (c) => {
  const user = getAuthedUser(c);
  const materialId = c.req.param('id');
  try {
    const result = await ingestMaterialToRag(c.env, user.id, materialId);
    return c.json(result);
  } catch (err) {
    const message = (err as Error).message;
    if (message.includes('not found')) {
      return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    }
    return c.json({ error: { code: 'INGEST_FAILED', message } }, 500);
  }
});

/** PATCH /api/materials/:id — update a material */
boardRoutes.patch('/materials/:id', async (c) => {
  const user = getAuthedUser(c);
  const materialId = c.req.param('id');
  let body: { name?: string; tags?: string[]; metadata?: Record<string, unknown> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    const material = await updateMaterial(c.env, user.id, materialId, body);
    return c.json(material);
  } catch (err) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** DELETE /api/materials/:id — delete a material */
boardRoutes.delete('/materials/:id', async (c) => {
  const user = getAuthedUser(c);
  const materialId = c.req.param('id');
  try {
    await deleteMaterial(c.env, user.id, materialId);
    return c.json({ ok: true });
  } catch (err) {
    return c.json({ error: { code: 'DELETE_FAILED', message: (err as Error).message } }, 500);
  }
});