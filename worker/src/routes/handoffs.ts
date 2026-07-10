/**
 * Handoff routes — T19, T20, T21, T22 (Wave 3).
 *
 * POST /api/handoffs/syllabus-to-coach/:syllabusId   — T19
 * POST /api/handoffs/purchase-to-studio/:purchaseId  — T21
 * POST /api/handoffs/live-class-start/:liveClassId    — T22
 * (T20 is automatic on passport credential issue)
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  handoffSyllabusToCoach,
  importPurchasedSyllabus,
  notifyCoachOnClassStart,
} from '../services/handoffs';

export const handoffRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

handoffRoutes.use('*', requireAuth());

/** POST /api/handoffs/syllabus-to-coach/:syllabusId — T19. */
handoffRoutes.post('/syllabus-to-coach/:syllabusId', async (c) => {
  const syllabusId = c.req.param('syllabusId');
  if (!syllabusId) return c.json({ error: { code: 'BAD_REQUEST', message: 'syllabusId required' } }, 400);
  try {
    const user = getAuthedUser(c);
    const result = await handoffSyllabusToCoach(c.env, syllabusId, user.id);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Handoff failed';
    return c.json({ error: { code: 'HANDOFF_FAILED', message } }, 500);
  }
});

/** POST /api/handoffs/purchase-to-studio/:purchaseId — T21. */
handoffRoutes.post('/purchase-to-studio/:purchaseId', async (c) => {
  const purchaseId = c.req.param('purchaseId');
  if (!purchaseId) return c.json({ error: { code: 'BAD_REQUEST', message: 'purchaseId required' } }, 400);
  try {
    const result = await importPurchasedSyllabus(c.env, purchaseId);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Import failed';
    return c.json({ error: { code: 'IMPORT_FAILED', message } }, 500);
  }
});

/** POST /api/handoffs/live-class-start/:liveClassId — T22. */
handoffRoutes.post('/live-class-start/:liveClassId', async (c) => {
  const user = getAuthedUser(c);
  const liveClassId = c.req.param('liveClassId');
  if (!liveClassId) return c.json({ error: { code: 'BAD_REQUEST', message: 'liveClassId required' } }, 400);
  try {
    const result = await notifyCoachOnClassStart(c.env, liveClassId, '', user.id);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Notify failed';
    return c.json({ error: { code: 'NOTIFY_FAILED', message } }, 500);
  }
});