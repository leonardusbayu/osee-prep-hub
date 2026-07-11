# Apply schema.sql to Supabase (Windows PowerShell)
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
# METHOD B: psql + DB password (if you have psql installed)
# ─────────────────────────────────────────────────────────────
# 1. Get the password from https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/settings/database
# 2. Set SUPABASE_DB_URL environment variable, then run:
#    $env:SUPABASE_DB_URL = "postgresql://postgres.zrnencaixfwpswfpmliv:YOUR_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres"
#    .\scripts\apply-schema.ps1
#

param(
    [string]$DbUrl = $env:SUPABASE_DB_URL
)

$ErrorActionPreference = 'Stop'

if (-not $DbUrl -or $DbUrl -match 'YOUR_PASSWORD') {
    Write-Host "Error: set SUPABASE_DB_URL first (get it from Supabase dashboard → Settings → Database)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  `$env:SUPABASE_DB_URL = 'postgresql://postgres.zrnencaixfwpswfpmliv:ACTUAL_PASSWORD@aws-0-ap-south-1.pooler.supabase.com:6543/postgres'"
    Write-Host "  .\scripts\apply-schema.ps1"
    exit 1
}

Write-Host "Applying schema.sql to Supabase..."
psql $DbUrl -v ON_ERROR_STOP=1 -f schema.sql
Write-Host "Schema applied successfully." -ForegroundColor Green

Write-Host ""
Write-Host "Verifying tables..."
npx tsx scripts/verify-schema.ts