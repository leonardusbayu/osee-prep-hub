/**
 * Apply schema.sql to Supabase using node-postgres.
 *
 * This works WITHOUT needing the Supabase CLI or psql — it installs pg
 * temporarily and connects via the connection string.
 *
 * Usage:
 *   SUPABASE_DB_URL='postgresql://postgres:[PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:6543/postgres' \
 *     npx tsx scripts/apply-schema.ts
 *
 * Get the password from:
 *   https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/settings/database
 *   → Connection string → URI → copy the password portion
 */

import { spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

// Step 1: Install pg if not present.
console.log('[1/3] Ensuring pg package is installed...');
const installed = spawnSync('npm', ['ls', 'pg'], { encoding: 'utf-8' });
if (!installed.stdout.includes('pg@')) {
  console.log('Installing pg (one-time)...');
  const install = spawnSync('npm', ['install', '--no-save', 'pg@8', '@types/pg'], { stdio: 'inherit' });
  if (install.status !== 0) {
    console.error('Failed to install pg');
    process.exit(1);
  }
}

// Step 2: Read schema.sql.
const schemaPath = resolve(import.meta.dirname, '..', 'schema.sql');
console.log(`[2/3] Reading ${schemaPath}...`);
const schemaSql = readFileSync(schemaPath, 'utf-8');

const dbUrl = process.env.SUPABASE_DB_URL;
if (!dbUrl) {
  console.error('Error: SUPABASE_DB_URL env var not set.');
  console.error('');
  console.error('Get the connection string from:');
  console.error('  https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/settings/database');
  console.error('  → Connection string → URI');
  console.error('');
  console.error('Then run:');
  console.error('  $env:SUPABASE_DB_URL = "postgresql://postgres:[PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:6543/postgres"');
  console.error('  npx tsx scripts/apply-schema.ts');
  process.exit(1);
}

// Step 3: Apply schema.
console.log('[3/3] Applying schema...');
const { Client } = await import('pg');
const client = new Client({ connectionString: dbUrl });
await client.connect();

try {
  await client.query(schemaSql);
  console.log('Schema applied successfully.');
} finally {
  await client.end();
}