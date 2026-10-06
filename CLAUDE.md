# Project Instructions — OSEE Prep Hub

## What This Is
AI Teaching Assistant platform for English teachers in Indonesia (`prep.osee.co.id`).
Three apps in one repo: Hono API on Cloudflare Workers (`worker/`), Flutter Web portals
(`flutter/` — teacher/student/partner/landing), React/Vite admin tool (`frontend-admin/`).
Database is Supabase Postgres, schema lives in root `schema.sql` (37 tables).

## Tech Stack
- **Worker API**: Cloudflare Workers + Hono 4 + @supabase/supabase-js, TypeScript 5.6 strict
- **DB**: Supabase Postgres + pgvector (RAG) — apply via `psql $DATABASE_URL -f schema.sql`
- **Flutter**: Dart >=3.8, Riverpod 2.5, go_router 14, dio 5 (web, withCredentials)
- **Admin**: React 18 + Vite 5 + Tailwind 3 + react-router-dom 6
- **Externals**: OpenAI (GPT-4o-mini/Whisper/TTS), R2 buckets, TriPay payments, Resend email, Telegram bot
- **Cron**: every minute (`wrangler.toml`) — webhook batch, class reminders, recurring commission

## Build & Run
- Worker dev: `npm --workspace worker run dev` (wrangler, localhost:8787)
- Worker test: `npm --workspace worker run test` (vitest, node env)
- Worker typecheck: `npm --workspace worker run typecheck`
- Flutter: `cd flutter && flutter run -d chrome` / `flutter test` / `dart analyze`
- Admin dev: `npm --workspace frontend-admin run dev` / `npm --workspace frontend-admin run test` / `npm --workspace frontend-admin run typecheck`
- Schema verify / seed / ingest: `npm run verify:schema`, `npm run seed:pricing`, `npm run ingest:kb`

## Architecture Rules
- API routes in `worker/src/routes/` (one Hono sub-app per domain), business logic in
  `worker/src/services/`. Routes stay thin: parse body → validate → call service → return JSON.
- Error shape everywhere: `{ error: { code: string; message: string } }` (UNAUTHORIZED,
  FORBIDDEN, BAD_REQUEST, NOT_FOUND, INTERNAL_ERROR...). Never return bare error strings.
- Auth: JWT from `Authorization: Bearer` or `osee_token` cookie. Middleware:
  `requireAuth()`, `requireRole(...roles)`, `optionalAuth()` from `worker/src/middleware/auth.ts`.
  JWT fast-path (`userFromPayload`) — no DB round-trip per request.
- DB access via `getSupabase(env)` (service key, bypasses RLS) or `getAnonSupabase(env)`
  (anon key, respects RLS) from `worker/src/services/supabase.ts`.
- Some `/api/*` paths are blueprint-alias duplicates in `worker/src/index.ts` — keep aliases
  in sync when changing handlers.
- Env vars live in `.dev.vars` (gitignored) — copy `.dev.vars.example`. Never hardcode secrets.

## Code Style
- TypeScript strict: `noUnusedLocals`, `noUnusedParameters`, `noImplicitReturns` on.
- Tests co-located with source as `*.test.ts` (worker, 22 files) using vitest; Supabase
  clients mocked via the `vi.hoisted` chainable mock in e.g. `worker/src/services/pricing.test.ts`.
- Flutter: feature-first — `flutter/lib/features/<domain>/{models,pages,providers,widgets}`,
  shared HTTP in `lib/core/api_client.dart`, routes in `lib/core/router.dart`.
- Admin pages: one component per page in `frontend-admin/src/pages/`, API calls through
  `src/api/client.ts` (`apiFetch<T>` wrapper with global 401 handler).

## Git
- Commits: `feat:` / `fix:` lowercase, often in Indonesian. Example: `fix: syllabus builder — delete dan rename item tidak update board`
- Branches: lowercase-kebab (`magazine-ui`). No CI workflows configured.

## Testing
- Worker: `src/**/*.test.ts` in node env (pure functions + mocked bindings), 10s timeout.
- Flutter: `flutter/test/*_test.dart` with `fake_dio.dart` helper for network mocking.
- Admin: vitest + @testing-library/react, setup in `src/test-setup.ts`.

## Where to Look
| Task | Path |
|---|---|
| Add/edit API endpoint | `worker/src/routes/<domain>.ts` + `worker/src/services/` |
| Add DB table | `schema.sql` + `scripts/verify-schema.ts` table list |
| Add env var | `.dev.vars.example`, `worker/src/types.ts`, `wrangler.toml` secrets comment |
| Flutter page | `flutter/lib/features/<role>/pages/` + route in `lib/core/router.dart` |
| Admin page | `frontend-admin/src/pages/` |
| API reference | `docs/API.md`; deployment: `docs/DEPLOYMENT.md`; testing: `docs/TESTING.md` |