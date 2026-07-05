/**
 * Verify all expected tables from schema.sql exist in Supabase.
 *
 * Usage:
 *   DATABASE_URL=postgresql://... npx tsx scripts/verify-schema.ts
 *
 * Or with Supabase CLI:
 *   npx tsx scripts/verify-schema.ts --supabase-url=... --supabase-key=...
 */
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Expected tables from blueprint Section 4 + order system extension
const EXPECTED_TABLES = [
  // Core
  'unified_profiles',
  'teacher_profiles',
  'student_profiles',
  'referral_codes',
  'classrooms',
  'classroom_enrollments',
  'syllabi',
  'syllabus_items',
  // AI
  'ai_grading_queue',
  'ai_generation_queue',
  'documents',
  // Commission
  'commission_ledger',
  'commission_payouts',
  'ambassador_teachers',
  // Webhooks + progress
  'webhook_events',
  'student_progress_unified',
  // Video + classes
  'video_courses',
  'video_lessons',
  'video_progress',
  'live_classes',
  'class_registrations',
  // Branding
  'branding_config',
  // Order system (Task 1.1 addition)
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
  // Use fetch to query Supabase REST API if URL is a Supabase URL,
  // otherwise fall back to pg-style query (requires pg package).
  // For simplicity, this script uses Supabase's REST API.
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
    console.error('Or verify manually via Supabase SQL editor:');
    console.error('  SELECT tablename FROM pg_tables WHERE schemaname=\'public\' ORDER BY tablename;');
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