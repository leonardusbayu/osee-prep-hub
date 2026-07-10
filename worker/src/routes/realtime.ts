/**
 * Syllabus collaborator routes — Task 2 (Wave 1).
 *
 * POST   /api/syllabi/:id/collaborators          — owner invites by email
 * GET    /api/syllabi/:id/collaborators          — list collaborators
 * DELETE /api/syllabi/:id/collaborators/:userId   — owner removes collaborator
 *
 * The realtime transport (Yjs sync, presence, postgres_changes) is handled
 * directly by Supabase Realtime on the client. These routes only manage
 * collaborator membership + authorization.
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  canAccessSyllabus,
  inviteCollaborator,
  listCollaborators,
} from '../services/realtime';
import { getSupabase } from '../services/supabase';

export const realtimeRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

realtimeRoutes.use('*', requireAuth());

/** POST /:id/collaborators — invite by email. (mounted at /api/syllabi) */
realtimeRoutes.post('/:id/collaborators', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');

  let body: { email?: string; role?: 'editor' | 'viewer' };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.email) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'email required' } }, 400);
  }
  const role = body.role === 'viewer' ? 'viewer' : 'editor';

  try {
    const collab = await inviteCollaborator(c.env, syllabusId, user.id, body.email, role);
    return c.json({ collaborator: collab }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Invite failed';
    return c.json({ error: { code: 'INVITE_FAILED', message } }, 400);
  }
});

/** GET /:id/collaborators — list collaborators + owner. (mounted at /api/syllabi) */
realtimeRoutes.get('/:id/collaborators', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');

  const access = await canAccessSyllabus(c.env, user.id, syllabusId);
  if (!access.allowed) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Not a collaborator on this syllabus' } }, 403);
  }

  try {
    const collaborators = await listCollaborators(c.env, syllabusId);
    return c.json({ collaborators, yourRole: access.role });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'List failed';
    return c.json({ error: { code: 'LIST_FAILED', message } }, 500);
  }
});

/** DELETE /:id/collaborators/:userId — owner removes collaborator. (mounted at /api/syllabi) */
realtimeRoutes.delete('/:id/collaborators/:userId', async (c) => {
  const user = getAuthedUser(c);
  const syllabusId = c.req.param('id');
  const targetUserId = c.req.param('userId');

  // Only owner can remove.
  const access = await canAccessSyllabus(c.env, user.id, syllabusId);
  if (!access.allowed || access.role !== 'owner') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Only the owner can remove collaborators' } }, 403);
  }
  if (targetUserId === user.id) {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Owner cannot remove themselves' } }, 400);
  }

  const supabase = getSupabase(c.env);
  const { error } = await supabase
    .from('syllabus_collaborators')
    .delete()
    .eq('syllabus_id', syllabusId)
    .eq('user_id', targetUserId);
  if (error) {
    return c.json({ error: { code: 'REMOVE_FAILED', message: error.message } }, 500);
  }
  return c.json({ removed: targetUserId });
});