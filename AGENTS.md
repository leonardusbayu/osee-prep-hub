# OSEE Prep Hub — Agent Guide

## Project

OSEE Education Hub (`prep.osee.co.id`) — AI Teaching Assistant for English teachers in Indonesia.
Monorepo: Cloudflare Worker (API) + Flutter Web (portals) + React/Vite (admin).

## Key paths

- `worker/` — Cloudflare Workers API (Hono + TypeScript). Deploy: `npx wrangler deploy` (from `worker/`)
- `flutter/` — Flutter Web teacher/student/partner portals. Build: `flutter build web --release`
- `frontend-admin/` — React/Vite admin tooling. Build: `npm run build:admin`
- `schema.sql` — Supabase PostgreSQL schema (29 tables, RLS, seed data)
- `docs/DEPLOYMENT.md` — production deployment guide

## Commands

| Task | Command |
|---|---|
| Install (root) | `npm install` |
| Worker dev | `npm --workspace worker run dev` (localhost:8787) |
| Worker tests | `npm --workspace worker run test` |
| Worker typecheck | `npm --workspace worker run typecheck` |
| Worker deploy | `npm --workspace worker run deploy` |
| Admin dev | `npm --workspace frontend-admin run dev` (localhost:5173) |
| Admin typecheck | `npm --workspace frontend-admin run typecheck` |
| Admin build | `npm run build:admin` → `frontend-admin/dist/` |
| Flutter web build | `cd flutter && flutter build web --release` → `flutter/build/web/` |
| Flutter test | `cd flutter && flutter test` |
| Verify schema | `npm run verify:schema` |
| Seed pricing | `npm run seed:pricing` |
| Ingest KB | `npm run ingest:kb` |

## Deploy targets

- Worker: `https://osee-prep-hub-worker.edubot-leonardus.workers.dev` (Cloudflare)
- Flutter portal: `https://osee-prep-hub.pages.dev` (Cloudflare Pages, project `osee-prep-hub`)
- Admin: `https://osee-prep-hub-admin.pages.dev` (Cloudflare Pages, project `osee-prep-hub-admin`)
- Supabase project: `zrnencaixfwpswfpmliv` ("osee hub", ap-south-1)

## Auth

Roles: `student`, `teacher`, `partner`, `admin`, `institution`.
JWT in `osee_token` HttpOnly cookie (domain `.osee.co.id`) + Bearer header.
Endpoints under `/api/auth/*`: `register`, `login`, `verify`, `refresh`, `logout`.

## Secrets

Stored in Cloudflare Worker (set via `wrangler secret put <NAME>`):
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_KEY`, `JWT_SECRET`, `OPENAI_API_KEY`.
Optional (not yet set): webhook secrets, EduBot bridge, Telegram, TriPay, R2, OSEE booking.

## Branches

- `main` — production source of truth
- `magazine-ui` — customized branch with magazine editorial theme + this agent guide

## Notes

- Flutter SDK must be on PATH (`flutter --version`).
- PowerShell execution policy blocks `npm.ps1` — use `npm.cmd` / `npx.cmd`.
- Worker secrets list: `npx wrangler secret list`.
- Schema is idempotent on re-apply (uses `IF NOT EXISTS`).
- The admin frontend has no tests by default (`vitest run` exits 1).