/**
 * Verify all expected tables from schema.sql exist in Supabase.
 *
 * Probes the Supabase REST API (PostgREST OpenAPI document) to enumerate
 * tables in the `public` schema, then compares against EXPECTED_TABLES.
 *
 * Usage:
 *   npx tsx scripts/verify-schema.ts
 *
 * Requires SUPABASE_URL and SUPABASE_SERVICE_KEY (loaded from worker/.dev.vars
 * or .dev.vars, or set in the environment). For a local/DIY alternative:
 *   psql "$DATABASE_URL" -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"
 */
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const EXPECTED_TABLES = [
  'unified_profiles',
  'teacher_profiles',
  'classrooms',
  'classroom_enrollments',
  'syllabi',
  'syllabus_items',
  'syllabus_item_progress',
  'teacher_referrals',
  'commission_rates',
  'commission_ledger',
  'commission_payouts',
  'ai_quota_usage',
  'ai_quota_limits',
  'knowledge_base_documents',
  'knowledge_base_embeddings',
  'ai_grading_queue',
  'ai_generation_queue',
  'student_progress_unified',
  'student_progress_history',
  'platform_links',
  'cross_exam_score_map',
  'video_courses',
  'video_lessons',
  'video_progress',
  'live_classes',
  'class_registrations',
  'webhook_events',
  'teacher_subscriptions',
  'branding_configs',
  'pricing_config',
  'orders',
  'order_items',
  'vouchers',
  'teacher_invitations',
  'syllabus_item_comments',
  'syllabus_item_attachments',
] as const;

interface VerifyResult {
  total: number;
  found: string[];
  missing: string[];
  extra: string[];
  ok: boolean;
}

function loadDevVars(path: string): void {
  if (!existsSync(path)) return;
  const content = readFileSync(path, 'utf8');
  for (const line of content.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const equals = trimmed.indexOf('=');
    if (equals === -1) continue;
    const key = trimmed.slice(0, equals).trim();
    const value = trimmed.slice(equals + 1).trim();
    if (key && process.env[key] === undefined) {
      process.env[key] = value;
    }
  }
}

async function fetchTableList(supabaseUrl: string, serviceKey: string): Promise<string[]> {
  const endpoint = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/`;
  const response = await fetch(endpoint, {
    method: 'GET',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      Accept: 'application/openapi+json',
    },
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Supabase REST introspection failed (${response.status}): ${body}`);
  }

  const openapi = (await response.json()) as {
    paths?: Record<string, unknown>;
    definitions?: Record<string, unknown>;
  };

  const tables = new Set<string>();
  if (openapi.paths) {
    for (const path of Object.keys(openapi.paths)) {
      const match = path.match(/^\/([^/{}]+)$/);
      if (match) tables.add(match[1]);
    }
  }
  if (openapi.definitions) {
    for (const name of Object.keys(openapi.definitions)) {
      tables.add(name);
    }
  }
  return Array.from(tables).sort();
}

async function main(): Promise<void> {
  loadDevVars(resolve(process.cwd(), 'worker/.dev.vars'));
  loadDevVars(resolve(process.cwd(), '.dev.vars'));

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_KEY;

  if (!supabaseUrl || !serviceKey) {
    console.error('Error: SUPABASE_URL and SUPABASE_SERVICE_KEY are required.');
    console.error('Set them in worker/.dev.vars (or .dev.vars) or in the environment.');
    process.exit(1);
  }
  if (supabaseUrl.includes('placeholder') || serviceKey === 'placeholder') {
    console.error('Error: SUPABASE_URL / SUPABASE_SERVICE_KEY still look like placeholder values.');
    process.exit(1);
  }

  try {
    const actualTables = await fetchTableList(supabaseUrl, serviceKey);
    const expectedSet = new Set<string>(EXPECTED_TABLES);
    const actualSet = new Set(actualTables);

    const found = EXPECTED_TABLES.filter((t) => actualSet.has(t));
    const missing = EXPECTED_TABLES.filter((t) => !actualSet.has(t));
    const extra = actualTables.filter((t) => !expectedSet.has(t));

    const result: VerifyResult = {
      total: EXPECTED_TABLES.length,
      found,
      missing,
      extra,
      ok: missing.length === 0,
    };

    console.log(JSON.stringify(result, null, 2));
    process.exit(result.ok ? 0 : 1);
  } catch (err) {
    console.error('Verification failed:', err instanceof Error ? err.message : String(err));
    process.exit(2);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});