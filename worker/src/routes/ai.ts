import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { searchDocuments } from '../services/rag-search';
import { generateMaterial, generateMindMapRecipe, generateNode, agentChat } from '../services/ai-generation';
import type { NodeType, AgentType } from '../services/ai-generation';
import { ingestSource, assembleContext } from '../services/content-ingestion';
import type { IngestSourceInput, SourceType } from '../services/content-ingestion';
import { checkQuota, getQuotaStatus } from '../services/quota';
import {
  createGradingEntry,
  getGradingEntry,
  listGradingHistory,
  processGradingEntry,
  processPendingGrading,
} from '../services/grading-queue';
import { evaluateSpeaking } from '../services/speaking-bridge';

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

/** POST /api/ai/grade-speaking — evaluate speaking recording via EduBot bridge (Task 7.1) */
aiRoutes.post('/grade-speaking', async (c) => {
  const user = getAuthedUser(c);
  let body: { audio_url?: string; examType?: string; prompt?: string; level?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.audio_url?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'audio_url required' } }, 400);
  }
  // Check speaking quota (Task 7.4)
  try { await checkQuota(c.env, user.id, user.role, 'speaking'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }
  try {
    const result = await evaluateSpeaking(c.env, {
      audioUrl: body.audio_url,
      examType: body.examType,
      prompt: body.prompt,
      level: body.level,
    });
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Speaking evaluation failed';
    return c.json({ error: { code: 'SPEAKING_FAILED', message } }, 500);
  }
});

/** POST /api/ai/mind-map-recipe — teacher dumps topic + notes, AI generates a workbook unit
 *  with theory, examples, exercises, vocabulary, and a practice prompt.
 *  Inspired by remalt.com's "dump ideas → AI generates structured content" pattern.
 *  Returns the recipe + an ai_generated_content payload suitable for syllabus_items. */
aiRoutes.post('/mind-map-recipe', async (c) => {
  const user = getAuthedUser(c);
  let body: { topic?: string; notes?: string; exam?: string; level?: string; item_type?: string; estimated_minutes?: number };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.topic?.trim() || !body.notes?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'topic and notes required' } }, 400);
  }
  // Check generation quota
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
    return c.json({ error: { code: 'QUOTA_CHECK_FAILED', message: (err as Error).message } }, 500);
  }
  try {
    const recipe = await generateMindMapRecipe(c.env, {
      topic: body.topic,
      notes: body.notes,
      exam: body.exam,
      level: body.level,
      item_type: body.item_type,
      estimated_minutes: body.estimated_minutes,
    });
    console.log(`mind-map-recipe user=${user.id} topic=${body.topic}`);
    return c.json(recipe);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Recipe generation failed';
    return c.json({ error: { code: 'RECIPE_FAILED', message } }, 500);
  }
});

/** POST /api/ai/ingest-source — extract text from YouTube/URL/PDF/text source
 *  Body: { type: 'youtube'|'url'|'pdf'|'text', url?, content?, filename? }
 *  Returns: { type, title, text, source_url, metadata } */
aiRoutes.post('/ingest-source', async (c) => {
  const user = getAuthedUser(c);
  let body: IngestSourceInput;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const validTypes: SourceType[] = ['youtube', 'url', 'pdf', 'text'];
  if (!body.type || !validTypes.includes(body.type)) {
    return c.json({ error: { code: 'INVALID_TYPE', message: `type must be one of: ${validTypes.join(', ')}` } }, 400);
  }
  try {
    const result = await ingestSource(c.env, body);
    console.log(`ingest-source user=${user.id} type=${body.type} title=${result.title} chars=${result.text.length}`);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Ingestion failed';
    return c.json({ error: { code: 'INGEST_FAILED', message } }, 400);
  }
});

/** POST /api/ai/mind-map-node — generate a single output node (remalt-style multi-node)
 *  Body: { type: 'theory'|'exercises'|'vocabulary'|'practice'|'examples', topic, notes, exam, level, item_type, context?, sources? }
 *  sources: array of { type, title, text } from previously ingested content
 *  Returns the node's content as JSON. */
aiRoutes.post('/mind-map-node', async (c) => {
  const user = getAuthedUser(c);
  let body: { type?: string; topic?: string; notes?: string; exam?: string; level?: string; item_type?: string; context?: string; sources?: Array<{ type: string; title: string; text: string }> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const validTypes: NodeType[] = ['theory', 'exercises', 'vocabulary', 'practice', 'examples'];
  if (!body.type || !validTypes.includes(body.type as NodeType)) {
    return c.json({ error: { code: 'INVALID_TYPE', message: `type must be one of: ${validTypes.join(', ')}` } }, 400);
  }
  if (!body.topic?.trim() || !body.notes?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'topic and notes required' } }, 400);
  }
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
  }
  try {
    // Assemble context from explicit context + ingested sources
    const sourceContext = body.sources ? assembleContext(body.sources.map((s) => ({ type: s.type as SourceType, title: s.title, text: s.text, metadata: {} }))) : '';
    const fullContext = [body.context ?? '', sourceContext].filter(Boolean).join('\n\n');
    const content = await generateNode(c.env, body.type as NodeType, {
      topic: body.topic,
      notes: body.notes,
      exam: body.exam,
      level: body.level,
      item_type: body.item_type,
      context: fullContext || undefined,
    });
    console.log(`mind-map-node user=${user.id} type=${body.type} topic=${body.topic} sources=${body.sources?.length ?? 0}`);
    return c.json({ type: body.type, content });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Node generation failed';
    return c.json({ error: { code: 'NODE_FAILED', message } }, 500);
  }
});

/** POST /api/ai/agent-chat — specialist agent refines material via conversation
 *  Body: { agent: 'reading'|'speaking'|'writing'|'general', message, context, topic, exam?, level?, history? }
 *  Returns { reply: string } */
aiRoutes.post('/agent-chat', async (c) => {
  const user = getAuthedUser(c);
  let body: { agent?: string; message?: string; context?: string; topic?: string; exam?: string; level?: string; history?: Array<{ role: string; content: string }>; sources?: Array<{ type: string; title: string; text: string }> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const validAgents: AgentType[] = ['reading', 'speaking', 'writing', 'general'];
  if (!body.agent || !validAgents.includes(body.agent as AgentType)) {
    return c.json({ error: { code: 'INVALID_AGENT', message: `agent must be one of: ${validAgents.join(', ')}` } }, 400);
  }
  if (!body.message?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'message required' } }, 400);
  }
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
  }
  try {
    const sourceContext = body.sources ? assembleContext(body.sources.map((s) => ({ type: s.type as SourceType, title: s.title, text: s.text, metadata: {} }))) : '';
    const fullContext = [body.context ?? '', sourceContext].filter(Boolean).join('\n\n');
    const result = await agentChat(c.env, {
      agent: body.agent as AgentType,
      message: body.message,
      context: fullContext,
      topic: body.topic ?? '',
      exam: body.exam,
      level: body.level,
      history: (body.history ?? []) as Array<{ role: 'user' | 'assistant'; content: string }>,
    });
    console.log(`agent-chat user=${user.id} agent=${body.agent}`);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Agent chat failed';
    return c.json({ error: { code: 'CHAT_FAILED', message } }, 500);
  }
});