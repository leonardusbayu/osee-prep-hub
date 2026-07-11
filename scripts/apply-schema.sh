#!/usr/bin/env bash
# Apply schema.sql to Supabase.
#
# Prerequisites: pick one method below.
#
# ─────────────────────────────────────────────────────────────
# METHOD A: Supabase SQL Editor (easiest, browser-based)
# ─────────────────────────────────────────────────────────────
# 1. Go to https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/sql/new
# 2. Paste the contents of schema.sql
# 3. Click "Run"
#
# ─────────────────────────────────────────────────────────────
# METHOD B: psql + DB password (from Supabase dashboard)
# ─────────────────────────────────────────────────────────────
# 1. Get the password:
#    - Go to https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/settings/database
#    - Under "Connection string" → "URI" → copy the password portion
#    - Format: postgresql://postgres.zrnencaixfwpswfpmliv:[PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:6543/postgres
# 2. Apply:
set -euo pipefail
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres.zrnencaixfwpswfpmliv:YOUR_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres}"

if [[ "$DB_URL" == *"YOUR_PASSWORD"* ]]; then
  echo "Error: set SUPABASE_DB_URL first (get it from Supabase dashboard → Settings → Database)"
  echo ""
  echo "  export SUPABASE_DB_URL='postgresql://postgres.zrnencaixfwpswfpmliv:ACTUAL_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres'"
  exit 1
fi

echo "Applying schema.sql to Supabase..."
psql "$DB_URL" -v ON_ERROR_STOP=1 -f schema.sql
echo "Schema applied successfully."

echo ""
echo "Verifying tables..."
npx tsx scripts/verify-schema.ts