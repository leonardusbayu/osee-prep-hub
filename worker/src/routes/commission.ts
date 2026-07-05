import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getCommissionStats, requestPayout } from '../services/commission-dashboard';

export const commissionRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

commissionRoutes.use('*', requireAuth());

/** GET /api/teacher/commission/dashboard — commission stats (Task 12.1) */
commissionRoutes.get('/dashboard', async (c) => {
  const user = getAuthedUser(c);
  try {
    const stats = await getCommissionStats(c.env, user.id);
    return c.json(stats);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/teacher/commission/recent — recent commission entries */
commissionRoutes.get('/recent', async (c) => {
  const user = getAuthedUser(c);
  try {
    const stats = await getCommissionStats(c.env, user.id);
    return c.json({ entries: stats.recent_entries });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/teacher/commission/payout — request payout (Task 12.2) */
commissionRoutes.post('/payout', async (c) => {
  const user = getAuthedUser(c);
  let body: { amount?: number };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.amount || body.amount <= 0) {
    return c.json({ error: { code: 'INVALID_AMOUNT', message: 'amount must be > 0' } }, 400);
  }
  try {
    const result = await requestPayout(c.env, user.id, body.amount);
    return c.json(result, 201);
  } catch (err) {
    return c.json({ error: { code: 'PAYOUT_FAILED', message: (err as Error).message } }, 400);
  }
});