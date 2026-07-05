import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { searchDocuments } from '../services/rag-search';

export const aiRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// All AI routes require authentication
aiRoutes.use('*', requireAuth());

/** POST /api/ai/rag-search — vector search over knowledge base */
aiRoutes.post('/rag-search', async (c) => {
  const user = getAuthedUser(c);

  let body: { query?: string; match_count?: number; filter?: Record<string, unknown> };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  if (!body.query || body.query.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_QUERY', message: 'query required' } }, 400);
  }

  // Rate limit: 100 requests/minute per user (simple check via last-request timestamp)
  // TODO: Implement proper rate limiting with KV or Durable Objects
  // For now, rely on OpenAI API rate limits as a backstop

  try {
    const results = await searchDocuments(c.env, body.query, {
      matchCount: body.match_count ?? 10,
      filter: body.filter,
    });

    // Log search for analytics (best-effort, don't fail on log error)
    console.log(`rag-search user=${user.id} query_len=${body.query.length} results=${results.length}`);

    return c.json({
      query: body.query,
      results,
      count: results.length,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Search failed';
    return c.json({ error: { code: 'SEARCH_FAILED', message } }, 500);
  }
});

// ---------- AI grading + generation endpoints (Tasks 5.1, 6.1 — stubs) ----------

/** POST /api/ai/grade-writing — grade an essay (Task 5.1 — stub) */
aiRoutes.post('/grade-writing', async (c) => {
  return c.json({
    error: {
      code: 'NOT_IMPLEMENTED',
      message: 'grade-writing endpoint — implemented in Task 5.1',
    },
  }, 501);
});

/** POST /api/ai/generate-material — generate study material (Task 6.1 — stub) */
aiRoutes.post('/generate-material', async (c) => {
  return c.json({
    error: {
      code: 'NOT_IMPLEMENTED',
      message: 'generate-material endpoint — implemented in Task 6.1',
    },
  }, 501);
});