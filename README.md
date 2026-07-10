# OSEE Prep Hub

[![CI](https://github.com/osee-edubot/osee-prep-hub/actions/workflows/ci.yml/badge.svg)](https://github.com/osee-edubot/osee-prep-hub/actions/workflows/ci.yml)
[![Deploy](https://github.com/osee-edubot/osee-prep-hub/actions/workflows/deploy-prod.yml/badge.svg)](https://github.com/osee-edubot/osee-prep-hub/actions/workflows/deploy-prod.yml)

AI Teaching Assistant platform for English teachers in Indonesia — connects all OSEE assets (4 practice platforms + EduBot) into one ecosystem.

## What This Is

`prep.osee.co.id` — a unified education platform where:
- **Teachers** get free AI tools (writing grader, material generator, reports) and earn commission on student actions
- **Partners (institutions)** manage multiple teachers and bulk-order tests at discounted rates
- **Students** access syllabi, track progress, and deep-link to practice platforms

## Tech Stack

- **Backend**: Cloudflare Workers + Hono (TypeScript) — `worker/`
- **Database**: Supabase PostgreSQL (new hub tables) + pgvector for RAG
- **Frontend (portals)**: Flutter Web (Riverpod + go_router + dio) — `flutter/`
- **Frontend (admin)**: React/Vite + Tailwind — `frontend-admin/`
- **AI**: OpenAI GPT-4o-mini + Whisper + TTS
- **Storage**: Cloudflare R2 (audio + video)
- **Auth**: JWT shared across `*.osee.co.id` via cookie

## Project Structure

```
osee-prep-hub/
├── worker/              # Cloudflare Workers API (Hono + TypeScript)
├── flutter/             # Flutter Web teacher/student/partner portals
├── frontend-admin/      # React/Vite admin tooling
├── scripts/              # Utility scripts (ingestion, seed, verify)
├── docs/                 # Documentation
├── schema.sql            # Supabase PostgreSQL schema
├── BLUEPRINT.md          # Original build blueprint
├── wrangler.toml         # Workers config (root-level)
├── package.json          # Workspace root
└── README.md             # This file
```

## Build Blueprint

See [BLUEPRINT.md](./BLUEPRINT.md) for the complete 18-week, 5-phase build plan.

## Development

### Worker (API)

```bash
cd worker
npm install
npm run dev          # wrangler dev — local API on localhost:8787
npm test             # vitest run
npm run deploy       # wrangler deploy (production)
```

### Flutter (Portals)

```bash
cd flutter
flutter pub get
flutter run -d chrome      # dev
flutter test               # widget tests
flutter build web          # production build → build/web/
```

### Admin (React/Vite)

```bash
cd frontend-admin
npm install
npm run dev          # Vite dev server
npm run build         # production build → dist/
```

### Database

```bash
# Apply schema to Supabase
psql $DATABASE_URL -f schema.sql
# Verify
npx tsx scripts/verify-schema.ts
```

## Environment

See [`.dev.vars.example`](./.dev.vars.example) for required environment variables.

## License

Proprietary — OSEE Education Hub.