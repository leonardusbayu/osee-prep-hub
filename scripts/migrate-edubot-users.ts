/**
 * Migrate EduBot users to Hub unified_profiles — blueprint line 2707.
 *
 * Run: npx tsx scripts/migrate-edubot-users.ts
 *
 * Reads from EduBot's D1 database (via Cloudflare REST API or local export)
 * and inserts corresponding rows into Hub's Supabase unified_profiles table.
 * Sets edubot_user_id + telegram_id to link accounts.
 *
 * Idempotent: skips users whose email or telegram_id already exists.
 *
 * Environment:
 *   SUPABASE_URL, SUPABASE_SERVICE_KEY  — Hub DB
 *   EDUBOT_D1_DATABASE_ID               — Cloudflare D1 database ID
 *   CF_ACCOUNT_ID, CF_API_TOKEN         — to query D1
 */

import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.SUPABASE_URL!;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY!;
const EDUBOT_D1_DATABASE_ID = process.env.EDUBOT_D1_DATABASE_ID!;
const CF_ACCOUNT_ID = process.env.CF_ACCOUNT_ID!;
const CF_API_TOKEN = process.env.CF_API_TOKEN!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

interface EduBotUser {
  id: number;
  email: string | null;
  telegram_id: string | null;
  display_name: string;
  role: string;
  target_exam: string | null;
  current_level: string | null;
  created_at: string;
}

async function fetchEduBotUsers(): Promise<EduBotUser[]> {
  // Query EduBot D1 via Cloudflare REST API
  // SELECT id, email, telegram_id, display_name, role, target_exam, current_level, created_at FROM users
  const sql = `SELECT id, email, telegram_id, display_name, role, target_exam, current_level, created_at FROM users LIMIT 5000`;
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/d1/database/${EDUBOT_D1_DATABASE_ID}/query`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${CF_API_TOKEN}`,
      },
      body: JSON.stringify({ sql }),
    }
  );
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`D1 query failed: ${res.status} ${text.slice(0, 200)}`);
  }
  const json = (await res.json()) as { result: Array<{ results: EduBotUser[] }> };
  return json.result[0]?.results ?? [];
}

async function migrateUser(u: EduBotUser): Promise<'inserted' | 'exists' | 'skipped'> {
  if (!u.email && !u.telegram_id) return 'skipped';

  // Check existing by email or telegram_id
  let existingQuery = supabase.from('unified_profiles').select('id').limit(1);
  if (u.email) {
    const { data } = await existingQuery.eq('email', u.email.toLowerCase()).maybeSingle();
    if (data) return 'exists';
  }
  if (u.telegram_id) {
    const { data } = await supabase
      .from('unified_profiles')
      .select('id')
      .eq('telegram_id', u.telegram_id)
      .maybeSingle();
    if (data) return 'exists';
  }

  // Insert
  const insert: Record<string, unknown> = {
    email: (u.email ?? `tg_${u.telegram_id}@edubot.local`).toLowerCase(),
    display_name: u.display_name,
    role: u.role === 'teacher' ? 'teacher' : 'student',
    target_exam: u.target_exam,
    current_level: u.current_level,
    telegram_id: u.telegram_id,
    edubot_user_id: u.id,
    created_at: u.created_at,
  };

  const { error } = await supabase.from('unified_profiles').insert(insert);
  if (error) {
    if (error.code === '23505') return 'exists'; // unique constraint
    throw new Error(`Insert failed for ${u.email ?? u.telegram_id}: ${error.message}`);
  }
  return 'inserted';
}

async function main(): Promise<void> {
  console.log('Fetching EduBot users from D1...');
  const users = await fetchEduBotUsers();
  console.log(`Found ${users.length} EduBot users.`);

  let inserted = 0, exists = 0, skipped = 0;
  for (const u of users) {
    try {
      const result = await migrateUser(u);
      if (result === 'inserted') inserted++;
      else if (result === 'exists') exists++;
      else skipped++;
      if ((inserted + exists + skipped) % 100 === 0) {
        console.log(`Progress: ${inserted + exists + skipped}/${users.length} (inserted=${inserted}, exists=${exists}, skipped=${skipped})`);
      }
    } catch (err) {
      console.error(`Failed to migrate user ${u.id} (${u.email ?? u.telegram_id}):`, err);
    }
  }
  console.log(`\nDone. Inserted: ${inserted}, Already exists: ${exists}, Skipped (no email+tg): ${skipped}`);
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});