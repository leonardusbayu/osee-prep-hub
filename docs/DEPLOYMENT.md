# Deployment Guide — Task 18.5

This guide covers production deployment of the OSEE Prep Hub.

## Prerequisites

- Cloudflare account with Workers + Pages enabled
- Custom domain `prep.osee.co.id` configured in Cloudflare
- Supabase project (URL + service key)
- OpenAI API key
- Telegram bot token (for EduBot bridge)
- EduBot deployed at known URL (for speaking evaluation)

## Step 1: Set Cloudflare Secrets

```bash
cd worker
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_KEY
wrangler secret put JWT_SECRET
wrangler secret put OPENAI_API_KEY
wrangler secret put EDUBOT_INTERNAL_SECRET
wrangler secret put WEBHOOK_SECRET_IBT
wrangler secret put WEBHOOK_SECRET_ITP
wrangler secret put WEBHOOK_SECRET_IELTS
wrangler secret put WEBHOOK_SECRET_TOEIC
wrangler secret put WEBHOOK_SECRET_BOOKING
wrangler secret put WEBHOOK_SECRET_EDUBOT
wrangler secret put TELEGRAM_BOT_TOKEN
wrangler secret put TELEGRAM_CHANNEL_ID
wrangler secret put OSEE_BOOKING_API_URL
wrangler secret put OSEE_BOOKING_API_SECRET
wrangler secret put TRIPAY_API_KEY
wrangler secret put TRIPAY_PRIVATE_KEY
wrangler secret put TRIPAY_MERCHANT_CODE
```

## Step 2: Apply Supabase Schema

Three options, listed easiest-first:

### Option A: Supabase SQL Editor (easiest)

1. Open https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/sql/new
2. Paste contents of `schema.sql` (1040+ lines: 29 blueprint tables + order/commission/Passport/marketplace/agent/push/viral/disputes/audit extensions + match_documents function + triggers)
3. Click "Run"
4. Verify: `SELECT count(*) FROM information_schema.tables WHERE table_schema='public';` should return 27+ tables

### Option B: `apply-schema.ts` (Node, no psql required)

```bash
# Get the DB connection string from:
#   https://supabase.com/dashboard/project/zrnencaixfwpswfpmliv/settings/database
#   → Connection string → URI
# Format: postgresql://postgres.zrnencaixfwpswfpmliv:[PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:6543/postgres

export SUPABASE_DB_URL='postgresql://postgres:[PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:6543/postgres'
npx tsx scripts/apply-schema.ts
```

The script installs `pg` automatically if not present, reads `schema.sql`, and applies it in a single transaction. Works on macOS, Linux, and Windows.

### Option C: psql (if you have it installed locally)

```bash
# Linux/macOS
psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f schema.sql

# Windows PowerShell
psql $env:SUPABASE_DB_URL -v ON_ERROR_STOP=1 -f schema.sql
```

## Step 3: Ingest Knowledge Base

```bash
cd ..
# Set env vars
export OPENAI_API_KEY=sk-...
export SUPABASE_URL=https://xxx.supabase.co
export SUPABASE_SERVICE_KEY=ey...

# Dry run first
npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1 --dry-run

# Actual ingestion
npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/tier1 --tier 1
```

Expected output:
```
Found 5 files
INGESTED: docs/knowledge-base/tier1/cefr-b1-writing.md → 1 chunks
INGESTED: docs/knowledge-base/tier1/cefr-b2-writing.md → 1 chunks
... (5 total)
Summary: 5 processed, 0 skipped, 0 failed
```

## Step 4: Deploy Worker

```bash
cd worker
wrangler deploy
```

Verify health:
```bash
curl https://prep-api.osee.co.id/api/health
# Expected: {"status":"ok","timestamp":"..."}
```

## Step 5: Build Flutter Web

```bash
cd flutter
flutter pub get
flutter build web --release
```

Verify build:
- `flutter/build/web/index.html` should be created
- `flutter/build/web/main.dart.js` should exist

## Step 6: Deploy Flutter to Cloudflare Pages

```bash
wrangler pages deploy build/web --project-name=osee-prep-hub
```

This creates `https://osee-prep-hub.pages.dev`.

## Step 7: Configure Custom Domain

In Cloudflare dashboard:
1. Pages → osee-prep-hub → Custom domains
2. Add `prep.osee.co.id`
3. DNS: Cloudflare will add a CNAME record automatically

Verify:
- https://prep.osee.co.id loads the Flutter app

## Step 8: Configure DNS for API

For `prep.osee.co.id/api/*` to route to the Worker:
1. DNS → Add record:
   - Type: CNAME
   - Name: api (or use a Workers route)
   - Target: `osee-prep-hub-worker.your-subdomain.workers.dev`
2. In Worker → Settings → Triggers → Add Route:
   - `prep.osee.co.id/api/*` → osee-prep-hub worker

## Step 9: Configure Webhook Secrets on Practice Platforms

For each platform (ibt.osee.co.id, itp.osee.co.id, etc.), add a webhook:
- URL: `https://prep-api.osee.co.id/api/webhook/{ibt|itp|ielts|toeic|booking|edubot}`
- Header: `X-Webhook-Secret: <same value as WEBHOOK_SECRET_IBT env var>`
- Events to forward:
  - `practice_completed`
  - `test_booked`
  - `test_completed`
  - `bot_session_started`

## Step 10: Smoke Test

```bash
# Health check
curl https://prep-api.osee.co.id/api/health

# Register a teacher
curl -X POST https://prep-api.osee.co.id/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@osee.co.id","password":"TestPass123!","name":"Test Teacher","role":"teacher"}'

# Login
curl -X POST https://prep-api.osee.co.id/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@osee.co.id","password":"TestPass123!"}' \
  -c cookies.txt

# Test AI grading
curl -X POST https://prep-api.osee.co.id/api/ai/grade-writing \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{"essay":"My essay about technology...","rubric":"ielts_task2","examType":"IELTS","level":"B2"}'
```

## Step 11: Configure EduBot Bridge

In EduBot's environment, add:
- `HUB_API_URL=https://prep-api.osee.co.id/api`
- `HUB_INTERNAL_SECRET=<same as EDUBOT_INTERNAL_SECRET in worker>`

EduBot will call `/api/external/verify-student` to authenticate students.

## Step 12: Configure TriPay (Payment)

In TriPay dashboard:
1. Add a merchant callback URL: `https://prep-api.osee.co.id/api/orders/webhook/tripay`
2. Add the merchant code + API key (already in Worker env)
3. Test with a small transaction

## Rollback

If something goes wrong:
1. `wrangler rollback` (restores last successful Worker deploy)
2. `wrangler pages rollback --project-name=osee-prep-hub` (restores last Pages deploy)
3. Supabase migrations are forward-only — fix via SQL update

## Monitoring

- Cloudflare Workers: https://dash.cloudflare.com → Workers → osee-prep-hub → Logs
- Cloudflare Pages: Pages → osee-prep-hub → Visit logs
- Supabase: Dashboard → Logs/Query

## Estimated Deploy Time

- Worker secrets setup: ~10 minutes
- Schema apply: ~2 minutes
- KB ingestion: ~2 minutes (5 files)
- Worker deploy: ~30 seconds
- Flutter build: ~3 minutes
- Pages deploy: ~30 seconds
- DNS configuration: ~5 minutes (propagation)

**Total: ~25 minutes** if you have all the credentials ready.