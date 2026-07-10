/**
 * Agent runtime tests — Task 1 (Wave 1).
 *
 * Mocks OpenAI API to test runtime logic without real API calls.
 * Tests: ToolBus register/execute, AgentRunner tool-call flow, rate-limit middleware.
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ToolBus, AgentRunner, type AgentDefinition, type AgentContext } from '../agents/runtime';
import { _resetBucketsForTests, rateLimit } from '../middleware/rate-limit';

// Stub an LLM: returns a fixed envelope.
function stubLlm(envelope: { response: string; toolCalls: unknown[] }) {
  const fetch = vi.fn(async () => ({
    ok: true,
    json: async () => ({
      choices: [{ message: { content: JSON.stringify(envelope) } }],
      usage: { total_tokens: 42 },
    }),
  }));
  globalThis.fetch = fetch as never;
  return fetch;
}

describe('ToolBus', () => {
  it('registers and executes tools', async () => {
    const bus = new ToolBus();
    bus.register('echo', async (args) => ({ echoed: args }));
    const result = await bus.execute('echo', { x: 1 }, {} as AgentContext, {} as never);
    expect(result).toEqual({ echoed: { x: 1 } });
  });

  it('throws on unknown tool', async () => {
    const bus = new ToolBus();
    await expect(bus.execute('nope', {}, {} as AgentContext, {} as never)).rejects.toThrow('Unknown tool: nope');
  });

  it('throws on duplicate registration', () => {
    const bus = new ToolBus();
    bus.register('a', async () => null);
    expect(() => bus.register('a', async () => null)).toThrow('already registered');
  });

  it('lists tools', () => {
    const bus = new ToolBus();
    bus.register('a', async () => null);
    bus.register('b', async () => null);
    expect(bus.list().sort()).toEqual(['a', 'b']);
  });

  it('has() reports membership', () => {
    const bus = new ToolBus();
    bus.register('a', async () => null);
    expect(bus.has('a')).toBe(true);
    expect(bus.has('b')).toBe(false);
  });
});

describe('AgentRunner', () => {
  beforeEach(() => {
    _resetBucketsForTests();
  });

  const def: AgentDefinition = {
    name: 'test',
    systemPrompt: 'You are a test agent.',
    tools: ['rag_search'],
    model: 'gpt-4o-mini',
    temperature: 0.5,
  };

  it('returns the response when no tool calls', async () => {
    stubLlm({ response: 'Hello world', toolCalls: [] });
    const bus = new ToolBus();
    bus.register('rag_search', async () => []);
    const runner = new AgentRunner({ OPENAI_API_KEY: 'sk-test' } as never, def, bus);
    const result = await runner.run('hi', { userId: 'u1', sessionId: 's1', history: [] });
    expect(result.response).toBe('Hello world');
    expect(result.toolCalls).toEqual([]);
    expect(result.tokensUsed).toBe(42);
  });

  it('executes tool calls and does a second LLM pass', async () => {
    // First pass: model wants to call a tool.
    const fetch = vi.fn();
    fetch
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          choices: [{ message: { content: JSON.stringify({ response: 'let me check', toolCalls: [{ name: 'rag_search', args: { query: 'test' } }] }) } }],
          usage: { total_tokens: 10 },
        }),
      })
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          choices: [{ message: { content: JSON.stringify({ response: 'final answer based on tool', toolCalls: [] }) } }],
          usage: { total_tokens: 20 },
        }),
      });
    globalThis.fetch = fetch as never;

    const bus = new ToolBus();
    bus.register('rag_search', async () => [{ chunk_text: 'result' }]);
    const runner = new AgentRunner({ OPENAI_API_KEY: 'sk-test' } as never, def, bus);
    const result = await runner.run('query', { userId: 'u1', sessionId: 's1', history: [] });
    expect(result.response).toBe('final answer based on tool');
    expect(result.toolCalls).toHaveLength(1);
    expect(result.toolCalls[0].name).toBe('rag_search');
    expect(result.toolCalls[0].result).toEqual([{ chunk_text: 'result' }]);
    expect(result.tokensUsed).toBe(30);
  });

  it('rejects tool calls not in the agent definition', async () => {
    stubLlm({
      response: 'trying',
      toolCalls: [{ name: 'fetch_user_profile', args: { userId: 'x' } }],
    });
    const bus = new ToolBus();
    bus.register('rag_search', async () => []);
    bus.register('fetch_user_profile', async () => ({ id: 'x' }));
    const runner = new AgentRunner({ OPENAI_API_KEY: 'sk-test' } as never, def, bus);
    const result = await runner.run('hi', { userId: 'u1', sessionId: 's1', history: [] });
    expect(result.toolCalls).toHaveLength(1);
    expect(result.toolCalls[0].error).toContain('not available to this agent');
  });

  it('captures tool execution errors', async () => {
    stubLlm({
      response: 'checking',
      toolCalls: [{ name: 'rag_search', args: {} }],
    });
    const bus = new ToolBus();
    bus.register('rag_search', async () => { throw new Error('boom'); });
    const runner = new AgentRunner({ OPENAI_API_KEY: 'sk-test' } as never, def, bus);
    const result = await runner.run('hi', { userId: 'u1', sessionId: 's1', history: [] });
    expect(result.toolCalls[0].error).toBe('boom');
  });

  it('caps tool calls at 4 per turn', async () => {
    stubLlm({
      response: 'checking',
      toolCalls: Array.from({ length: 8 }, (_, i) => ({ name: 'rag_search', args: { n: i } })),
    });
    const bus = new ToolBus();
    bus.register('rag_search', async () => null);
    const runner = new AgentRunner({ OPENAI_API_KEY: 'sk-test' } as never, def, bus);
    const result = await runner.run('hi', { userId: 'u1', sessionId: 's1', history: [] });
    expect(result.toolCalls).toHaveLength(4);
  });
});

describe('rate-limit middleware', () => {
  beforeEach(() => {
    _resetBucketsForTests();
  });

  it('returns 429 when bucket exhausted', async () => {
    const middleware = rateLimit('test-scope');
    const ctx = (user: any) => ({
      req: { header: () => undefined },
      env: {} as never,
      get: () => user,
      set: () => {},
      json: (body: unknown, status: number) => ({ body, status }),
      header: () => {},
    });

    // 20 calls (student) should pass
    for (let i = 0; i < 20; i++) {
      const c = ctx({ id: 'u1', role: 'student' }) as never;
      const result = await middleware(c, () => Promise.resolve());
      expect(result).toBeUndefined();
    }
    // 21st should 429
    const c = ctx({ id: 'u1', role: 'student' }) as never;
    const result = await middleware(c, () => Promise.resolve()) as { body: any; status: number };
    expect(result.status).toBe(429);
    expect(result.body).toHaveProperty('error.code', 'RATE_LIMITED');
  });

  it('allows 200 for pro tier (teacher)', async () => {
    const middleware = rateLimit('test-scope-2');
    const ctx = (user: any) => ({
      req: { header: () => undefined },
      env: {} as never,
      get: () => user,
      set: () => {},
      json: (body: unknown, status: number) => ({ body, status }),
      header: () => {},
    });

    for (let i = 0; i < 200; i++) {
      const c = ctx({ id: 'u2', role: 'teacher' }) as never;
      const result = await middleware(c, () => Promise.resolve());
      expect(result).toBeUndefined();
    }
    // 201st should 429
    const c = ctx({ id: 'u2', role: 'teacher' }) as never;
    const result = await middleware(c, () => Promise.resolve()) as { body: any; status: number };
    expect(result.status).toBe(429);
  });
});