import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getPartnerDashboard, getPartnerTeachers, inviteTeacher } from '../services/partner';

export const partnerRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

partnerRoutes.use('*', requireAuth());

/** Partner role guard */
partnerRoutes.use('*', async (c, next) => {
  const user = getAuthedUser(c);
  if (user.role !== 'partner' && user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Partner role required' } }, 403);
  }
  await next();
  return; // ensure all code paths return
});

/** GET /api/partner/dashboard — partner dashboard stats */
partnerRoutes.get('/dashboard', async (c) => {
  const user = getAuthedUser(c);
  try {
    const stats = await getPartnerDashboard(c.env, user.id);
    return c.json(stats);
  } catch (err) {
    return c.json({ error: { code: 'DASHBOARD_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/partner/teachers — list teachers in institution */
partnerRoutes.get('/teachers', async (c) => {
  const user = getAuthedUser(c);
  try {
    const teachers = await getPartnerTeachers(c.env, user.id);
    return c.json({ teachers });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/partner/teachers/invite — invite a teacher */
partnerRoutes.post('/teachers/invite', async (c) => {
  const user = getAuthedUser(c);
  let body: { email?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.email?.trim()) {
    return c.json({ error: { code: 'INVALID_EMAIL', message: 'email required' } }, 400);
  }
  try {
    const result = await inviteTeacher(c.env, user.id, body.email.trim());
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'INVITE_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/partner/orders — list all orders by institution */
partnerRoutes.get('/orders', async (c) => {
  const user = getAuthedUser(c);
  try {
    const { listOrders } = await import('../services/orders');
    const orders = await listOrders(c.env, user.id);
    return c.json({ orders });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
  return c.json({ orders: [] });
});