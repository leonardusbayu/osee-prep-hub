/**
 * OSEE Agent Runtime — Task 1 (Wave 1).
 *
 * Core abstractions for the agent system that later waves build on:
 * - AgentDefinition: declarative agent spec (name, prompt, tools, model)
 * - AgentContext: per-invocation state (user, session, history, retrievers)
 * - ToolBus: registry + executor for tools the agent can call
 * - AgentRunner: executes one turn (system prompt + history + input → LLM → tool calls → final response)
 *
 * Design choices (per plan Must NOT do):
 * - No fine-tuning. No streaming (batch JSON only). No agent-to-agent communication in Wave 1.
 *
 * The runner uses OpenAI Chat Completions with response_format=json_object so the
 * model returns a structured {response, toolCalls} envelope. Tool calls are executed
 * sequentially (max 4 per turn) and results fed back into the final response.
 */

import type { Env } from '../types';

const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';

// ============================================================
// Types
// ============================================================

export type AgentModel = 'gpt-4o-mini' | 'gpt-4o';

export interface AgentDefinition {
  name: string;
  systemPrompt: string;
  tools: string[];
  model: AgentModel;
  temperature: number;
}

export interface ChatMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
}

export interface AgentContext {
  userId: string;
  sessionId: string;
  history: ChatMessage[];
  ragRetriever?: (query: string, topK: number) => Promise<unknown[]>;
}

export interface ToolCall {
  name: string;
  args: Record<string, unknown>;
  result?: unknown;
  error?: string;
}

export interface AgentRunResult {
  response: string;
  toolCalls: ToolCall[];
  tokensUsed: number;
}

export type ToolHandler = (
  args: Record<string, unknown>,
  ctx: AgentContext,
  env: Env
) => Promise<unknown>;

// ============================================================
// ToolBus
// ============================================================

export class ToolBus {
  private tools = new Map<string, ToolHandler>();

  register(name: string, handler: ToolHandler): void {
    if (this.tools.has(name)) {
      throw new Error(`Tool already registered: ${name}`);
    }
    this.tools.set(name, handler);
  }

  has(name: string): boolean {
    return this.tools.has(name);
  }

  async execute(
    name: string,
    args: Record<string, unknown>,
    ctx: AgentContext,
    env: Env
  ): Promise<unknown> {
    const handler = this.tools.get(name);
    if (!handler) {
      throw new Error(`Unknown tool: ${name}`);
    }
    return handler(args, ctx, env);
  }

  list(): string[] {
    return Array.from(this.tools.keys());
  }
}

// ============================================================
// AgentRunner
// ============================================================

const MAX_TOOL_CALLS_PER_TURN = 4;

export class AgentRunner {
  constructor(
    private env: Env,
    private def: AgentDefinition,
    private bus: ToolBus
  ) {}

  /**
   * Execute one agent turn.
   * 1. Build messages (system + history + user input + tool schemas)
   * 2. Call LLM with json_object response format
   * 3. Parse {response, toolCalls} envelope
   * 4. Execute each tool call sequentially, collecting results
   * 5. If tool results change the response, do a second LLM pass with tool results
   * 6. Return {response, toolCalls, tokensUsed}
   */
  async run(input: string, ctx: AgentContext): Promise<AgentRunResult> {
    const toolSchemas = this.def.tools.map((name) => {
      // Minimal schema — the system prompt describes each tool's args.
      return `- ${name}(args: object): see system prompt for args`;
    });

    const systemContent = `${this.def.systemPrompt}

You have access to these tools:
${toolSchemas.join('\n')}

When the user's request requires data you don't have, call a tool by returning JSON:
{
  "response": "<intermediate acknowledgment or final answer>",
  "toolCalls": [{"name": "<toolName>", "args": {<args>}}]
}

If you have enough information to answer, return:
{
  "response": "<final answer>",
  "toolCalls": []
}

Always respond in Bahasa Indonesia if the user wrote in Bahasa. Always respond in English if the user wrote in English.`;

    const messages: ChatMessage[] = [
      { role: 'system', content: systemContent },
      ...ctx.history.slice(-10), // keep last 10 turns for context window budget
      { role: 'user', content: input },
    ];

    let tokensUsed = 0;
    const executedCalls: ToolCall[] = [];

    // First pass
    const firstPass = await this.callLlm(messages);
    tokensUsed += firstPass.tokens;

    let { response, toolCalls } = firstPass.envelope;

    // Execute tool calls (cap at MAX_TOOL_CALLS_PER_TURN)
    const callsToExecute = (toolCalls ?? []).slice(0, MAX_TOOL_CALLS_PER_TURN);
    const toolResults: ChatMessage[] = [];

    for (const call of callsToExecute) {
      if (!this.def.tools.includes(call.name)) {
        executedCalls.push({
          name: call.name,
          args: call.args ?? {},
          error: `Tool not available to this agent: ${call.name}`,
        });
        continue;
      }
      if (!this.bus.has(call.name)) {
        executedCalls.push({
          name: call.name,
          args: call.args ?? {},
          error: `Tool not registered: ${call.name}`,
        });
        continue;
      }
      try {
        const result = await this.bus.execute(call.name, call.args ?? {}, ctx, this.env);
        executedCalls.push({ name: call.name, args: call.args ?? {}, result });
        toolResults.push({
          role: 'tool',
          content: `${call.name} returned: ${JSON.stringify(result).slice(0, 2000)}`,
        });
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Tool execution failed';
        executedCalls.push({ name: call.name, args: call.args ?? {}, error: message });
        toolResults.push({
          role: 'tool',
          content: `${call.name} failed: ${message}`,
        });
      }
    }

    // If tools were called and we have results, do a second pass to synthesize final response
    if (toolResults.length > 0) {
      messages.push(
        { role: 'assistant', content: JSON.stringify(firstPass.envelope) },
        ...toolResults,
        {
          role: 'user',
          content: 'Now use the tool results to produce your final response. Return the same JSON envelope: {"response": "<final answer>", "toolCalls": []}',
        }
      );
      const secondPass = await this.callLlm(messages);
      tokensUsed += secondPass.tokens;
      response = secondPass.envelope.response;
    }

    return { response, toolCalls: executedCalls, tokensUsed };
  }

  private async callLlm(
    messages: ChatMessage[]
  ): Promise<{ envelope: { response: string; toolCalls: ToolCall[] }; tokens: number }> {
    const completion = await fetch(OPENAI_CHAT_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${this.env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: this.def.model,
        messages,
        temperature: this.def.temperature,
        max_tokens: 1200,
        response_format: { type: 'json_object' },
      }),
    });

    if (!completion.ok) {
      const errText = await completion.text();
      throw new Error(`OpenAI API error ${completion.status}: ${errText}`);
    }

    const json = (await completion.json()) as {
      choices: Array<{ message: { content: string } }>;
      usage: { total_tokens: number };
    };

    if (!json.choices?.[0]) {
      throw new Error('OpenAI returned no choices');
    }

    let envelope: { response: string; toolCalls: ToolCall[] };
    try {
      envelope = JSON.parse(json.choices[0].message.content);
    } catch {
      // If the model didn't return valid JSON, treat the content as the response.
      envelope = { response: json.choices[0].message.content, toolCalls: [] };
    }

    return { envelope, tokens: json.usage?.total_tokens ?? 0 };
  }
}