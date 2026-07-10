/**
 * Viral metrics routes — T40 (Wave 5).
 *
 * GET /api/viral/metrics         — admin only: growth dashboard
 * GET /api/viral/metrics/me      — auth: my personal viral metrics
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getViralMetrics } from '../services/viral-metrics';
import { getSupabase } from '../services/supabase';

export const viralMetricsRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

viralMetricsRoutes.use('*', requireAuth());

/** GET /api/viral/metrics — admin. */
viralMetricsRoutes.get('/metrics', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  const days = parseInt(c.req.query('days') ?? '30', 10);
  try {
    const metrics = await getViralMetrics(c.env, days);
    return c.json(metrics);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Metrics failed';
    return c.json({ error: { code: 'METRICS_FAILED', message } }, 500);
  }
});

/** GET /api/viral/metrics/me — my personal metrics. */
viralMetricsRoutes.get('/metrics/me', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  const { count: myShares } = await supabase
    .from('viral_share_events')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id);

  const { count: myConversions } = await supabase
    .from('referrals')
    .select('id', { count: 'exact', head: true })
    .eq('referrer_id', user.id)
    .in('status', ['signed_up', 'converted']);

  const { calculateReferralReward } = await import('../services/viral');
  return c.json({
    total_shares: myShares ?? 0,
    total_conversions: myConversions ?? 0,
    estimated_reward_idr: calculateReferralReward(myConversions ?? 0),
  });
});