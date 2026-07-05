import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { setPrice, listAllPricing } from '../services/pricing';

export const adminRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

adminRoutes.use('*', requireAuth());

/** Admin role guard */
adminRoutes.use('*', async (c, next) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  await next();
  return; // ensure all code paths return
});

/** GET /api/admin/pricing — list all pricing entries */
adminRoutes.get('/pricing', async (c) => {
  try {
    const pricing = await listAllPricing(c.env);
    return c.json({ pricing });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/admin/pricing — set/update price */
adminRoutes.post('/pricing', async (c) => {
  let body: { item_type?: string; role?: string; price?: number };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.item_type || !body.role || typeof body.price !== 'number') {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'item_type, role, price required' } }, 400);
  }
  try {
    await setPrice(c.env, body.item_type as never, body.role as never, body.price);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'SET_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/stats — platform-wide stats (placeholder for Task 18.4) */
adminRoutes.get('/stats', async (c) => {
  return c.json({
    total_users: 0,
    active_teachers: 0,
    total_revenue: 0,
    commission_paid: 0,
    ai_usage: 0,
    note: 'Full analytics — Task 18.4',
  });
});