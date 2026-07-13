import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getAmbassadorStats, generateProposalHtml } from '../services/ambassador';

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

/** GET /api/ambassador/proposal — printable HTML teacher proposal document (Task 17.3) */
ambassadorRoutes.get('/proposal', async (c) => {
  const user = getAuthedUser(c);
  try {
    const { html, filename } = await generateProposalHtml(c.env, user.id);
    c.header('Content-Type', 'text/html; charset=utf-8');
    c.header('Content-Disposition', `inline; filename="${filename}"`);
    return c.body(html);
  } catch (err) {
    return c.json({ error: { code: 'PROPOSAL_FAILED', message: (err as Error).message } }, 500);
  }
});