import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { setPrice, listAllPricing } from '../services/pricing';
import { getSupabase } from '../services/supabase';

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
  try {
    const supabase = getSupabase(c.env);
    const [
      users,
      teachers,
      revenue,
      commissionPaid,
      aiUsage,
    ] = await Promise.all([
      supabase.from('unified_profiles').select('id', { count: 'exact', head: true }),
      supabase
        .from('unified_profiles')
        .select('id', { count: 'exact', head: true })
        .eq('role', 'teacher'),
      supabase
        .from('orders')
        .select('total_amount')
        .in('status', ['paid', 'fulfilled']),
      supabase
        .from('commission_ledger')
        .select('amount_idr')
        .eq('status', 'paid'),
      supabase
        .from('ai_quota_usage')
        .select('used_count'),
    ]);

    const totalRevenue = (revenue.data ?? []).reduce(
      (sum, row) => sum + Number((row as { total_amount?: number }).total_amount ?? 0),
      0
    );
    const totalCommissionPaid = (commissionPaid.data ?? []).reduce(
      (sum, row) => sum + Number((row as { amount_idr?: number }).amount_idr ?? 0),
      0
    );
    const totalAiUsage = (aiUsage.data ?? []).reduce(
      (sum, row) => sum + Number((row as { used_count?: number }).used_count ?? 0),
      0
    );

    return c.json({
      total_users: users.count ?? 0,
      active_teachers: teachers.count ?? 0,
      total_revenue: totalRevenue,
      commission_paid: totalCommissionPaid,
      ai_usage: totalAiUsage,
    });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/users — list recent users */
adminRoutes.get('/users', async (c) => {
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('unified_profiles')
      .select('id,email,display_name,role,created_at')
      .order('created_at', { ascending: false })
      .limit(100);
    if (error) throw error;
    return c.json({ users: data ?? [] });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});
