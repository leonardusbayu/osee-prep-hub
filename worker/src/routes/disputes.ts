/**
 * Dispute routes — T28 (Wave 4).
 *
 * POST   /api/disputes                          — open dispute
 * GET    /api/disputes/me                       — my disputes (as buyer)
 * POST   /api/disputes/:id/resolve              — admin resolves (refund or reject)
 * GET    /api/disputes/:id                      — view dispute
 * GET    /api/marketplace/sellers/:id/reputation — public reputation
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  openDispute,
  resolveDispute,
  recomputeSellerReputation,
  type Dispute,
} from '../services/disputes';
import { getSupabase } from '../services/supabase';

export const disputeRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

disputeRoutes.use('*', requireAuth());

/** POST /api/disputes — open dispute. */
disputeRoutes.post('/', async (c) => {
  const user = getAuthedUser(c);
  let body: { purchaseId?: string; reason?: string; description?: string; evidenceUrls?: string[] };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.purchaseId || !body.reason || !body.description) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'purchaseId, reason, description required' } }, 400);
  }
  const validReasons = ['not_as_described', 'never_delivered', 'quality_issue', 'duplicate', 'other'];
  if (!validReasons.includes(body.reason)) {
    return c.json({ error: { code: 'INVALID_REASON', message: `reason must be one of: ${validReasons.join(', ')}` } }, 400);
  }
  try {
    const dispute = await openDispute(
      c.env,
      user.id,
      body.purchaseId,
      body.reason as Dispute['reason'],
      body.description,
      body.evidenceUrls ?? []
    );
    return c.json({ dispute }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Open failed';
    return c.json({ error: { code: 'OPEN_FAILED', message } }, 400);
  }
});

/** GET /api/disputes/me — list my disputes. */
disputeRoutes.get('/me', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('marketplace_disputes')
    .select('*, marketplace_purchases!marketplace_disputes_purchase_id_fkey(listing_id, buyer_id, seller_id, escrow_status)')
    .order('created_at', { ascending: false })
    .limit(20);
  if (error) return c.json({ error: { code: 'LIST_FAILED', message: error.message } }, 500);
  const my = (data ?? []).filter((d: any) =>
    d.marketplace_purchases?.buyer_id === user.id || d.marketplace_purchases?.seller_id === user.id
  );
  return c.json({ disputes: my });
});

/** GET /api/disputes/:id — view single dispute. */
disputeRoutes.get('/:id', async (c) => {
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('marketplace_disputes')
    .select('*, marketplace_purchases!marketplace_disputes_purchase_id_fkey(buyer_id, seller_id)')
    .eq('id', id)
    .single();
  if (error || !data) return c.json({ error: { code: 'NOT_FOUND', message: 'Dispute not found' } }, 404);
  const user = getAuthedUser(c);
  const purchase = data.marketplace_purchases as any;
  if (purchase?.buyer_id !== user.id && purchase?.seller_id !== user.id && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Not your dispute' } }, 403);
  }
  return c.json({ dispute: data });
});

/** POST /api/disputes/:id/resolve — admin only. */
disputeRoutes.post('/:id/resolve', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  let body: { resolution?: string; notes?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.resolution || !['resolved_refund', 'resolved_reject'].includes(body.resolution)) {
    return c.json({ error: { code: 'INVALID_RESOLUTION', message: 'resolution must be resolved_refund or resolved_reject' } }, 400);
  }
  try {
    await resolveDispute(c.env, id, user.id, body.resolution as 'resolved_refund' | 'resolved_reject', body.notes ?? '');
    return c.json({ resolved: id });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Resolve failed';
    return c.json({ error: { code: 'RESOLVE_FAILED', message } }, 400);
  }
});

/** GET /api/marketplace/sellers/:id/reputation — public. */
disputeRoutes.get('/sellers/:id/reputation', async (c) => {
  const sellerId = c.req.param('id');
  if (!sellerId) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  try {
    const reputation = await recomputeSellerReputation(c.env, sellerId);
    return c.json(reputation);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Reputation failed';
    return c.json({ error: { code: 'REPUTATION_FAILED', message } }, 500);
  }
});