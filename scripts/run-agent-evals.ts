/**
 * Agent eval harness — Task 1 (Wave 1).
 *
 * Usage: npx tsx scripts/run-agent-evals.ts --agent curator --min-pass-rate 0.85
 *
 * Loads test cases from scripts/agent-evals/<agent>.json, runs each through
 * the agent, scores via keyword match on expected output. Exits 0 if pass
 * rate >= min-pass-rate, 1 otherwise.
 *
 * NOTE: This requires OPENAI_API_KEY to be set in the environment. It calls
 * the real OpenAI API — so evals cost tokens. For CI, mark this test as
 * opt-in (not part of the default `npm test` run).
 */

import { readFileSync, readdirSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from 'dotenv';

// Load .env if present (local dev convenience)
try { config(); } catch { /* dotenv optional */ }

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(__dirname, '..');

interface EvalCase {
  input: string;
  expectKeywords: string[];
  description: string;
}

interface EvalResult {
  description: string;
  passed: boolean;
  missing: string[];
  responsePreview: string;
}

function loadCases(agent: string): EvalCase[] {
  const path = resolve(REPO_ROOT, 'scripts', 'agent-evals', `${agent}.json`);
  try {
    const raw = readFileSync(path, 'utf-8');
    return JSON.parse(raw) as EvalCase[];
  } catch {
    console.error(`No eval cases found for agent "${agent}" at ${path}`);
    console.error('Available agents:', readdirSync(resolve(REPO_ROOT, 'scripts', 'agent-evals')).map(f => f.replace('.json', '')));
    process.exit(2);
  }
}

function scoreResponse(response: string, expectKeywords: string[]): { passed: boolean; missing: string[] } {
  const lower = response.toLowerCase();
  const missing = expectKeywords.filter(k => !lower.includes(k.toLowerCase()));
  return { passed: missing.length === 0, missing };
}

async function runAgent(agentName: string, input: string): Promise<string> {
  // Dynamic import of worker source — assumes ESM build or tsx runtime.
  const { getAgent } = await import(resolve(REPO_ROOT, 'worker', 'src', 'agents', 'index.ts'));
  const { AgentRunner, ToolBus, type AgentContext } = await import(resolve(REPO_ROOT, 'worker', 'src', 'agents', 'runtime.ts'));
  const { registerBuiltinTools } = await import(resolve(REPO_ROOT, 'worker', 'src', 'agents', 'tools.ts'));

  const env = {
    OPENAI_API_KEY: process.env.OPENAI_API_KEY ?? '',
    SUPABASE_URL: process.env.SUPABASE_URL ?? '',
    SUPABASE_SERVICE_KEY: process.env.SUPABASE_SERVICE_KEY ?? '',
  } as Record<string, string>;

  if (!env.OPENAI_API_KEY) {
    throw new Error('OPENAI_API_KEY must be set to run evals');
  }

  const def = getAgent(agentName);
  const ctx: AgentContext = { userId: 'eval-runner', sessionId: 'eval', history: [] };
  const bus = new ToolBus();
  registerBuiltinTools(bus, ctx);
  const runner = new AgentRunner(env as never, def, bus);
  const result = await runner.run(input, ctx);
  return result.response;
}

async function main() {
  const args = process.argv.slice(2);
  const agentIdx = args.indexOf('--agent');
  const minPassIdx = args.indexOf('--min-pass-rate');
  const agentName = agentIdx >= 0 ? args[agentIdx + 1] : null;
  const minPassRate = minPassIdx >= 0 ? parseFloat(args[minPassIdx + 1]) : 0.85;

  if (!agentName) {
    console.error('Usage: npx tsx scripts/run-agent-evals.ts --agent <name> --min-pass-rate <0..1>');
    process.exit(2);
  }

  const cases = loadCases(agentName);
  console.log(`\n=== Eval: ${agentName} (${cases.length} cases, min pass rate: ${minPassRate}) ===\n`);

  const results: EvalResult[] = [];
  for (const c of cases) {
    try {
      const response = await runAgent(agentName, c.input);
      const { passed, missing } = scoreResponse(response, c.expectKeywords);
      results.push({
        description: c.description,
        passed,
        missing,
        responsePreview: response.slice(0, 200),
      });
      console.log(`${passed ? '✓' : '✗'} ${c.description}${passed ? '' : ` — missing: ${missing.join(', ')}`}`);
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      results.push({ description: c.description, passed: false, missing: ['(threw error)'], responsePreview: message });
      console.log(`✗ ${c.description} — error: ${message}`);
    }
  }

  const passCount = results.filter(r => r.passed).length;
  const passRate = passCount / results.length;
  console.log(`\nPass rate: ${passCount}/${results.length} = ${(passRate * 100).toFixed(1)}%`);

  if (passRate >= minPassRate) {
    console.log(`PASS (>= ${minPassRate})`);
    process.exit(0);
  } else {
    console.log(`FAIL (< ${minPassRate})`);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('Eval harness crashed:', err);
  process.exit(1);
});