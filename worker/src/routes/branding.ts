import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  getBrandingConfig,
  upsertBrandingConfig,
  getTeacherTier,
  upgradeTeacherTier,
  cancelTeacherTier,
} from '../services/branding';

/**
 * Branding + tier routes — Task 15.1, 15.2, 15.3, 15.4.
 *
 * All routes require authentication. Tier upgrade is available to teacher role.
 */
export const brandingRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

brandingRoutes.use('*', requireAuth());

/** GET /api/branding — current branding config + tier info */
brandingRoutes.get('/', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  try {
    const [branding, tier] = await Promise.all([
      getBrandingConfig(c.env, user.id),
      getTeacherTier(c.env, user.id),
    ]);
    return c.json({ branding, tier });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** PUT /api/branding — update branding config */
brandingRoutes.put('/', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  let body: {
    logo_url?: string | null;
    primary_color?: string;
    secondary_color?: string;
    custom_subdomain?: string | null;
    hide_osee_branding?: boolean;
    custom_copyright?: string | null;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    const result = await upsertBrandingConfig(c.env, user.id, body);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/branding/upgrade — upgrade to Pro or Institution (Task 15.2, 15.3) */
brandingRoutes.post('/upgrade', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  let body: { tier?: string; payment_reference?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (body.tier !== 'pro' && body.tier !== 'institution') {
    return c.json({ error: { code: 'INVALID_TIER', message: 'tier must be pro or institution' } }, 400);
  }
  try {
    const result = await upgradeTeacherTier(c.env, user.id, body.tier, body.payment_reference);
    return c.json(result, 200);
  } catch (err) {
    return c.json({ error: { code: 'UPGRADE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/branding/cancel — cancel subscription, revert to free */
brandingRoutes.post('/cancel', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'teacher' && user.role !== 'partner') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teacher role required' } }, 403);
  }
  try {
    const result = await cancelTeacherTier(c.env, user.id);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'CANCEL_FAILED', message: (err as Error).message } }, 500);
  }
});