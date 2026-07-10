/**
 * Agent routes — Task 1 (Wave 1).
 *
 * POST /api/agents/:agentName/invoke — invoke an agent with input text.
 *   Auth: any authenticated user. Rate-limited (20/min free, 200/min pro).
 *   Body: { input: string, sessionId?: string }
 *   Returns: { response: string, toolCalls: ToolCall[], tokensUsed: number }
 *
 * GET /api/agents — list available agents (for client UI).
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { rateLimit } from '../middleware/rate-limit';
import { getAgent, listAgents } from '../agents';
import { AgentRunner, ToolBus, type AgentContext, type ChatMessage } from '../agents/runtime';
import { registerBuiltinTools, searchCatalogTool, createPracticeQuestionTool, fetchGradingHistoryTool, fetchPassportTool, fetchJobMarketTool } from '../agents/tools';

export const agentRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

agentRoutes.use('*', requireAuth());
agentRoutes.use('*', rateLimit('agent-invoke'));

/** GET /api/agents — list available agents. */
agentRoutes.get('/', (c) => {
  return c.json({ agents: listAgents() });
});

/** POST /api/agents/:agentName/invoke */
agentRoutes.post('/:agentName/invoke', async (c) => {
  const user = getAuthedUser(c);
  const agentName = c.req.param('agentName');

  let def;
  try {
    def = getAgent(agentName);
  } catch {
    return c.json({ error: { code: 'AGENT_NOT_FOUND', message: `Unknown agent: ${agentName}` } }, 404);
  }

  let body: { input?: string; sessionId?: string; history?: ChatMessage[] };
  try {
    body = await c.req.json();
  } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.input || body.input.trim().length === 0) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'input required' } }, 400);
  }
  if (body.input.length > 4000) {
    return c.json({ error: { code: 'INPUT_TOO_LONG', message: 'input must be <= 4000 chars' } }, 400);
  }

  const sessionId = body.sessionId ?? crypto.randomUUID();
  const ctx: AgentContext = {
    userId: user.id,
    sessionId,
    history: body.history ?? [],
  };

  // Build tool bus with all built-in tools registered.
  // (We register all tools; the agent definition gates which ones it can call.)
  const bus = new ToolBus();
  registerBuiltinTools(bus, ctx);
  bus.register('search_catalog', searchCatalogTool);
  bus.register('create_practice_question', createPracticeQuestionTool);
  bus.register('fetch_grading_history', fetchGradingHistoryTool);
  bus.register('fetch_passport', fetchPassportTool);
  bus.register('fetch_job_market', fetchJobMarketTool);

  try {
    const runner = new AgentRunner(c.env, def, bus);
    const result = await runner.run(body.input, ctx);
    return c.json({ ...result, sessionId });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Agent invocation failed';
    console.error(`agent-invoke agent=${agentName} user=${user.id} error=${message}`);
    return c.json({ error: { code: 'AGENT_FAILED', message } }, 500);
  }
});