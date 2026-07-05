import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { searchDocuments } from '../services/rag-search';
import { generateMaterial } from '../services/ai-generation';
import { checkQuota, getQuotaStatus } from '../services/quota';
import {
  createGradingEntry,
  getGradingEntry,
  listGradingHistory,
  processGradingEntry,
  processPendingGrading,
} from '../services/grading-queue';

export const aiRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

aiRoutes.use('*', requireAuth());

/** POST /api/ai/rag-search — vector search over knowledge base */
aiRoutes.post('/rag-search', async (c) => {
  const user = getAuthedUser(c);
  let body: { query?: string; match_count?: number; filter?: Record<string, unknown> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.query || body.query.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_QUERY', message: 'query required' } }, 400);
  }
  try {
    const results = await searchDocuments(c.env, body.query, {
      matchCount: body.match_count ?? 10, filter: body.filter,
    });
    console.log(`rag-search user=${user.id} results=${results.length}`);
    return c.json({ query: body.query, results, count: results.length });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Search failed';
    return c.json({ error: { code: 'SEARCH_FAILED', message } }, 500);
  }
});

/** POST /api/ai/grade-writing — create grading queue entry (async) */
aiRoutes.post('/grade-writing', async (c) => {
  const user = getAuthedUser(c);
  let body: { essay?: string; rubric?: string; examType?: string; level?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.essay || !body.rubric || !body.examType) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'essay, rubric, examType required' } }, 400);
  }
  // Check quota
  try { await checkQuota(c.env, user.id, user.role, 'grading'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }
  // Create queue entry
  try {
    const entryId = await createGradingEntry(c.env, user.id, 'writing', {
      essay: body.essay, rubric: body.rubric, examType: body.examType, level: body.level,
    });
    // Process immediately (in production, this would be a background job)
    // For now, we process inline so the user gets the result right away
    try {
      await processGradingEntry(c.env, entryId);
      const entry = await getGradingEntry(c.env, user.id, entryId);
      return c.json({ queue_id: entryId, status: entry?.status ?? 'processing', result: entry?.result });
    } catch {
      return c.json({ queue_id: entryId, status: 'processing' }, 202);
    }
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Queue failed';
    return c.json({ error: { code: 'QUEUE_FAILED', message } }, 500);
  }
});

/** GET /api/ai/grading/:id — check grading status + result */
aiRoutes.get('/grading/:id', async (c) => {
  const user = getAuthedUser(c);
  const entryId = c.req.param('id');
  try {
    const entry = await getGradingEntry(c.env, user.id, entryId);
    if (!entry) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Entry not found' } }, 404);
    }
    return c.json(entry);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/ai/grading/history — user's grading history */
aiRoutes.get('/grading/history', async (c) => {
  const user = getAuthedUser(c);
  try {
    const history = await listGradingHistory(c.env, user.id, 50);
    return c.json({ history });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/ai/grading/process — process pending grading entries (cron-triggered) */
aiRoutes.post('/grading/process', async (c) => {
  try {
    const result = await processPendingGrading(c.env, 10);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'PROCESSING_FAILED', message: (err as Error).message } }, 500);
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
    return c.json({ error: { code: 'QUOTA_FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/ai/generate-material — generate study material (Task 6.1) */
aiRoutes.post('/generate-material', async (c) => {
  const user = getAuthedUser(c);
  let body: { type?: string; exam?: string; level?: string; topic?: string; options?: { wordCount?: number; questionCount?: number; difficulty?: string } };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.type || !body.exam || !body.level || !body.topic) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'type, exam, level, topic required' } }, 400);
  }
  // Check quota (generation)
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }
  try {
    const result = await generateMaterial(c.env, {
      type: body.type as 'reading' | 'listening' | 'speaking' | 'writing' | 'grammar' | 'vocabulary' | 'mock_test',
      exam: body.exam, level: body.level, topic: body.topic, options: body.options,
    });
    console.log(`generate-material user=${user.id} type=${body.type} topic=${body.topic}`);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Generation failed';
    return c.json({ error: { code: 'GENERATION_FAILED', message } }, 500);
  }
});