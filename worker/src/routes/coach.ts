/**
 * Coach routes — T10 (Wave 2).
 *
 * POST /api/coach/sessions                  — start a new coach session
 * GET  /api/coach/sessions/:id              — get session + messages
 * GET  /api/coach/sessions                  — list recent sessions for user
 * POST /api/coach/sessions/:id/messages     — send a message to the tutor agent
 *
 * The Coach is the tutor agent with session + history persistence.
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import { getSupabase } from '../services/supabase';
import { getAgent } from '../agents';
import { AgentRunner, ToolBus, type AgentContext, type ChatMessage } from '../agents/runtime';
import {
  registerBuiltinTools,
  searchCatalogTool,
  createPracticeQuestionTool,
  fetchGradingHistoryTool,
} from '../agents/tools';
import { traceMiddleware } from '../agents/tracing';

export const coachRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

coachRoutes.use('*', requireAuth());
coachRoutes.use('*', rateLimit('coach-send'));

/** POST /api/coach/sessions — start a new session. */
coachRoutes.post('/sessions', async (c) => {
  const user = getAuthedUser(c);
  let body: { syllabusId?: string };
  try { body = await c.req.json(); } catch { body = {}; }

  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('coach_sessions')
    .insert({
      student_id: user.id,
      syllabus_id: body.syllabusId ?? null,
      agent_name: 'tutor',
    })
    .select()
    .single();
  if (error || !data) {
    return c.json({ error: { code: 'CREATE_FAILED', message: error?.message ?? 'No row' } }, 500);
  }
  return c.json({ session: data }, 201);
});

/** GET /api/coach/sessions — list current user's recent sessions. */
coachRoutes.get('/sessions', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('coach_sessions')
    .select('id, syllabus_id, agent_name, started_at, ended_at')
    .eq('student_id', user.id)
    .order('started_at', { ascending: false })
    .limit(20);
  if (error) {
    return c.json({ error: { code: 'LIST_FAILED', message: error.message } }, 500);
  }
  return c.json({ sessions: data ?? [] });
});

/** GET /api/coach/sessions/:id — get session + messages. */
coachRoutes.get('/sessions/:id', async (c) => {
  const user = getAuthedUser(c);
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);

  const supabase = getSupabase(c.env);
  const { data: session } = await supabase
    .from('coach_sessions')
    .select('*')
    .eq('id', id)
    .eq('student_id', user.id)
    .single();
  if (!session) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Session not found' } }, 404);
  }
  const { data: messages } = await supabase
    .from('coach_messages')
    .select('*')
    .eq('session_id', id)
    .order('created_at', { ascending: true });

  return c.json({ session, messages: messages ?? [] });
});

/** POST /api/coach/sessions/:id/messages — send a message, get tutor response. */
coachRoutes.post('/sessions/:id/messages', async (c) => {
  const user = getAuthedUser(c);
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);

  let body: { content?: string; clientId?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.content || body.content.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'content required' } }, 400);
  }
  if (body.content.length > 4000) {
    return c.json({ error: { code: 'INPUT_TOO_LONG', message: 'content must be <= 4000 chars' } }, 400);
  }

  const supabase = getSupabase(c.env);
  // Verify session ownership.
  const { data: session } = await supabase
    .from('coach_sessions')
    .select('*')
    .eq('id', id)
    .eq('student_id', user.id)
    .single();
  if (!session) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Session not found' } }, 404);
  }

  // Load prior messages (last 10) for context.
  const { data: prior } = await supabase
    .from('coach_messages')
    .select('role, content')
    .eq('session_id', id)
    .order('created_at', { ascending: true })
    .limit(20);
  const history: ChatMessage[] = (prior ?? []).map((m: any) => ({
    role: m.role,
    content: m.content,
  }));

  // Save user message.
  await supabase.from('coach_messages').insert({
    session_id: id,
    role: 'user',
    content: body.content,
    metadata: { client_id: body.clientId },
  });

  // Invoke tutor agent.
  const def = getAgent('tutor');
  const ctx: AgentContext = {
    userId: user.id,
    sessionId: id,
    history,
  };
  const bus = new ToolBus();
  registerBuiltinTools(bus, ctx);
  bus.register('search_catalog', searchCatalogTool);
  bus.register('create_practice_question', createPracticeQuestionTool);
  bus.register('fetch_grading_history', fetchGradingHistoryTool);

  const runner = new AgentRunner(c.env, def, bus);
  const traced = traceMiddleware(c.env, runner, ctx);

  try {
    const result = await traced.run(body.content);

    // Save assistant response.
    await supabase.from('coach_messages').insert({
      session_id: id,
      role: 'assistant',
      content: result.response,
      tool_calls: result.toolCalls,
    });

    return c.json({
      response: result.response,
      toolCalls: result.toolCalls,
      tokensUsed: result.tokensUsed,
      clientId: body.clientId, // echo for offline-sync dedup
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Coach failed';
    // Save error as system message for debugging.
    await supabase.from('coach_messages').insert({
      session_id: id,
      role: 'system',
      content: `Error: ${message}`,
      metadata: { error: true },
    });
    return c.json({ error: { code: 'COACH_FAILED', message } }, 500);
  }
});

/** POST /api/coach/sessions/:id/sync — T24 offline-sync batch upload.
 *  Accepts an array of queued messages (when device was offline).
 *  Each message has a clientId for dedup. Returns assistant responses
 *  in the same order. */
coachRoutes.post('/sessions/:id/sync', async (c) => {
  const user = getAuthedUser(c);
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);

  let body: { messages?: Array<{ content: string; clientId: string }> };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.messages || body.messages.length === 0) {
    return c.json({ results: [] });
  }

  const supabase = getSupabase(c.env);
  // Verify session.
  const { data: session } = await supabase
    .from('coach_sessions')
    .select('id')
    .eq('id', id)
    .eq('student_id', user.id)
    .single();
  if (!session) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Session not found' } }, 404);
  }

  const results: Array<{ clientId: string; response?: string; error?: string }> = [];
  for (const msg of body.messages) {
    // Dedup: skip if already saved (by client_id metadata).
    const { data: existing } = await supabase
      .from('coach_messages')
      .select('id')
      .eq('session_id', id)
      .eq('metadata->>client_id', msg.clientId)
      .maybeSingle();
    if (existing) {
      results.push({ clientId: msg.clientId, response: '(duplicate — already processed)' });
      continue;
    }

    await supabase.from('coach_messages').insert({
      session_id: id,
      role: 'user',
      content: msg.content,
      metadata: { client_id: msg.clientId },
    });

    // Run agent.
    try {
      const def = getAgent('tutor');
      const ctx: AgentContext = { userId: user.id, sessionId: id, history: [] };
      const bus = new ToolBus();
      registerBuiltinTools(bus, ctx);
      bus.register('search_catalog', searchCatalogTool);
      bus.register('create_practice_question', createPracticeQuestionTool);
      bus.register('fetch_grading_history', fetchGradingHistoryTool);
      const runner = new AgentRunner(c.env, def, bus);
      const traced = traceMiddleware(c.env, runner, ctx);
      const result = await traced.run(msg.content);
      await supabase.from('coach_messages').insert({
        session_id: id,
        role: 'assistant',
        content: result.response,
        tool_calls: result.toolCalls,
      });
      results.push({ clientId: msg.clientId, response: result.response });
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed';
      results.push({ clientId: msg.clientId, error: message });
    }
  }
  return c.json({ results });
});