/**
 * Ambassador v2 routes — T37 (Wave 5).
 *
 * GET  /api/ambassador-v2/me              — get my tier
 * POST /api/ambassador-v2/sync            — recompute tier from current data
 * GET  /api/ambassador-v2/tiers           — list all tier definitions
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  syncAmbassadorTier,
  getAmbassadorTierRecord,
  TIER_DEFINITIONS,
} from '../services/ambassador-v2';

export const ambassadorV2Routes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

ambassadorV2Routes.use('*', requireAuth());

/** GET /api/ambassador-v2/me */
ambassadorV2Routes.get('/me', async (c) => {
  const user = getAuthedUser(c);
  const tier = await getAmbassadorTierRecord(c.env, user.id);
  return c.json({ tier: tier ?? { user_id: user.id, tier: 'partner', commission_multiplier: 1.00, equity_grant_idr: 0, equity_vest_years: 0, badge: null, joined_at: new Date().toISOString(), promoted_at: null, notes: null } });
});

/** POST /api/ambassador-v2/sync */
ambassadorV2Routes.post('/sync', async (c) => {
  const user = getAuthedUser(c);
  try {
    const tier = await syncAmbassadorTier(c.env, user.id);
    return c.json({ tier });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Sync failed';
    return c.json({ error: { code: 'SYNC_FAILED', message } }, 500);
  }
});

/** GET /api/ambassador-v2/tiers — public tier definitions. */
ambassadorV2Routes.get('/tiers', (c) => {
  return c.json({ tiers: TIER_DEFINITIONS });
});