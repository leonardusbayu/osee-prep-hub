/**
 * Insight routes — T13 (Wave 2).
 *
 * GET /api/insight/stats              — institution-wide aggregate stats
 * GET /api/insight/cohort-heatmap     — students × weeks completion matrix
 * GET /api/insight/teacher-effectiveness — teacher metrics
 *
 * Auth: admin only (institutions in Phase 2).
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  getInstitutionStats,
  getCohortHeatmap,
  getTeacherEffectiveness,
} from '../services/insight';

export const insightRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

insightRoutes.use('*', requireAuth());

/** GET /api/insight/stats */
insightRoutes.get('/stats', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  try {
    const stats = await getInstitutionStats(c.env);
    return c.json(stats);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Stats failed';
    return c.json({ error: { code: 'STATS_FAILED', message } }, 500);
  }
});

/** GET /api/insight/cohort-heatmap?classroomId=&limit= */
insightRoutes.get('/cohort-heatmap', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  const classroomId = c.req.query('classroomId');
  const limit = parseInt(c.req.query('limit') ?? '30', 10);
  try {
    const rows = await getCohortHeatmap(c.env, classroomId, limit);
    return c.json({ rows });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Heatmap failed';
    return c.json({ error: { code: 'HEATMAP_FAILED', message } }, 500);
  }
});

/** GET /api/insight/teacher-effectiveness?limit= */
insightRoutes.get('/teacher-effectiveness', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin only' } }, 403);
  }
  const limit = parseInt(c.req.query('limit') ?? '50', 10);
  try {
    const teachers = await getTeacherEffectiveness(c.env, limit);
    return c.json({ teachers });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Effectiveness failed';
    return c.json({ error: { code: 'EFFECTIVENESS_FAILED', message } }, 500);
  }
});