/**
 * Viral routes — T25 (Wave 3).
 *
 * GET  /api/viral/referral/me              — get/create my referral code
 * POST /api/viral/share                    — record a share event
 * GET  /api/viral/redirect/:code           — public redirect for share links
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser, optionalAuth } from '../middleware/auth';
import {
  getOrCreateReferralCode,
  recordShareEvent,
  recordShareClick,
  convertReferral,
} from '../services/viral';

export const viralRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

/** GET /api/viral/referral/me — auth required. */
viralRoutes.get('/referral/me', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  try {
    const data = await getOrCreateReferralCode(c.env, user.id);
    return c.json(data);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Failed';
    return c.json({ error: { code: 'REFERRAL_FAILED', message } }, 500);
  }
});

/** POST /api/viral/share */
viralRoutes.post('/share', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  let body: { surface?: string; entityId?: string; channel?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.surface || !body.entityId) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'surface, entityId required' } }, 400);
  }
  const validSurfaces = ['passport_share', 'coach_recommend', 'syllabus_share', 'marketplace_listing'];
  if (!validSurfaces.includes(body.surface)) {
    return c.json({ error: { code: 'INVALID_SURFACE', message: `surface must be one of: ${validSurfaces.join(', ')}` } }, 400);
  }
  try {
    await recordShareEvent(
      c.env,
      user.id,
      body.surface as 'passport_share' | 'coach_recommend' | 'syllabus_share' | 'marketplace_listing',
      body.entityId,
      body.channel as 'whatsapp' | 'twitter' | 'email' | 'copy_link' | 'instagram' | undefined
    );
    return c.json({ recorded: true });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Record failed';
    return c.json({ error: { code: 'RECORD_FAILED', message } }, 500);
  }
});

/** GET /api/viral/redirect/:code — public redirect endpoint. */
viralRoutes.get('/redirect/:code', optionalAuth(), async (c) => {
  const code = c.req.param('code');
  if (!code) return c.json({ error: { code: 'BAD_REQUEST', message: 'code required' } }, 400);

  const { referrerId } = await recordShareClick(c.env, code);

  // If user is authenticated, convert the referral.
  const user = c.get('user');
  if (user && referrerId && user.id !== referrerId) {
    await convertReferral(c.env, code, user.id);
  }

  // Redirect to landing page with code prefilled.
  return c.redirect(`/register?ref=${code}`, 302);
});