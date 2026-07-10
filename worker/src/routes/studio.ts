/**
 * Studio routes — T9 (Wave 2).
 *
 * POST /api/studio/:syllabusId/snapshot    — persist Yjs state snapshot
 * GET  /api/studio/:syllabusId/snapshot    — latest snapshot
 * POST /api/studio/:syllabusId/share       — generate read-only share link
 *
 * The real-time Yjs sync itself is client-side via Supabase Realtime.
 * These endpoints handle persistence + sharing only.
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  saveSnapshot,
  getLatestSnapshot,
  generateShareToken,
} from '../services/studio';
import { canAccessSyllabus } from '../services/realtime';

export const studioRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

studioRoutes.use('*', requireAuth());

/** POST /api/studio/:syllabusId/snapshot */
studioRoutes.post('/:syllabusId/snapshot', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('syllabusId');
  if (!syllabusId) return c.json({ error: { code: 'BAD_REQUEST', message: 'syllabusId required' } }, 400);

  const access = await canAccessSyllabus(c.env, user.id, syllabusId);
  if (!access.allowed || access.role === 'viewer') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Viewer cannot save snapshots' } }, 403);
  }

  let body: { state?: Record<string, unknown> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.state) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'state required' } }, 400);
  }
  try {
    const snap = await saveSnapshot(c.env, syllabusId, user.id, body.state);
    return c.json({ snapshot: snap }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Save failed';
    return c.json({ error: { code: 'SAVE_FAILED', message } }, 500);
  }
});

/** GET /api/studio/:syllabusId/snapshot */
studioRoutes.get('/:syllabusId/snapshot', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('syllabusId');
  if (!syllabusId) return c.json({ error: { code: 'BAD_REQUEST', message: 'syllabusId required' } }, 400);

  const access = await canAccessSyllabus(c.env, user.id, syllabusId);
  if (!access.allowed) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Not a collaborator' } }, 403);
  }

  const snap = await getLatestSnapshot(c.env, syllabusId);
  if (!snap) return c.json({ snapshot: null });
  return c.json({ snapshot: snap });
});

/** POST /api/studio/:syllabusId/share — generate read-only share token. */
studioRoutes.post('/:syllabusId/share', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('syllabusId');
  if (!syllabusId) return c.json({ error: { code: 'BAD_REQUEST', message: 'syllabusId required' } }, 400);

  const access = await canAccessSyllabus(c.env, user.id, syllabusId);
  if (!access.allowed || access.role !== 'owner') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Only the owner can create share links' } }, 403);
  }
  const token = generateShareToken(syllabusId);
  return c.json({ shareToken: token, shareUrl: `/studio/shared/${token}` });
});