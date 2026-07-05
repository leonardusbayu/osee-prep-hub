import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getAmbassadorStats } from '../services/ambassador';

export const ambassadorRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

ambassadorRoutes.use('*', requireAuth());

/** GET /api/ambassador/dashboard — ambassador dashboard (Task 17.2) */
ambassadorRoutes.get('/dashboard', async (c) => {
  const user = getAuthedUser(c);
  try {
    const stats = await getAmbassadorStats(c.env, user.id);
    return c.json(stats);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});