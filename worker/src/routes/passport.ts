/**
 * Passport routes — Task 3 (Wave 1).
 *
 * POST   /api/passport/issue           — teacher/admin issues a credential
 * GET    /api/passport/:id             — PUBLIC: fetch credential + evidence
 * POST   /api/passport/:id/verify      — optional auth: employer verifies, records event
 * POST   /api/passport/:id/revoke      — auth (issuer/admin): revokes credential
 * GET    /.well-known/passport-public-key.pem — PUBLIC: Ed25519 public key PEM
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, requireRole, getAuthedUser, optionalAuth } from '../middleware/auth';
import {
  issueCredential,
  verifyCredential,
  revokeCredential,
  recordVerification,
  listAuditForCredential,
  type IssueInput,
} from '../services/passport';

export const passportRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

passportRoutes.use('*', requireAuth());

/** GET /api/passport/audit/:id — T27 admin: full audit log for a credential. */
passportRoutes.get('/audit/:id', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  try {
    const events = await listAuditForCredential(c.env, id);
    return c.json({ credential_id: id, events });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Audit failed';
    return c.json({ error: { code: 'AUDIT_FAILED', message } }, 500);
  }
});

/** POST /api/passport/issue — teacher/admin issues a credential. */
passportRoutes.post('/issue', requireAuth(), requireRole('teacher', 'admin'), async (c) => {
  const user = getAuthedUser(c);
  let body: IssueInput;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.userId || !body.credentialType || !body.subjectData) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'userId, credentialType, subjectData required' } }, 400);
  }
  const validTypes = ['score_report', 'course_completion', 'badge', 'recommendation'];
  if (!validTypes.includes(body.credentialType)) {
    return c.json({ error: { code: 'INVALID_TYPE', message: `credentialType must be one of: ${validTypes.join(', ')}` } }, 400);
  }
  try {
    // Override issuer_id with the authed user.
    const result = await issueCredential(c.env, body);
    // Patch issuer_id (insert used '' — update now).
    const { getSupabase } = await import('../services/supabase');
    const supabase = getSupabase(c.env);
    await supabase
      .from('passport_credentials')
      .update({ issuer_id: user.id })
      .eq('id', result.credential.id);
    result.credential.issuer_id = user.id;
    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Issue failed';
    return c.json({ error: { code: 'ISSUE_FAILED', message } }, 400);
  }
});

/** GET /api/passport/:id — PUBLIC: fetch credential + evidence + verification status. */
passportRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  const result = await verifyCredential(c.env, id);
  if (!result.credential) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Credential not found' } }, 404);
  }
  // Record the verification event (best-effort, anonymous).
  const ip = c.req.header('CF-Connecting-IP') ?? c.req.header('X-Forwarded-For') ?? null;
  await recordVerification(c.env, id, result.valid, result.reason, undefined, ip ?? undefined);
  return c.json(result);
});

/** POST /api/passport/:id/verify — optional auth: employer records a verification. */
passportRoutes.post('/:id/verify', optionalAuth(), async (c) => {
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  const user = c.get('user');
  const result = await verifyCredential(c.env, id);
  if (!result.credential) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Credential not found' } }, 404);
  }
  const ip = c.req.header('CF-Connecting-IP') ?? c.req.header('X-Forwarded-For') ?? null;
  await recordVerification(c.env, id, result.valid, result.reason, user?.id, ip ?? undefined);
  return c.json({ valid: result.valid, reason: result.reason });
});

/** POST /api/passport/:id/revoke — auth (issuer/admin): revokes credential. */
passportRoutes.post('/:id/revoke', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  let body: { reason?: string };
  try { body = await c.req.json(); } catch { body = {}; }
  try {
    await revokeCredential(c.env, id, user.id, body.reason ?? 'revoked_by_issuer');
    return c.json({ revoked: id });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Revoke failed';
    if (message.includes('not found')) return c.json({ error: { code: 'NOT_FOUND', message } }, 404);
    if (message.includes('Only the original')) return c.json({ error: { code: 'FORBIDDEN', message } }, 403);
    return c.json({ error: { code: 'REVOKE_FAILED', message } }, 500);
  }
});