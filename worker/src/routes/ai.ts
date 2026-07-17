import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { searchDocuments } from '../services/rag-search';
import { generateMaterial, generateMindMapRecipe, generateNode, agentChat, generateImage } from '../services/ai-generation';
import type { NodeType, AgentType, ImageType } from '../services/ai-generation';
import { ingestSource, assembleContext } from '../services/content-ingestion';
import type { IngestSourceInput, SourceType } from '../services/content-ingestion';
import { batchIngest, searchKnowledge, assembleKnowledgeContext } from '../services/knowledge-cluster';
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

/** POST /api/ai/rag/search — vector search over knowledge base (Blueprint line 1376).
 *  Alias at /rag-search kept for backward compatibility. */
async function handleRagSearch(c: import('hono').Context<{ Bindings: Env; Variables: ContextVars }>): Promise<Response> {
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
}

aiRoutes.post('/rag/search', handleRagSearch);
aiRoutes.post('/rag-search', handleRagSearch); // backward-compat alias

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
    // Process inline for low latency (the OpenAI grading call is fast enough
    // to await). On failure the entry stays 'processing' and the cron worker
    // retries it — the client gets a 202 + can poll /grading/:id.
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

/** GET /api/ai/generation/:id — poll generation job status + result (blueprint line 1373) */
aiRoutes.get('/generation/:id', async (c) => {
  const user = getAuthedUser(c);
  const supabase = (await import('../services/supabase')).getSupabase(c.env);
  const { data, error } = await supabase
    .from('ai_generation_queue')
    .select('*')
    .eq('id', c.req.param('id'))
    .eq('user_id', user.id)
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Generation job not found' } }, 404);
  }
  return c.json(data);
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
    // Insert generation job into ai_generation_queue (Task 6.2)
    const { getSupabase } = await import('../services/supabase');
    const supabase = getSupabase(c.env);
    const { data: queueRow } = await supabase
      .from('ai_generation_queue')
      .insert({
        teacher_id: user.id,
        user_id: user.id,
        generation_type: body.type,
        exam_type: body.exam,
        cefr_level: body.level,
        topic: body.topic,
        status: 'processing',
        processing_started_at: new Date().toISOString(),
      })
      .select()
      .single();
    const jobId = (queueRow as Record<string, unknown>)?.id as string | undefined;

    const result = await generateMaterial(c.env, {
      type: body.type as 'reading' | 'listening' | 'speaking' | 'writing' | 'grammar' | 'vocabulary' | 'mock_test',
      exam: body.exam, level: body.level, topic: body.topic, options: body.options,
    });

    // Update queue row with result
    if (jobId) {
      await supabase
        .from('ai_generation_queue')
        .update({
          status: 'completed',
          generated_content: result,
          completed_at: new Date().toISOString(),
        })
        .eq('id', jobId);
    }

    console.log(`generate-material user=${user.id} type=${body.type} topic=${body.topic}`);
    return c.json({ ...result, job_id: jobId });
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

/** POST /api/ai/batch-ingest — ingest multiple sources at once, auto-embed into RAG
 *  Body: { sources: [{ type, url?, content?, filename? }], cluster_label? }
 *  Returns: { ingested: [...], embedded_count, cluster_id?, errors: [...] } */
aiRoutes.post('/batch-ingest', async (c) => {
  const user = getAuthedUser(c);
  let body: { sources?: IngestSourceInput[]; cluster_label?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.sources || !Array.isArray(body.sources) || body.sources.length === 0) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'sources array required' } }, 400);
  }
  if (body.sources.length > 50) {
    return c.json({ error: { code: 'TOO_MANY', message: 'Max 50 sources per batch' } }, 400);
  }
  try {
    const result = await batchIngest(c.env, {
      sources: body.sources,
      cluster_label: body.cluster_label,
      teacher_id: user.id,
    });
    console.log(`batch-ingest user=${user.id} sources=${body.sources.length} ingested=${result.ingested.length} embedded=${result.embedded_count} errors=${result.errors.length}`);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Batch ingest failed';
    return c.json({ error: { code: 'BATCH_FAILED', message } }, 500);
  }
});

/** POST /api/ai/knowledge-search — RAG search across all teacher's ingested sources
 *  Body: { query, cluster_id? }
 *  Returns: { results: [{ chunk_text, source_title, source_type, similarity }] } */
aiRoutes.post('/knowledge-search', async (c) => {
  const user = getAuthedUser(c);
  let body: { query?: string; cluster_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.query?.trim()) {
    return c.json({ error: { code: 'INVALID_QUERY', message: 'query required' } }, 400);
  }
  try {
    const results = await searchKnowledge(c.env, body.query, user.id, {
      clusterId: body.cluster_id,
      matchCount: 10,
    });
    console.log(`knowledge-search user=${user.id} query="${body.query.substring(0, 50)}" results=${results.length}`);
    return c.json({ results, count: results.length });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Search failed';
    return c.json({ error: { code: 'SEARCH_FAILED', message } }, 500);
  }
});

/** POST /api/ai/mind-map-node — generate a single output node (remalt-style multi-node)
 *  Body: { type: 'theory'|'exercises'|'vocabulary'|'practice'|'examples', topic, notes, exam, level, item_type, context?, sources?, use_rag?, difficulty?, kp_tags?, linked_nodes? }
 *  sources: array of { type, title, text } from previously ingested content (raw context)
 *  use_rag: if true, searches the teacher's knowledge base via RAG for relevant chunks
 *  difficulty: 'easy'|'medium'|'hard'|'expert' — adjusts generated content difficulty
 *  kp_tags: array of { code, label } — Kurikulum Merdeka competency tags to align to
 *  linked_nodes: array of { nodeId, type, title, content } — upstream node outputs for edge-aware pipeline
 *  Returns the node's content as JSON. */
aiRoutes.post('/mind-map-node', async (c) => {
  const user = getAuthedUser(c);
  let body: { type?: string; topic?: string; notes?: string; exam?: string; level?: string; item_type?: string; context?: string; sources?: Array<{ type: string; title: string; text: string }>; use_rag?: boolean; difficulty?: string; kp_tags?: Array<{ code: string; label: string }>; linked_nodes?: Array<{ nodeId: string; type: string; title: string; content: Record<string, unknown> }> };
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
    // Assemble context from multiple sources:
    // 1. RAG search across teacher's knowledge base (if use_rag is true)
    let ragContext = '';
    if (body.use_rag !== false) {
      try {
        const ragQuery = `${body.topic} ${body.notes} ${body.exam ?? ''} ${body.level ?? ''} ${body.item_type ?? ''}`;
        const ragResults = await searchKnowledge(c.env, ragQuery, user.id, { matchCount: 8 });
        ragContext = assembleKnowledgeContext(ragResults);
      } catch (e) {
        console.error('RAG search failed (non-fatal, falling back to raw sources):', e);
      }
    }
    // 2. Raw source context (passed directly from the canvas)
    const sourceContext = body.sources ? assembleContext(body.sources.map((s) => ({ type: s.type as SourceType, title: s.title, text: s.text, metadata: {} }))) : '';
    // 3. Explicit context from upstream nodes
    const explicitContext = body.context ?? '';
    // Combine all context sources
    const fullContext = [explicitContext, ragContext, sourceContext].filter(Boolean).join('\n\n---\n\n');
    const content = await generateNode(c.env, body.type as NodeType, {
      topic: body.topic,
      notes: body.notes,
      exam: body.exam,
      level: body.level,
      item_type: body.item_type,
      context: fullContext || undefined,
      difficulty: body.difficulty,
      kp_tags: body.kp_tags,
      linked_nodes: body.linked_nodes,
    });
    console.log(`mind-map-node user=${user.id} type=${body.type} topic=${body.topic} sources=${body.sources?.length ?? 0} difficulty=${body.difficulty ?? 'medium'} linked=${body.linked_nodes?.length ?? 0}`);
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

/** POST /api/ai/generate-image — DALL-E 3 lesson image generation
 *  Body: { type: 'cover'|'illustration'|'infographic'|'vocabulary'|'icon'|'scene', topic, description?, exam?, level?, size?, style? }
 *  Returns: { type, url, revised_prompt, size, metadata }
 *  Note: url expires in ~1hr — the teacher should save it locally. */
aiRoutes.post('/generate-image', async (c) => {
  const user = getAuthedUser(c);
  let body: { type?: string; topic?: string; description?: string; exam?: string; level?: string; size?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  const validTypes: ImageType[] = ['illustration', 'cover', 'infographic', 'vocabulary', 'icon', 'scene'];
  if (!body.type || !validTypes.includes(body.type as ImageType)) {
    return c.json({ error: { code: 'INVALID_TYPE', message: `type must be one of: ${validTypes.join(', ')}` } }, 400);
  }
  if (!body.topic?.trim()) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'topic required' } }, 400);
  }
  try { await checkQuota(c.env, user.id, user.role, 'generation'); } catch (err) {
    if ((err as Error & { code?: string }).code === 'QUOTA_EXCEEDED') {
      return c.json({ error: { code: 'QUOTA_EXCEEDED', message: (err as Error).message } }, 429);
    }
  }
  try {
    const result = await generateImage(c.env, {
      type: body.type as ImageType,
      topic: body.topic,
      description: body.description,
      exam: body.exam,
      level: body.level,
      size: body.size as '1024x1024' | '1024x1792' | '1792x1024' | undefined,
    });
    console.log(`generate-image user=${user.id} type=${body.type} topic=${body.topic}`);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Image generation failed';
    console.error(`generate-image error for user=${user.id}:`, message);
    return c.json({ error: { code: 'IMAGE_FAILED', message } }, 500);
  }
});

/** POST /api/ai/rag/upload — teacher uploads custom material to knowledge base */
aiRoutes.post('/rag/upload', async (c) => {
  const user = getAuthedUser(c);
  let body: {
    title?: string;
    source?: string;
    category?: string;
    content?: string;
    cefr_level?: string;
    metadata?: Record<string, unknown>;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.title || !body.source || !body.category || !body.content) {
    return c.json(
      { error: { code: 'INVALID_INPUT', message: 'title, source, category, content required' } },
      400
    );
  }

  const { getSupabase } = await import('../services/supabase');
  const supabase = getSupabase(c.env);

  const { data, error } = await supabase
    .from('knowledge_base_documents')
    .insert({
      title: body.title,
      source: body.source,
      category: body.category,
      content: body.content,
      cefr_level: body.cefr_level ?? null,
      metadata: body.metadata ?? {},
      uploaded_by: user.id,
      is_active: true,
    })
    .select()
    .single();
  if (error || !data) {
    return c.json({ error: { code: 'INSERT_FAILED', message: error?.message ?? 'unknown' } }, 500);
  }
  const docId = (data as Record<string, unknown>).id as string;

  // Chunk + embed via OpenAI (best-effort — non-blocking on failure)
  const chunks = chunkText(body.content, 500, 50);
  let embedded = 0;
  for (let i = 0; i < chunks.length; i++) {
    const embedding = await getEmbedding(c.env, chunks[i]);
    if (embedding) {
      const { error: embError } = await supabase.from('knowledge_base_embeddings').insert({
        document_id: docId,
        chunk_index: i,
        chunk_text: chunks[i],
        embedding,
      });
      if (!embError) embedded++;
    }
  }
  await supabase
    .from('knowledge_base_documents')
    .update({ content_chunk_count: chunks.length })
    .eq('id', docId);

  return c.json({ document_id: docId, chunks: chunks.length, embedded, success: true }, 201);
});

// ---------- Helpers ----------

function chunkText(text: string, maxTokens: number, overlap: number): string[] {
  const paragraphs = text.split(/\n\n+/);
  const chunks: string[] = [];
  let current = '';
  for (const para of paragraphs) {
    const estTokens = Math.ceil((current + para).length / 4);
    if (estTokens > maxTokens && current) {
      chunks.push(current);
      const words = current.split(' ');
      current = words.slice(-overlap).join(' ') + '\n\n' + para;
    } else {
      current = current ? current + '\n\n' + para : para;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

async function getEmbedding(env: Env, text: string): Promise<number[] | null> {
  try {
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({ model: 'text-embedding-3-small', input: text }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { data: Array<{ embedding: number[] }> };
    return json.data[0]?.embedding ?? null;
  } catch {
    return null;
  }
}
