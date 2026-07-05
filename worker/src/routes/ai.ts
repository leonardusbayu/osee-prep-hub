import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { searchDocuments } from '../services/rag-search';
import { gradeWriting } from '../services/ai-grading';
import { checkQuota, getQuotaStatus } from '../services/quota';

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

  try {
    const results = await searchDocuments(c.env, body.query, {
      matchCount: body.match_count ?? 10,
      filter: body.filter,
    });
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

/** POST /api/ai/grade-writing — grade an essay (Task 5.1) */
aiRoutes.post('/grade-writing', async (c) => {
  const user = getAuthedUser(c);

  let body: { essay?: string; rubric?: string; examType?: string; level?: string };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }

  if (!body.essay || !body.rubric || !body.examType) {
    return c.json(
      { error: { code: 'INVALID_INPUT', message: 'essay, rubric, and examType required' } },
      400
    );
  }

  // Check quota
  try {
    const quota = await checkQuota(c.env, user.id, user.role, 'grading');
    void quota; // quota check passed — if exceeded, checkQuota throws
  } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json(
        { error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } },
        429
      );
    }
    const message = err instanceof Error ? err.message : 'Quota check failed';
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message } }, 500);
  }

  try {
    const result = await gradeWriting(c.env, {
      essay: body.essay,
      rubric: body.rubric,
      examType: body.examType,
      level: body.level,
    });
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Grading failed';
    return c.json({ error: { code: 'GRADING_FAILED', message } }, 500);
  }
});

/** GET /api/ai/quota — get current user's quota status */
aiRoutes.get('/quota', async (c) => {
  const user = getAuthedUser(c);
  try {
    const grading = await getQuotaStatus(c.env, user.id, user.role, 'grading');
    const generation = await getQuotaStatus(c.env, user.id, user.role, 'generation');
    const speaking = await getQuotaStatus(c.env, user.id, user.role, 'speaking');
    return c.json({ grading, generation, speaking });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Failed to fetch quota';
    return c.json({ error: { code: 'QUOTA_FETCH_FAILED', message } }, 500);
  }
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