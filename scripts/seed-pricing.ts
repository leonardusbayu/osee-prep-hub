import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

type Role = 'student' | 'teacher' | 'partner' | 'admin';
type ItemType =
  | 'mock_itp'
  | 'mock_ibt'
  | 'mock_ielts'
  | 'mock_toeic'
  | 'tutor_bot_premium'
  | 'official_toefl'
  | 'official_toeic';

interface PricingRow {
  item_type: ItemType;
  role: Role;
  price: number;
  is_active: boolean;
}

const DEFAULT_PRICING: Array<Omit<PricingRow, 'is_active'>> = [
  { item_type: 'mock_itp', role: 'student', price: 75000 },
  { item_type: 'mock_itp', role: 'teacher', price: 60000 },
  { item_type: 'mock_itp', role: 'partner', price: 50000 },
  { item_type: 'mock_itp', role: 'admin', price: 0 },

  { item_type: 'mock_ibt', role: 'student', price: 150000 },
  { item_type: 'mock_ibt', role: 'teacher', price: 120000 },
  { item_type: 'mock_ibt', role: 'partner', price: 100000 },
  { item_type: 'mock_ibt', role: 'admin', price: 0 },

  { item_type: 'mock_ielts', role: 'student', price: 150000 },
  { item_type: 'mock_ielts', role: 'teacher', price: 120000 },
  { item_type: 'mock_ielts', role: 'partner', price: 100000 },
  { item_type: 'mock_ielts', role: 'admin', price: 0 },

  { item_type: 'mock_toeic', role: 'student', price: 100000 },
  { item_type: 'mock_toeic', role: 'teacher', price: 80000 },
  { item_type: 'mock_toeic', role: 'partner', price: 65000 },
  { item_type: 'mock_toeic', role: 'admin', price: 0 },

  { item_type: 'tutor_bot_premium', role: 'student', price: 99000 },
  { item_type: 'tutor_bot_premium', role: 'teacher', price: 79000 },
  { item_type: 'tutor_bot_premium', role: 'partner', price: 69000 },
  { item_type: 'tutor_bot_premium', role: 'admin', price: 0 },

  { item_type: 'official_toefl', role: 'student', price: 650000 },
  { item_type: 'official_toefl', role: 'teacher', price: 625000 },
  { item_type: 'official_toefl', role: 'partner', price: 600000 },
  { item_type: 'official_toefl', role: 'admin', price: 0 },

  { item_type: 'official_toeic', role: 'student', price: 550000 },
  { item_type: 'official_toeic', role: 'teacher', price: 525000 },
  { item_type: 'official_toeic', role: 'partner', price: 500000 },
  { item_type: 'official_toeic', role: 'admin', price: 0 },
];

function loadDevVars(path: string) {
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

async function main() {
  loadDevVars(resolve(process.cwd(), 'worker/.dev.vars'));
  loadDevVars(resolve(process.cwd(), '.dev.vars'));

  const supabaseUrl = process.env.SUPABASE_URL;
  const serviceKey = process.env.SUPABASE_SERVICE_KEY;

  if (!supabaseUrl || !serviceKey) {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY are required.');
  }
  if (supabaseUrl.includes('placeholder') || serviceKey === 'placeholder') {
    throw new Error('SUPABASE_URL and SUPABASE_SERVICE_KEY still look like placeholder values.');
  }

  const rows: PricingRow[] = DEFAULT_PRICING.map((row) => ({ ...row, is_active: true }));
  const endpoint = `${supabaseUrl.replace(/\/$/, '')}/rest/v1/pricing_config?on_conflict=item_type,role`;

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      apikey: serviceKey,
      Authorization: `Bearer ${serviceKey}`,
      'Content-Type': 'application/json',
      Prefer: 'resolution=merge-duplicates,return=representation',
    },
    body: JSON.stringify(rows),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`Pricing seed failed (${response.status}): ${body}`);
  }

  const seeded = (await response.json()) as PricingRow[];
  console.log(`Seeded ${seeded.length} pricing rows.`);
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
