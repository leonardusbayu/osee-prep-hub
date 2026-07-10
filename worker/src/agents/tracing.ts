/**
 * Agent tracing middleware — Task 7 (Wave 1).
 *
 * Wraps an AgentRunner.run() call to insert a row into `agent_traces` after
 * each invocation. The trace records:
 * - agent_name, session_id, user_id
 * - input_summary (truncated to 200 chars, PII scrubbed via logger)
 * - output_summary (truncated)
 * - tool_calls (array)
 * - tokens_used, duration_ms, success, error_message
 *
 * Usage:
 *   const runner = new AgentRunner(env, def, bus);
 *   const traced = traceMiddleware(env, runner, ctx);
 *   const result = await traced(input);
 */

import type { Env } from '../types';
import type { AgentRunner, AgentContext, AgentRunResult } from './runtime';
import { getSupabase } from '../services/supabase';

export interface TraceRow {
  user_id: string;
  agent_name: string;
  session_id: string;
  input_summary: string;
  output_summary: string;
  tool_calls: unknown[];
  tokens_used: number;
  duration_ms: number;
  success: boolean;
  error_message: string | null;
}

/** Wrap an AgentRunner so each run() inserts a trace row. */
export function traceMiddleware(
  env: Env,
  runner: AgentRunner,
  ctx: AgentContext
): { run: (input: string) => Promise<AgentRunResult> } {
  return {
    run: async (input: string) => {
      const start = Date.now();
      let result: AgentRunResult | null = null;
      let errorMessage: string | null = null;
      try {
        result = await runner.run(input, ctx);
        return result;
      } catch (err) {
        errorMessage = err instanceof Error ? err.message : String(err);
        throw err;
      } finally {
        const durationMs = Date.now() - start;
        // Best-effort trace insert — never let a logging failure break the agent call.
        try {
          const supabase = getSupabase(env);
          const row: TraceRow = {
            user_id: ctx.userId,
            agent_name: (runner as unknown as { def: { name: string } }).def.name,
            session_id: ctx.sessionId,
            input_summary: truncate(input, 200),
            output_summary: result ? truncate(result.response, 200) : '',
            tool_calls: result?.toolCalls ?? [],
            tokens_used: result?.tokensUsed ?? 0,
            duration_ms: durationMs,
            success: errorMessage === null,
            error_message: errorMessage,
          };
          await supabase.from('agent_traces').insert(row);
        } catch (logErr) {
          console.error('agent_traces insert failed:', logErr instanceof Error ? logErr.message : logErr);
        }
      }
    },
  };
}

function truncate(s: string, max: number): string {
  return s.length > max ? s.slice(0, max) + '...' : s;
}