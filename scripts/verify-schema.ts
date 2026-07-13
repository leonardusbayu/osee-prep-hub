/**
 * Verify all expected tables from schema.sql exist in Supabase.
 *
 * Usage:
 *   DATABASE_URL=postgresql://... npx tsx scripts/verify-schema.ts
 *
 * Or with psql directly:
 *   psql "$DATABASE_URL" -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Expected tables — matches schema.sql exactly
const EXPECTED_TABLES = [
  // Core
  'unified_profiles',
  'teacher_profiles',
  'classrooms',
  'classroom_enrollments',
  'syllabi',
  'syllabus_items',
  'syllabus_item_progress',
  // Referral + commission
  'teacher_referrals',
  'commission_rates',
  'commission_ledger',
  'commission_payouts',
  // AI quota
  'ai_quota_usage',
  'ai_quota_limits',
  // Knowledge base (RAG)
  'knowledge_base_documents',
  'knowledge_base_embeddings',
  // AI queues
  'ai_grading_queue',
  'ai_generation_queue',
  // Progress
  'student_progress_unified',
  'student_progress_history',
  'platform_links',
  // Cross-exam
  'cross_exam_score_map',
  // Video
  'video_courses',
  'video_lessons',
  'video_progress',
  // Live classes
  'live_classes',
  'class_registrations',
  // Webhooks
  'webhook_events',
  // Subscriptions + branding
  'teacher_subscriptions',
  'branding_configs',
  // Order system
  'pricing_config',
  'orders',
  'order_items',
  'vouchers',
] as const;

type TableName = (typeof EXPECTED_TABLES)[number];

interface VerifyResult {
  total: number;
  found: string[];
  missing: string[];
  extra: string[];
  ok: boolean;
}

async function fetchTables(databaseUrl: string): Promise<string[]> {
  const url = new URL(databaseUrl);
  throw new Error(
    `Direct database query not implemented. Use one of:\n` +
    `  1. Run schema.sql in Supabase SQL editor, then check tables via Supabase dashboard\n` +
    `  2. Use psql: psql "${databaseUrl}" -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"\n` +
    `  3. Implement pg connection here (install 'pg' package)\n`
  );
}

async function main(): Promise<void> {
  const databaseUrl = process.env.DATABASE_URL ?? process.env.SUPABASE_DB_URL;
  if (!databaseUrl) {
    console.error('Error: DATABASE_URL or SUPABASE_DB_URL environment variable not set.');
    console.error('');
    console.error('To verify schema:');
    console.error('  1. Set DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT].supabase.co:5432/postgres');
    console.error('  2. Run: npx tsx scripts/verify-schema.ts');
    console.error('');
    console.error(`Expected tables (${EXPECTED_TABLES.length}):`);
    for (const t of EXPECTED_TABLES) {
      console.error(`  - ${t}`);
    }
    process.exit(1);
  }

  try {
    const actualTables = await fetchTables(databaseUrl);
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