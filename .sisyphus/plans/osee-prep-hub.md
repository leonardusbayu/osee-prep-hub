# OSEE Prep Hub — Complete Build Plan

## TL;DR

> **Quick Summary**: Build `prep.osee.co.id` — an AI Teaching Assistant platform connecting all OSEE assets (4 practice platforms + EduBot) into one ecosystem. Teachers get free AI tools (grader, generator, reports), invite students via referral codes, earn commission on student actions. **Partners (institutions)** manage multiple teachers and bulk-order tests. Both teachers and partners can order 7 test types (ITP/IBT/IELTS/TOEIC mocks, Tutor Bot premium, Official TOEFL, Official TOEIC) via 4 ordering modes (voucher resale, book for students, bulk purchase, self-purchase) with role-based discounted pricing. 18-week build per blueprint, executed phase-by-phase.
>
> **Deliverables**:
> - Cloudflare Workers + Hono API (hub/worker) with auth, AI, commission, webhooks, reports, syllabus, video, classes, admin, **orders, vouchers, pricing, booking bridge, partner** routes
> - Supabase PostgreSQL schema (full DDL from blueprint Section 4 + **order system tables: pricing_config, orders, order_items, vouchers**) with pgvector for RAG
> - Flutter Web teacher portal + student portal + **partner dashboard** (state: Riverpod, routing: go_router with auth guards, HTTP: dio)
> - React/Vite admin tooling (small, internal, includes **pricing config management**)
> - RAG knowledge base (pgvector + ingestion scripts + retrieval API)
> - Webhook receivers for all 6 platforms (ibt, itp, ielts, toeic, booking, edubot)
> - Commission engine, payout system, ambassador program
> - **Order system: pricing config, 4 ordering modes, voucher generation + redemption, official test booking bridge to osee.co.id**
> - **Partner (institution) dashboard: manage teachers, bulk-order tests, institution-wide stats**
> - Video content system (R2-backed), live class integration
> - EduBot bridge (Phase 5) — links Telegram account to OSEE account, syncs progress
> - Production deployment to Cloudflare Pages + Workers with custom domain prep.osee.co.id
>
> **Estimated Effort**: XL (18-week blueprint, ~80 tasks)
> **Parallel Execution**: YES — 6 waves across 5 phases, 4-task final verification wave
> **Critical Path**: Init → Auth → Webhooks → RAG → AI Grader → Reports → Syllabus → Student Portal → Commission → EduBot Bridge → Deploy

---

## Context

### Original Request
Build OSEE Prep Hub from blueprint at `C:\Users\user\osee-prep-hub-blueprint.md`. Blueprint says: "Implement phase-by-phase. Each phase independently deployable. Do not skip phases. Commit after every task."

### Interview Summary
**Key Discussions**:
- **Plan scope**: Entire blueprint (Phases 1-5, Weeks 1-18, all ~80 tasks) → ONE plan file
- **Project root**: `D:\osee hub` (use as-is, initialize git here)
- **Accounts**: All ready — Supabase, Cloudflare, OpenAI, R2. No account-creation tasks.
- **EduBot repo**: `D:\claude telegram bot` — confirmed real. Worker at `worker/src/` with 29 routes + 101 services matching blueprint. Test framework: vitest.
- **Frontend**: **Flutter Web for teacher/student portals** (deviates from blueprint's React/Vite recommendation). Admin tooling stays as small React/Vite app. Plan defines fresh Flutter architecture (Riverpod + go_router + dio + Material 3).
- **Testing**: Match EduBot's vitest pattern for worker. Use flutter_test for Flutter widgets. Every task also gets agent-executed QA scenarios.

**Research Findings**:
- EduBot worker verified: Hono + TypeScript + vitest. 8 existing test files (tests.test.ts, referral-commission.test.ts, etc.) serve as pattern references.
- Blueprint Section 4: Full Supabase schema SQL (~900 lines of DDL) — copy to schema.sql, run in Supabase.
- Blueprint Section 5: Full API spec with endpoints, request/response shapes.
- Blueprint Section 7: RAG architecture with pgvector, ingestion script structure, retrieval prompts.
- Blueprint Section 9: Commission flow with trigger logic on webhook events.
- Blueprint Section 13: Folder structure (React/Vite) — adapted: `flutter/` for portals, `frontend-admin/` for admin, `worker/` unchanged.

### Metis Review
**Note**: Metis subagent dispatch unavailable (billing). Self-review performed inline. See "Self-Review Gaps" section below.

**Identified Gaps** (addressed):
- Flutter Web vs React/Vite tension: Resolved by splitting — Flutter for portals, React for admin. Blueprint's React-specific tasks (e.g. "@dnd-kit drag-and-drop") interpreted as "build Flutter equivalent" with explicit notes.
- Test infrastructure: Resolved — audit EduBot's vitest setup as first task, replicate for Hub worker.
- Env vars: Resolved — user confirmed accounts ready. Plan assumes secrets set via `wrangler secret put`. Plan includes a `.dev.vars` template task.
- EduBot API contract for bridge tasks: Resolved — executor reads EduBot's actual route files at `D:\claude telegram bot\worker\src\routes\` for contracts.

---

## Work Objectives

### Core Objective
Build a production-deployed AI Teaching Assistant platform at prep.osee.co.id that connects all OSEE assets, provides AI tools to teachers for free, drives student referrals through commission, and bridges with EduBot for unified tutoring.

### Concrete Deliverables
- `worker/` — Cloudflare Workers + Hono API (TypeScript)
- `flutter/` — Flutter Web teacher + student portals
- `frontend-admin/` — React/Vite admin tooling
- `schema.sql` — Supabase PostgreSQL schema (from blueprint Section 4)
- `scripts/` — RAG ingestion, seed data, migration utilities
- Production deployment at prep.osee.co.id

### Definition of Done
- [ ] `wrangler deploy` succeeds for worker
- [ ] `flutter build web` succeeds for portals
- [ ] All API endpoints respond correctly (verified via curl)
- [ ] Auth flow works end-to-end (register → login → SSO cookie → protected route)
- [ ] Webhook receiver accepts and processes events from all 6 platforms
- [ ] AI grader returns graded results for sample essay
- [ ] Commission calculated correctly on webhook events
- [ ] Student portal shows syllabus + progress + deep links to practice platforms
- [ ] EduBot bridge syncs progress bidirectionally
- [ ] prep.osee.co.id accessible with valid SSL

### Must Have
- All 80+ tasks from blueprint Section 12 implemented
- **6 additional order system tasks (15.5-15.10)**: pricing config, order service, teacher order UI, partner dashboard+order, voucher redemption, booking bridge
- Every task committed individually (blueprint mandate)
- Vitest tests for worker code (matching EduBot's pattern)
- Flutter widget tests for portal UIs (teacher, student, **partner**)
- Agent-executed QA scenarios for EVERY task
- Phase-by-phase execution (no skipping phases per blueprint)
- **Partner (institution) role**: register, dashboard, order tests, manage teachers
- **7 orderable item types** with role-based pricing: mock_itp, mock_ibt, mock_ielts, mock_toeic, tutor_bot_premium, official_toefl, official_toeic
- **4 ordering modes**: voucher_resale, book_for_student, bulk_purchase, self_purchase
- **Voucher system**: generation, redemption, cross-platform access granting
- **Official test booking bridge** to osee.co.id

### Must NOT Have (Guardrails)
- **DO NOT modify EduBot repo** (`D:\claude telegram bot`) — only read from it for bridging contracts. No commits there.
- **DO NOT rebuild EduBot's existing services** — bridge to them via HTTP API calls from Hub Workers.
- **DO NOT use React/Vite for teacher/student portals** — Flutter Web only. React/Vite is for admin tooling only.
- **DO NOT skip phases** — blueprint mandate. Phase N must be complete before Phase N+1 starts.
- **DO NOT create separate plan files per phase** — one plan, all 80+ tasks.
- **AI slop to avoid**: excessive JSDoc/comments, over-abstraction (no "BaseManagerFactory"), generic names (data/result/item/temp), premature extraction of utilities, console.log in production code.
- **No `as any` or `@ts-ignore`** in worker code — use proper types.
- **No empty catch blocks** — handle or rethrow.
- **No scope creep**: tasks build exactly what blueprint specifies, nothing more. If a task says "build login page", don't also build password reset flow unless blueprint lists it.

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: NO (new project) — but EduBot has vitest setup to copy
- **Automated tests**: YES (Match EduBot pattern)
- **Framework**: vitest (worker), flutter_test (Flutter portals), vitest (admin React)
- **Pattern**: First task audits `D:\claude telegram bot\worker\vitest.config.ts` + existing `*.test.ts` files, replicates config for Hub worker. Each subsequent task includes test cases following EduBot's patterns.

### QA Policy
Every task MUST include agent-executed QA scenarios.
Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

- **Worker API**: Use Bash (curl) — send requests to local `wrangler dev` endpoint, assert status + response fields
- **Flutter Web UI**: Use Playwright — `flutter build web` → serve → navigate, interact, assert DOM, screenshot
- **Admin React UI**: Use Playwright — `npm run dev` → navigate, interact, assert, screenshot
- **Database**: Use Bash (psql/supabase CLI) — query tables, assert rows/columns/constraints
- **Scripts**: Use Bash (node/tsx) — run script, assert output

---

## Execution Strategy

### Parallel Execution Waves

> Blueprint mandates phase-by-phase execution. Within each phase, tasks are parallelized where dependencies allow. Phases do NOT overlap.

```
Wave 1 — Phase 1A: Foundation (Week 1 — DB + Auth)
├── Task 0.1: Project init + git + scaffolding [quick]
├── Task 0.2: Audit EduBot vitest setup + replicate config [quick]
├── Task 1.1: Supabase schema.sql + run DDL [quick]
├── Task 1.2: Cloudflare Workers project setup (worker/) [quick]
├── Task 1.3: Auth routes (register, login, verify, refresh, logout) [deep]
├── Task 1.4: SSO cookie (domain: .osee.co.id) [quick]
├── Task 1.5: Flutter project init (flutter/) + architecture [deep]
├── Task 1.6: Registration page (Flutter) with referral code [visual-engineering]
├── Task 1.7: Login page (Flutter) [visual-engineering]
├── Task 1.8: Auth guard router (Flutter go_router, role-based) [deep]
└── Task 1.9: Admin React project init (frontend-admin/) [quick]

Wave 2 — Phase 1B: Teacher Portal MVP (Week 2)
├── Task 2.1: Teacher dashboard page (Flutter) [visual-engineering]
├── Task 2.2: Classroom creation + join code generation (worker + Flutter) [deep]
├── Task 2.3: Student registration via referral link (/r/CODE) [deep]
├── Task 2.4: Classroom enrollment system (worker + Flutter) [deep]
├── Task 2.5: OSEE branding widget (Flutter component) [visual-engineering]
└── Task 2.6: Tutor Bot link component (floating CTA) [visual-engineering]

Wave 3 — Phase 1C: Webhook System (Week 3)
├── Task 3.1: Webhook receiver endpoints (6 platforms) [deep]
├── Task 3.2: Webhook event processing pipeline [deep]
├── Task 3.3: Student progress unified table updates [unspecified-high]
├── Task 3.4: Commission trigger on webhook events [deep]
└── Task 3.5: Webhook secret authentication [quick]

Wave 4 — Phase 2A: RAG Knowledge Base (Week 4)
├── Task 4.1: Enable pgvector extension in Supabase [quick]
├── Task 4.2: Document ingestion script [deep]
├── Task 4.3: Ingest Tier 1 materials (CEFR, Kurikulum Merdeka, ETS specs) [unspecified-high]
├── Task 4.4: Ingest EduBot error pattern data [unspecified-high]
├── Task 4.5: Vector search function (match_documents) [deep]
└── Task 4.6: RAG search API endpoint [quick]

Wave 5 — Phase 2B: AI Writing Grader (Week 5)
├── Task 5.1: gradeWriting service (GPT-4o-mini + RAG) [deep]
├── Task 5.2: Grading queue system (pending → processing → completed) [deep]
├── Task 5.3: AI grader UI page (Flutter — upload essay, rubric, results) [visual-engineering]
├── Task 5.4: Quota checking (free: 50/month, pro: unlimited) [unspecified-high]
├── Task 5.5: Store results in ai_grading_queue table [quick]
└── Task 5.6: Bridge to EduBot writing route (alternative path) [deep]

Wave 6 — Phase 2C: AI Material Generator (Week 6)
├── Task 6.1: generateMaterial service (GPT-4o-mini + RAG) [deep]
├── Task 6.2: Generation queue system [deep]
├── Task 6.3: Material generator UI (Flutter — type, exam, level, topic) [visual-engineering]
├── Task 6.4: Content validation pipeline (reuse EduBot's contentValidator pattern) [deep]
├── Task 6.5: Generated material preview + add to syllabus [visual-engineering]
└── Task 6.6: Quota checking (free: 10/month) [quick]

Wave 7 — Phase 2D: AI Speaking Evaluator (Week 7)
├── Task 7.1: Bridge to EduBot speaking evaluation (Whisper + GPT) [deep]
├── Task 7.2: Speaking grader UI (Flutter — record, submit, results) [visual-engineering]
├── Task 7.3: R2 audio upload pipeline [deep]
└── Task 7.4: Quota checking for speaking [quick]

Wave 8 — Phase 3A: Student Reports (Week 8)
├── Task 8.1: Report generation service [deep]
├── Task 8.2: Student report PDF template (teacher branding + OSEE footer) [deep]
├── Task 8.3: Report viewer page (Flutter) [visual-engineering]
├── Task 8.4: Batch report generation (all students in classroom) [unspecified-high]
└── Task 8.5: Report download/email feature [unspecified-high]

Wave 9 — Phase 3B: Classroom Reports (Week 9)
├── Task 9.1: Classroom report aggregation service [deep]
├── Task 9.2: Classroom report PDF template [deep]
├── Task 9.3: Weakness heatmap visualization (Flutter) [visual-engineering]
└── Task 9.4: Teacher effectiveness metrics [deep]

Wave 10 — Phase 3C: Syllabus Builder (Week 10)
├── Task 10.1: Material library component (Flutter — left column) [visual-engineering]
├── Task 10.2: Syllabus timeline component (Flutter — right column) [visual-engineering]
├── Task 10.3: Drag-and-drop implementation (Flutter ReorderableList — blueprint says @dnd-kit which is React; use Flutter equivalent) [deep]
├── Task 10.4: Batch save (PUT syllabus items) [quick]
├── Task 10.5: Material browser from all platforms (via platform bridge API) [deep]
└── Task 10.6: AI-generated materials integration (from Phase 2) [unspecified-high]

Wave 11 — Phase 3D: Student Portal (Week 11)
├── Task 11.1: Student dashboard (syllabus, progress, readiness) [visual-engineering]
├── Task 11.2: Syllabus view page (with deep links to practice platforms) [visual-engineering]
├── Task 11.3: Progress tracking page [visual-engineering]
├── Task 11.4: Readiness gauge component (Flutter) [visual-engineering]
├── Task 11.5: Cross-exam score map component [visual-engineering]
└── Task 11.6: Contextual "Book Official Test" CTA (only when readiness > 80%) [quick]

Wave 12 — Phase 4A: Commission System (Week 12)
├── Task 12.1: Commission dashboard page (Flutter) [visual-engineering]
├── Task 12.2: Payout request system (worker + Flutter) [deep]
├── Task 12.3: Payout tracking (pending → confirmed → paid) [deep]
├── Task 12.4: AI quota bonus system (earn generations by bringing students) [deep]
└── Task 12.5: Ambassador program (2x rates, badge, featured) [unspecified-high]

Wave 13 — Phase 4B: Video Content System (Week 13)
├── Task 13.1: Video course management (admin React) [visual-engineering]
├── Task 13.2: Video lesson player (Flutter — with comprehension quiz overlay) [visual-engineering]
├── Task 13.3: Video progress tracking [deep]
├── Task 13.4: Video course library page (Flutter student) [visual-engineering]
├── Task 13.5: Free preview (YouTube) vs premium (R2) gating [deep]
└── Task 13.6: Teacher assigns video lessons to syllabus [unspecified-high]

Wave 14 — Phase 4C: Live Class Integration (Week 14)
├── Task 14.1: Live class management (admin React form) [visual-engineering]
├── Task 14.2: Upcoming classes page (Flutter student) [visual-engineering]
├── Task 14.3: EduBot integration (Zoom link sharing via Telegram) [deep]
├── Task 14.4: Auto-reminder cron (1 hour before class) [deep]
└── Task 14.5: Post-class recording upload + notification [unspecified-high]

Wave 15 — Phase 4D: White-Label + Pro Tier + Order System (Week 15)
├── Task 15.1: Branding config system [deep]
├── Task 15.2: Pro tier upgrade page + payment (Flutter + TriPay bridge) [deep]
├── Task 15.3: Institution tier (custom subdomain, multi-teacher) [deep]
├── Task 15.4: OSEE branding hide/show logic (free = visible, pro = hideable) [quick]
├── Task 15.5: Pricing config system (admin sets prices per role per test type) [quick]
├── Task 15.6: Order service + API (4 modes, vouchers, TriPay fulfillment) [deep]
├── Task 15.7: Teacher order page (Flutter — 7 items, 4 modes, payment, vouchers) [visual-engineering]
├── Task 15.8: Partner dashboard + order page + teacher management [deep]
├── Task 15.9: Voucher redemption system (cross-platform access granting) [deep]
└── Task 15.10: Official test booking bridge to osee.co.id [deep]

Wave 16 — Phase 5A: EduBot Bridge (Week 16)
├── Task 16.1: Link Telegram account to OSEE account [deep]
├── Task 16.2: EduBot reads student progress from Hub API [deep]
├── Task 16.3: EduBot deep-links students to practice platforms [unspecified-high]
├── Task 16.4: EduBot knows teacher's syllabus → tutors on those topics [deep]
└── Task 16.5: EduBot reports progress back to Hub [deep]

Wave 17 — Phase 5B: Ambassador Program + Launch (Week 17)
├── Task 17.1: Ambassador recruitment page (Flutter) [visual-engineering]
├── Task 17.2: Ambassador dashboard (recruited teachers, bonuses) [visual-engineering]
├── Task 17.3: Teacher proposal document (PDF template) [deep]
├── Task 17.4: Landing page (prep.osee.co.id) [visual-engineering]
└── Task 17.5: SEO optimization (osee.co.id blog integration) [unspecified-high]

Wave 18 — Phase 5C: Polish + Deploy (Week 18)
├── Task 18.1: Error handling + logging (worker-wide) [deep]
├── Task 18.2: Performance optimization (caching, CDN) [deep]
├── Task 18.3: Mobile responsiveness (Flutter Web) [visual-engineering]
├── Task 18.4: Analytics dashboard (admin React) [visual-engineering]
└── Task 18.5: Deploy to production (Cloudflare Pages + Workers + custom domain) [deep]

Wave FINAL (After ALL tasks — 4 parallel reviews, then user okay):
├── Task F1: Plan compliance audit (oracle)
├── Task F2: Code quality review (unspecified-high)
├── Task F3: Real manual QA (unspecified-high)
└── Task F4: Scope fidelity check (deep)
→ Present results → Get explicit user okay

Critical Path: Task 0.1 → 1.1 → 1.3 → 1.4 → 1.8 → 2.2 → 3.1 → 3.4 → 4.1 → 5.1 → 8.1 → 10.3 → 11.1 → 12.2 → 15.5 → 15.6 → 15.8 → 16.1 → 18.5 → F1-F4
Parallel Speedup: ~60% faster than sequential within phases
Max Concurrent: 9 (Wave 1)
```

### Dependency Matrix (abbreviated — full dependencies in each task's "Parallelization" field)

- **0.1, 0.2**: None — start immediately
- **1.1, 1.2, 1.5, 1.9**: Depend on 0.1
- **1.3**: Depends on 1.1, 1.2
- **1.4**: Depends on 1.3
- **1.6, 1.7**: Depend on 1.3, 1.5
- **1.8**: Depends on 1.3, 1.5
- **2.x**: Depend on Phase 1 complete
- **3.x**: Depend on Phase 1 complete (2.x and 3.x can overlap within Phase 1)
- **4.x-7.x**: Depend on Phase 1 complete
- **8.x-11.x**: Depend on Phase 2 complete
- **12.x-15.x**: Depend on Phase 3 complete
- **16.x-18.x**: Depend on Phase 4 complete
- **F1-F4**: Depend on ALL tasks complete

### Agent Dispatch Summary

- **Wave 1 (10 tasks)**: 0.1→`quick`, 0.2→`quick`, 1.1→`quick`, 1.2→`quick`, 1.3→`deep`, 1.4→`quick`, 1.5→`deep`, 1.6→`visual-engineering`, 1.7→`visual-engineering`, 1.8→`deep`, 1.9→`quick`
- **Wave 2 (6 tasks)**: 2.1→`visual-engineering`, 2.2→`deep`, 2.3→`deep`, 2.4→`deep`, 2.5→`visual-engineering`, 2.6→`visual-engineering`
- **Wave 3 (5 tasks)**: 3.1→`deep`, 3.2→`deep`, 3.3→`unspecified-high`, 3.4→`deep`, 3.5→`quick`
- **Wave 4 (6 tasks)**: 4.1→`quick`, 4.2→`deep`, 4.3→`unspecified-high`, 4.4→`unspecified-high`, 4.5→`deep`, 4.6→`quick`
- **Wave 5 (6 tasks)**: 5.1→`deep`, 5.2→`deep`, 5.3→`visual-engineering`, 5.4→`unspecified-high`, 5.5→`quick`, 5.6→`deep`
- **Wave 6 (6 tasks)**: 6.1→`deep`, 6.2→`deep`, 6.3→`visual-engineering`, 6.4→`deep`, 6.5→`visual-engineering`, 6.6→`quick`
- **Wave 7 (4 tasks)**: 7.1→`deep`, 7.2→`visual-engineering`, 7.3→`deep`, 7.4→`quick`
- **Wave 8 (5 tasks)**: 8.1→`deep`, 8.2→`deep`, 8.3→`visual-engineering`, 8.4→`unspecified-high`, 8.5→`unspecified-high`
- **Wave 9 (4 tasks)**: 9.1→`deep`, 9.2→`deep`, 9.3→`visual-engineering`, 9.4→`deep`
- **Wave 10 (6 tasks)**: 10.1→`visual-engineering`, 10.2→`visual-engineering`, 10.3→`deep`, 10.4→`quick`, 10.5→`deep`, 10.6→`unspecified-high`
- **Wave 11 (6 tasks)**: 11.1-11.5→`visual-engineering`, 11.6→`quick`
- **Wave 12 (5 tasks)**: 12.1→`visual-engineering`, 12.2→`deep`, 12.3→`deep`, 12.4→`deep`, 12.5→`unspecified-high`
- **Wave 13 (6 tasks)**: 13.1→`visual-engineering`, 13.2→`visual-engineering`, 13.3→`deep`, 13.4→`visual-engineering`, 13.5→`deep`, 13.6→`unspecified-high`
- **Wave 14 (5 tasks)**: 14.1→`visual-engineering`, 14.2→`visual-engineering`, 14.3→`deep`, 14.4→`deep`, 14.5→`unspecified-high`
- **Wave 15 (10 tasks)**: 15.1→`deep`, 15.2→`deep`, 15.3→`deep`, 15.4→`quick`, 15.5→`quick`, 15.6→`deep`, 15.7→`visual-engineering`, 15.8→`deep`, 15.9→`deep`, 15.10→`deep`
- **Wave 16 (5 tasks)**: 16.1→`deep`, 16.2→`deep`, 16.3→`unspecified-high`, 16.4→`deep`, 16.5→`deep`
- **Wave 17 (5 tasks)**: 17.1→`visual-engineering`, 17.2→`visual-engineering`, 17.3→`deep`, 17.4→`visual-engineering`, 17.5→`unspecified-high`
- **Wave 18 (5 tasks)**: 18.1→`deep`, 18.2→`deep`, 18.3→`visual-engineering`, 18.4→`visual-engineering`, 18.5→`deep`
- **FINAL (4 tasks)**: F1→`oracle`, F2→`unspecified-high`, F3→`unspecified-high`, F4→`deep`

---

## TODOs

- [ ] 0.1. Project initialization + git + scaffolding

  **What to do**:
  - Initialize git repo in `D:\osee hub` (`git init`)
  - Copy blueprint from `C:\Users\user\osee-prep-hub-blueprint.md` to `D:\osee hub\BLUEPRINT.md`
  - Create root `package.json` with workspace config (worker + frontend-admin as workspaces; flutter is separate)
  - Create root `.gitignore` (node_modules, dist, .wrangler, .env, .dev.vars, flutter/build, .sisyphus/evidence)
  - Create root `README.md` with project overview + link to BLUEPRINT.md
  - Create directory structure: `worker/`, `flutter/`, `frontend-admin/`, `scripts/`, `docs/`, `.sisyphus/evidence/`
  - Create `.dev.vars.example` with all env vars from blueprint Section 14 (placeholder values)
  - Create `wrangler.toml` at root (for hub worker — name: osee-prep-hub, compatibility_date, main: worker/src/index.ts)

  **Must NOT do**:
  - Do not install Flutter SDK (assume executor has it or will install)
  - Do not create EduBot symlink or copy EduBot files
  - Do not set real secret values in `.dev.vars.example`

  **Recommended Agent Profile**:
  - **Category**: `quick` — mechanical scaffolding, no business logic
  - **Skills**: [] — no specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 0.2 once dir exists — but 0.1 creates the dir, so 0.2 depends on 0.1)
  - **Parallel Group**: Wave 1 starter
  - **Blocks**: All subsequent tasks (everything needs the repo)
  - **Blocked By**: None

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2627-2720` — Section 13 Folder Structure (adapt: flutter/ instead of frontend/)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2724-2778` — Section 14 Environment Variables (for .dev.vars.example)
  - `D:\claude telegram bot\worker\wrangler.toml` — EduBot's wrangler config as pattern reference

  **WHY Each Reference Matters**:
  - Section 13 defines the target directory structure — adapt React frontend/ to flutter/ + frontend-admin/
  - Section 14 lists every env var the project needs — `.dev.vars.example` must include all of them
  - EduBot's wrangler.toml shows the correct Cloudflare Workers config format for this team's stack

  **Acceptance Criteria**:
  - [ ] `git init` succeeded, repo at `D:\osee hub`
  - [ ] `BLUEPRINT.md` exists in repo root and matches source
  - [ ] Directories exist: worker/, flutter/, frontend-admin/, scripts/, docs/, .sisyphus/evidence/
  - [ ] `.dev.vars.example` contains all env vars from blueprint Section 14
  - [ ] `.gitignore` covers node_modules, .wrangler, .env, .dev.vars, build/, dist/

  **QA Scenarios**:
  ```
  Scenario: Repo structure is correct
    Tool: Bash
    Preconditions: Task 0.1 complete
    Steps:
      1. Run: git status (in D:\osee hub)
      2. Assert: "On branch main" or "No commits yet"
      3. Run: Test-Path worker, flutter, frontend-admin, scripts, docs
      4. Assert: all return True
      5. Run: Test-Path .dev.vars.example, .gitignore, BLUEPRINT.md
      6. Assert: all return True
      7. Run: Get-Content .dev.vars.example | Select-String "SUPABASE_URL"
      8. Assert: match found
    Expected Result: All directories and files exist, git initialized
    Evidence: .sisyphus/evidence/task-0.1-repo-structure.txt

  Scenario: Blueprint is accessible
    Tool: Bash
    Preconditions: Task 0.1 complete
    Steps:
      1. Run: Get-Content BLUEPRINT.md -TotalCount 5
      2. Assert: output contains "OSEE Education Hub" and "Complete Build Blueprint"
    Expected Result: BLUEPRINT.md is the correct blueprint file
    Evidence: .sisyphus/evidence/task-0.1-blueprint-verify.txt
  ```

  **Commit**: YES
  - Message: `task(0.1): initialize project - git, scaffolding, blueprint, env template`
  - Files: all created files
  - Pre-commit: none (no code yet)

- [ ] 0.2. Audit EduBot vitest setup + replicate config for Hub worker

  **What to do**:
  - Read `D:\claude telegram bot\worker\vitest.config.ts` — understand config (test environment, include patterns, coverage settings)
  - Read 2-3 EduBot test files to understand patterns:
    - `D:\claude telegram bot\worker\src\routes\tests.test.ts` — route testing pattern
    - `D:\claude telegram bot\worker\src\services\referral-commission.test.ts` — service testing pattern
    - `D:\claude telegram bot\worker\src\services\user-roles.test.ts` — another service pattern
  - Document findings in `docs/TESTING.md`: framework, config, mocking strategy, assertion style, file naming convention
  - Create `worker/vitest.config.ts` for Hub based on EduBot's config (adapt paths)
  - Create `worker/package.json` with vitest as devDependency (match EduBot's versions: vitest ^4.1.4)
  - Create a smoke test `worker/src/smoke.test.ts` that verifies vitest runs

  **Must NOT do**:
  - Do not modify EduBot repo
  - Do not install dependencies yet (just create package.json)
  - Do not create complex test utilities — keep it minimal, expand per-task

  **Recommended Agent Profile**:
  - **Category**: `quick` — config + documentation, no business logic
  - **Skills**: [] — no specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Parallel Group**: Wave 1 (after 0.1)
  - **Blocks**: All worker tasks (1.2, 1.3, etc. need vitest config)
  - **Blocked By**: 0.1

  **References**:
  - `D:\claude telegram bot\worker\vitest.config.ts` — EduBot's vitest config to replicate
  - `D:\claude telegram bot\worker\package.json` — devDependencies versions to match
  - `D:\claude telegram bot\worker\src\routes\tests.test.ts` — route test pattern
  - `D:\claude telegram bot\worker\src\services\referral-commission.test.ts` — service test pattern
  - `D:\claude telegram bot\worker\src\services\user-roles.test.ts` — service test pattern

  **WHY Each Reference Matters**:
  - vitest.config.ts is the exact config to copy/adapt — shows test environment, include globs, etc.
  - package.json shows which vitest version EduBot uses — match for consistency
  - The 3 test files show HOW EduBot tests routes and services — mocking strategy, assertion style, setup/teardown. Hub tests should follow the same patterns.

  **Acceptance Criteria**:
  - [ ] `docs/TESTING.md` exists with EduBot vitest analysis
  - [ ] `worker/vitest.config.ts` exists and is valid
  - [ ] `worker/package.json` has vitest devDependency matching EduBot's version
  - [ ] `worker/src/smoke.test.ts` exists with a passing test

  **QA Scenarios**:
  ```
  Scenario: Vitest runs successfully in Hub worker
    Tool: Bash
    Preconditions: Task 0.2 complete, npm install run in worker/
    Steps:
      1. cd worker && npm install
      2. Run: npx vitest run
      3. Assert: exit code 0
      4. Assert: output contains "1 passed" or similar
    Expected Result: vitest runs and smoke test passes
    Failure Indicators: vitest not found, config error, 0 tests found
    Evidence: .sisyphus/evidence/task-0.2-vitest-smoke.txt

  Scenario: Testing docs capture EduBot patterns
    Tool: Bash
    Preconditions: Task 0.2 complete
    Steps:
      1. Run: Get-Content docs/TESTING.md
      2. Assert: contains "vitest"
      3. Assert: contains sections on config, mocking, patterns
    Expected Result: TESTING.md is a useful reference for future tasks
    Evidence: .sisyphus/evidence/task-0.2-testing-docs.txt
  ```

  **Commit**: YES
  - Message: `task(0.2): audit EduBot vitest setup, replicate config for Hub worker`
  - Files: docs/TESTING.md, worker/vitest.config.ts, worker/package.json, worker/src/smoke.test.ts
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 1.1. Supabase schema — create schema.sql and run DDL

  **What to do**:
  - Read blueprint Section 4 (lines 337-1236) — full Supabase PostgreSQL schema DDL
  - Create `schema.sql` in repo root with the complete schema from blueprint
  - Add pgvector extension creation at top: `CREATE EXTENSION IF NOT EXISTS vector;`
  - Add uuid extension: `CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`
  - **ADDITION (order system)**: Append these tables to schema.sql (not in blueprint Section 4 — added per user request for ordering system):
    ```sql
    -- Order system tables (added per user request — not in original blueprint)
    CREATE TABLE pricing_config (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      item_type TEXT NOT NULL CHECK (item_type IN ('mock_itp','mock_ibt','mock_ielts','mock_toeic','tutor_bot_premium','official_toefl','official_toeic')),
      role TEXT NOT NULL CHECK (role IN ('student','teacher','partner','admin')),
      price INTEGER NOT NULL,  -- in Rupiah
      is_active BOOLEAN DEFAULT TRUE,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(item_type, role)
    );

    CREATE TABLE orders (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
      order_type TEXT NOT NULL CHECK (order_type IN ('voucher_resale','book_for_student','bulk_purchase','self_purchase')),
      status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','paid','fulfilled','cancelled','refunded')),
      total_amount INTEGER NOT NULL,  -- in Rupiah
      payment_method TEXT,
      payment_ref TEXT,  -- TriPay transaction ref
      notes TEXT,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE order_items (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
      item_type TEXT NOT NULL CHECK (item_type IN ('mock_itp','mock_ibt','mock_ielts','mock_toeic','tutor_bot_premium','official_toefl','official_toeic')),
      quantity INTEGER NOT NULL DEFAULT 1,
      unit_price INTEGER NOT NULL,  -- price at time of order (snapshot)
      assigned_student_id UUID REFERENCES unified_profiles(id),  -- for bulk_purchase: which student
      fulfillment_status TEXT DEFAULT 'pending' CHECK (fulfillment_status IN ('pending','voucher_generated','booking_confirmed','fulfilled','failed')),
      external_booking_id TEXT,  -- for official tests: osee.co.id booking ID
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE TABLE vouchers (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
      code TEXT NOT NULL UNIQUE,  -- unique voucher code for redemption
      item_type TEXT NOT NULL,  -- matches order_items.item_type
      status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','redeemed','expired','cancelled')),
      redeemed_by UUID REFERENCES unified_profiles(id),
      redeemed_at TIMESTAMPTZ,
      expires_at TIMESTAMPTZ,
      platform_webhook_sent BOOLEAN DEFAULT FALSE,  -- track if practice platform was notified
      created_at TIMESTAMPTZ DEFAULT NOW()
    );

    CREATE INDEX idx_orders_user ON orders(user_id);
    CREATE INDEX idx_order_items_order ON order_items(order_id);
    CREATE INDEX idx_vouchers_code ON vouchers(code);
    CREATE INDEX idx_vouchers_status ON vouchers(status);
    ```
  - Run schema.sql against the Supabase project (user confirmed Supabase is ready) via Supabase SQL editor or `psql` connection
  - Verify all tables created by querying `pg_tables`
  - Create a verification script `scripts/verify-schema.ts` that checks all expected tables exist (including new order tables)

  **Must NOT do**:
  - Do not modify the schema from blueprint — copy as-is
  - Do not create RLS policies beyond what blueprint specifies
  - Do not seed data (seed scripts come later in Phase 2)

  **Recommended Agent Profile**:
  - **Category**: `quick` — copy DDL + run it, mechanical
  - **Skills**: [] — no specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.2, 1.5, 1.9 — all depend only on 0.1)
  - **Parallel Group**: Wave 1
  - **Blocks**: 1.3 (auth needs tables), 2.x, 3.x, all DB-dependent tasks
  - **Blocked By**: 0.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:335-1236` — Section 4 Database Schema (full DDL — ~900 lines)
  - `C:\Users\user\osee-prep-hub-blueprint.md:81-94` — Why Cloudflare + Supabase dual backend

  **WHY Each Reference Matters**:
  - Section 4 IS the schema — copy it verbatim into schema.sql. Includes all tables: unified_profiles, classrooms, syllabi, syllabus_items, ai_grading_queue, commission_ledger, webhook_events, student_progress_unified, etc.
  - The dual backend section explains WHY certain tables are in Supabase vs EduBot's D1 — context for not duplicating

  **Acceptance Criteria**:
  - [ ] `schema.sql` exists in repo root with all DDL from blueprint Section 4
  - [ ] `schema.sql` includes `CREATE EXTENSION IF NOT EXISTS vector;` and `uuid-ossp`
  - [ ] `schema.sql` includes order system tables: pricing_config, orders, order_items, vouchers
  - [ ] Schema executed successfully against Supabase project
  - [ ] `scripts/verify-schema.ts` runs and reports all expected tables present
  - [ ] All tables from blueprint exist in Supabase (unified_profiles, classrooms, syllabi, syllabus_items, ai_grading_queue, commission_ledger, webhook_events, student_progress_unified, referral_codes, etc.)
  - [ ] Order system tables exist: pricing_config, orders, order_items, vouchers

  **QA Scenarios**:
  ```
  Scenario: All schema tables exist in Supabase
    Tool: Bash
    Preconditions: schema.sql executed against Supabase
    Steps:
      1. Run: npx tsx scripts/verify-schema.ts
      2. Assert: exit code 0
      3. Assert: output lists all expected tables with "EXISTS" status
      4. Run: psql $DATABASE_URL -c "SELECT tablename FROM pg_tables WHERE schemaname='public' ORDER BY tablename;"
      5. Assert: output includes unified_profiles, classrooms, syllabi, syllabus_items, ai_grading_queue, commission_ledger, webhook_events, pricing_config, orders, order_items, vouchers
    Expected Result: All tables from blueprint + order system exist in Supabase
    Failure Indicators: missing tables, SQL errors on execution
    Evidence: .sisyphus/evidence/task-1.1-schema-tables.txt

  Scenario: pgvector extension is enabled
    Tool: Bash
    Preconditions: schema.sql executed
    Steps:
      1. Run: psql $DATABASE_URL -c "SELECT extname FROM pg_extension WHERE extname='vector';"
      2. Assert: output contains "vector"
    Expected Result: pgvector extension installed (needed for Phase 2 RAG)
    Evidence: .sisyphus/evidence/task-1.1-pgvector.txt
  ```

  **Commit**: YES
  - Message: `task(1.1): create schema.sql from blueprint Section 4, execute against Supabase`
  - Files: schema.sql, scripts/verify-schema.ts
  - Pre-commit: `npx tsx scripts/verify-schema.ts`

- [ ] 1.2. Cloudflare Workers project setup (worker/)

  **What to do**:
  - Create `worker/src/index.ts` — main entry with Hono app, health check route
  - Create `worker/src/types.ts` — TypeScript interfaces (Env bindings for Supabase, JWT, OpenAI, R2, etc.)
  - Create `worker/tsconfig.json` — strict mode, target ES2022, types from @cloudflare/workers-types
  - Create `worker/wrangler.toml` — name: osee-prep-hub, main: src/index.ts, compatibility_date, vars section
  - Create `worker/src/middleware/cors.ts` — CORS middleware for *.osee.co.id origins
  - Create `worker/src/services/supabase.ts` — Supabase client factory using env bindings
  - Create `worker/src/services/jwt.ts` — JWT sign/verify utilities using Web Crypto API
  - Run `wrangler dev` locally and verify health endpoint responds
  - Install dependencies: hono, @cloudflare/workers-types, @supabase/supabase-js, typescript, wrangler

  **Must NOT do**:
  - Do not implement auth routes yet (Task 1.3)
  - Do not hardcode secrets — use env bindings throughout
  - Do not use `any` type — define proper interfaces in types.ts

  **Recommended Agent Profile**:
  - **Category**: `quick` — project scaffolding + boilerplate
  - **Skills**: [] — no specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.1, 1.5, 1.9)
  - **Parallel Group**: Wave 1
  - **Blocks**: 1.3 (auth routes need this), all worker tasks
  - **Blocked By**: 0.1, 0.2 (vitest config)

  **References**:
  - `D:\claude telegram bot\worker\src\index.ts` — EduBot's main entry pattern (Hono app setup, route registration)
  - `D:\claude telegram bot\worker\src\types.ts` — EduBot's type definitions pattern (Env interface)
  - `D:\claude telegram bot\worker\wrangler.toml` — EduBot's wrangler config pattern
  - `D:\claude telegram bot\worker\tsconfig.json` — EduBot's TypeScript config
  - `C:\Users\user\osee-prep-hub-blueprint.md:2638-2678` — Section 13 worker/ folder structure
  - `C:\Users\user\osee-prep-hub-blueprint.md:2724-2778` — Section 14 env vars (for types.ts Env interface)

  **WHY Each Reference Matters**:
  - EduBot's index.ts shows how this team structures a Hono app — route imports, app.use() for middleware, export default app. Copy the pattern.
  - EduBot's types.ts shows the Env interface pattern — bindings for D1, KV, secrets. Adapt for Hub (Supabase, R2 instead of D1).
  - EduBot's wrangler.toml shows correct config format for their Cloudflare setup.
  - Section 13 lists all the route/service files that need to exist eventually — types.ts should cover all env bindings they'll need.
  - Section 14 lists all env vars — types.ts Env interface must include all of them.

  **Acceptance Criteria**:
  - [ ] `worker/src/index.ts` exists with Hono app + `/api/health` route returning `{"status":"ok"}`
  - [ ] `worker/src/types.ts` defines `Env` interface with all bindings from Section 14
  - [ ] `worker/tsconfig.json` exists, strict mode enabled
  - [ ] `worker/wrangler.toml` exists with correct config
  - [ ] `worker/src/middleware/cors.ts` allows *.osee.co.id origins
  - [ ] `worker/src/services/supabase.ts` creates Supabase client from env
  - [ ] `worker/src/services/jwt.ts` has sign() and verify() functions
  - [ ] `npx tsc --noEmit` passes with no errors
  - [ ] `wrangler dev` starts and `curl http://localhost:8787/api/health` returns `{"status":"ok"}`

  **QA Scenarios**:
  ```
  Scenario: Worker starts and health endpoint responds
    Tool: Bash
    Preconditions: Task 1.2 complete, wrangler dev running
    Steps:
      1. cd worker && wrangler dev
      2. Wait 5 seconds for startup
      3. Run: curl http://localhost:8787/api/health
      4. Assert: HTTP 200
      5. Assert: response body contains "ok"
    Expected Result: Health endpoint returns 200 with status ok
    Failure Indicators: wrangler fails to start, 404, connection refused
    Evidence: .sisyphus/evidence/task-1.2-health-check.txt

  Scenario: TypeScript compiles without errors
    Tool: Bash
    Preconditions: Task 1.2 complete
    Steps:
      1. cd worker && npx tsc --noEmit
      2. Assert: exit code 0
      3. Assert: no error output
    Expected Result: Strict TypeScript compiles clean
    Evidence: .sisyphus/evidence/task-1.2-tsc.txt

  Scenario: CORS rejects non-osee origins
    Tool: Bash
    Preconditions: wrangler dev running
    Steps:
      1. Run: curl -H "Origin: https://evil.com" -I http://localhost:8787/api/health
      2. Assert: response does NOT include Access-Control-Allow-Origin: https://evil.com
      3. Run: curl -H "Origin: https://prep.osee.co.id" -I http://localhost:8787/api/health
      4. Assert: response includes Access-Control-Allow-Origin: https://prep.osee.co.id
    Expected Result: CORS allows osee.co.id subdomains, blocks others
    Evidence: .sisyphus/evidence/task-1.2-cors.txt
  ```

  **Commit**: YES
  - Message: `task(1.2): set up Cloudflare Workers project - Hono app, types, supabase+jwt services, CORS`
  - Files: worker/src/index.ts, worker/src/types.ts, worker/tsconfig.json, worker/wrangler.toml, worker/src/middleware/cors.ts, worker/src/services/supabase.ts, worker/src/services/jwt.ts
  - Pre-commit: `cd worker && npx tsc --noEmit`

- [ ] 1.3. Auth routes — register, login, verify, refresh, logout

  **What to do**:
  - Create `worker/src/routes/auth.ts` with Hono routes:
    - `POST /api/auth/register` — accepts {email, password, name, role: teacher|student|partner, referral_code?}. Hashes password (bcrypt or Web Crypto PBKDF2). Creates unified_profiles row. Generates JWT. Sets SSO cookie. Returns {user, token}. Partner role requires institution_name field.
    - `POST /api/auth/login` — accepts {email, password}. Verifies. Generates JWT. Sets cookie. Returns {user, token}.
    - `GET /api/auth/verify` — reads JWT from cookie or Authorization header. Returns {valid: true, user} or 401.
    - `POST /api/auth/refresh` — accepts refresh token, issues new JWT.
    - `POST /api/auth/logout` — clears cookie. Returns 200.
  - Create `worker/src/middleware/auth.ts` — JWT verification middleware, sets `c.set('user', user)` on context
  - Write vitest tests: `worker/src/routes/auth.test.ts` covering register (happy + duplicate email + invalid referral), login (happy + wrong password), verify (valid + expired + no token), logout
  - Register auth routes in `worker/src/index.ts`

  **Must NOT do**:
  - Do not build Flutter UI (Tasks 1.6, 1.7)
  - Do not implement role-based route guards yet (Task 1.8)
  - Do not store plaintext passwords
  - Do not use `as any` for user types

  **Recommended Agent Profile**:
  - **Category**: `deep` — security-critical, multiple endpoints, tests required
  - **Skills**: [] — no specialized skills needed (Hono patterns from EduBot)

  **Parallelization**:
  - **Can Run In Parallel**: NO (needs 1.1 for tables, 1.2 for worker setup)
  - **Parallel Group**: Wave 1
  - **Blocks**: 1.4 (SSO cookie needs auth), 1.6, 1.7 (UI calls these), 1.8 (guard uses verify), 2.x
  - **Blocked By**: 1.1, 1.2, 0.2

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:274-333` — Section 3 Auth flow (SSO across subdomains)
  - `C:\Users\user\osee-prep-hub-blueprint.md:1239-1340` — Section 5 API spec for auth endpoints
  - `D:\claude telegram bot\worker\src\routes\auth.ts` — EduBot's auth route implementation pattern
  - `D:\claude telegram bot\worker\src\services\auth.ts` — EduBot's auth service (password hashing, JWT pattern)
  - `D:\claude telegram bot\worker\src\routes\tests.test.ts` — EduBot's route test pattern

  **WHY Each Reference Matters**:
  - Blueprint Section 3 auth flow shows the SSO cookie strategy (domain: .osee.co.id) and how it integrates across platforms
  - Blueprint Section 5 API spec gives exact request/response shapes for each auth endpoint
  - EduBot's auth.ts shows how this team implements auth in Hono — password hashing library, JWT structure, cookie setting
  - EduBot's auth service shows the service-layer pattern — extract auth logic from routes
  - EduBot's tests.test.ts shows how to test Hono routes with vitest (mock services, make requests, assert responses)

  **Acceptance Criteria**:
  - [ ] All 5 auth endpoints implemented and registered
  - [ ] Password hashing uses PBKDF2 or bcrypt (no plaintext)
  - [ ] JWT contains {sub, email, role, exp, iat}
  - [ ] Auth middleware sets user on context for protected routes
  - [ ] `worker/src/routes/auth.test.ts` passes with ≥5 test cases
  - [ ] Register with referral_code links student to teacher
  - [ ] Duplicate email registration returns 409

  **QA Scenarios**:
  ```
  Scenario: Register a new teacher
    Tool: Bash (curl)
    Preconditions: wrangler dev running, Supabase schema active
    Steps:
      1. curl -X POST http://localhost:8787/api/auth/register -H "Content-Type: application/json" -d '{"email":"teacher@test.com","password":"TestPass123!","name":"Test Teacher","role":"teacher"}'
      2. Assert: HTTP 201
      3. Assert: response contains "token" (JWT string)
      4. Assert: response contains "user" with role "teacher"
      5. Assert: Set-Cookie header present with domain=.osee.co.id
    Expected Result: Teacher registered, JWT issued, cookie set
    Evidence: .sisyphus/evidence/task-1.3-register-teacher.txt

  Scenario: Register student with referral code
    Tool: Bash
    Preconditions: teacher from previous scenario exists
    Steps:
      1. Query Supabase for teacher's referral_code
      2. curl -X POST /api/auth/register -d '{"email":"student@test.com","password":"TestPass123!","name":"Test Student","role":"student","referral_code":"<CODE>"}'
      3. Assert: HTTP 201
      4. Assert: response user.role is "student"
      5. Query Supabase: SELECT referred_by FROM unified_profiles WHERE email='student@test.com'
      6. Assert: referred_by equals teacher's UUID
    Expected Result: Student linked to teacher via referral code
    Evidence: .sisyphus/evidence/task-1.3-register-student-referral.txt

  Scenario: Login with wrong password fails
    Tool: Bash
    Preconditions: teacher@test.com exists
    Steps:
      1. curl -X POST /api/auth/login -d '{"email":"teacher@test.com","password":"WrongPass!"}'
      2. Assert: HTTP 401
      3. Assert: response contains "error"
      4. Assert: no Set-Cookie header
    Expected Result: Invalid credentials rejected, no cookie set
    Evidence: .sisyphus/evidence/task-1.3-login-fail.txt

  Scenario: Verify token returns user
    Tool: Bash
    Preconditions: valid token from register
    Steps:
      1. curl -H "Authorization: Bearer <token>" http://localhost:8787/api/auth/verify
      2. Assert: HTTP 200
      3. Assert: response contains "valid": true and "user" object
    Expected Result: Valid token verified, user returned
    Evidence: .sisyphus/evidence/task-1.3-verify-token.txt
  ```

  **Commit**: YES
  - Message: `task(1.3): implement auth routes - register, login, verify, refresh, logout + middleware`
  - Files: worker/src/routes/auth.ts, worker/src/middleware/auth.ts, worker/src/routes/auth.test.ts, worker/src/index.ts (route registration)
  - Pre-commit: `cd worker && npx vitest run src/routes/auth.test.ts`

- [ ] 1.4. SSO cookie — set cookie domain to .osee.co.id

  **What to do**:
  - Update auth routes (from 1.3) to set cookies with:
    - `domain=.osee.co.id` (shared across all subdomains)
    - `httpOnly=true` (XSS protection)
    - `secure=true` (HTTPS only)
    - `sameSite=Lax` (CSRF protection)
    - `path=/`
    - `maxAge=604800` (7 days matching JWT expiry)
  - Update logout to clear cookie with same domain/path
  - Create `worker/src/services/cookie.ts` — helper to build Set-Cookie header with correct attributes
  - Test: verify cookie attributes in curl response headers

  **Must NOT do**:
  - Do not use sameSite=None (insecure)
  - Do not set domain without leading dot (needs .osee.co.id not osee.co.id)
  - Do not make cookie readable by JavaScript (httpOnly required)

  **Recommended Agent Profile**:
  - **Category**: `quick` — small helper + config change
  - **Skills**: [] — no specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.5, 1.9 — different concerns)
  - **Parallel Group**: Wave 1
  - **Blocks**: 1.6, 1.7 (UI depends on cookie behavior)
  - **Blocked By**: 1.3

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:274-333` — Section 3 Auth flow (SSO cookie spec)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2848` — Cookie domain: .osee.co.id
  - `D:\claude telegram bot\worker\src\routes\auth.ts` — EduBot's cookie setting pattern

  **WHY Each Reference Matters**:
  - Section 3 defines the SSO strategy — cookie must work across all *.osee.co.id subdomains
  - Deployment section confirms cookie domain config
  - EduBot's auth route shows how this team sets cookies in Hono

  **Acceptance Criteria**:
  - [ ] `worker/src/services/cookie.ts` exists with buildCookie helper
  - [ ] Auth routes use cookie helper
  - [ ] Set-Cookie header includes: domain=.osee.co.id; HttpOnly; Secure; SameSite=Lax; Path=/; Max-Age=604800
  - [ ] Logout clears cookie with same domain/path

  **QA Scenarios**:
  ```
  Scenario: Cookie has correct SSO attributes
    Tool: Bash
    Preconditions: wrangler dev running
    Steps:
      1. curl -v -X POST http://localhost:8787/api/auth/login -d '{"email":"teacher@test.com","password":"TestPass123!"}'
      2. Assert: Set-Cookie header present
      3. Assert: cookie contains "Domain=.osee.co.id"
      4. Assert: cookie contains "HttpOnly"
      5. Assert: cookie contains "SameSite=Lax"
      6. Assert: cookie contains "Max-Age=604800"
    Expected Result: Cookie configured for cross-subdomain SSO
    Evidence: .sisyphus/evidence/task-1.4-cookie-attrs.txt

  Scenario: Logout clears cookie
    Tool: Bash
    Preconditions: valid session
    Steps:
      1. curl -v -X POST http://localhost:8787/api/auth/logout -H "Cookie: <session_cookie>"
      2. Assert: Set-Cookie header present
      3. Assert: cookie contains "Max-Age=0" or "Expires=Thu, 01 Jan 1970"
    Expected Result: Cookie invalidated on logout
    Evidence: .sisyphus/evidence/task-1.4-logout-clears.txt
  ```

  **Commit**: YES
  - Message: `task(1.4): set SSO cookie domain .osee.co.id with secure attributes`
  - Files: worker/src/services/cookie.ts, worker/src/routes/auth.ts (update)
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 1.5. Flutter project init — architecture, state, routing, HTTP

  **What to do**:
  - Initialize Flutter project in `flutter/` directory: `flutter create . --project-name osee_prep_hub --platforms web`
  - Set up directory structure under `flutter/lib/`:
    - `main.dart` — app entry, ProviderScope, router config
    - `app/` — app-wide config, theme, constants
    - `core/` — utilities, error handling, constants
    - `features/` — feature modules (auth, teacher, student) each with pages/, widgets/, providers/, models/
    - `shared/` — shared widgets, layouts
  - Install dependencies in `flutter/pubspec.yaml`:
    - `flutter_riverpod` (state management — closest to Zustand)
    - `go_router` (routing with auth guards)
    - `dio` (HTTP client)
    - `json_annotation` + `json_serializable` + `build_runner` (model codegen)
    - `google_fonts` (typography)
  - Create `flutter/lib/app/theme.dart` — Material 3 theme (OSEE brand colors)
  - Create `flutter/lib/core/api_client.dart` — dio instance with baseUrl from env, auth interceptor (attaches JWT from cookie/storage)
  - Create `flutter/lib/core/router.dart` — go_router config with placeholder routes for /login, /register, /teacher, /student, /admin
  - Create `flutter/test/smoke_test.dart` — verify app builds and router initializes
  - Configure `flutter/web/index.html` — title, meta tags for prep.osee.co.id

  **Must NOT do**:
  - Do not build actual pages yet (Tasks 1.6, 1.7)
  - Do not use provider or bloc (Riverpod chosen for Zustand-like ergonomics)
  - Do not hardcode API URL — use environment/config
  - Do not use Flutter's built-in Navigator (use go_router)

  **Recommended Agent Profile**:
  - **Category**: `deep` — architecture decisions, multiple config files, dependency setup
  - **Skills**: [] — Flutter expertise in agent's base capabilities

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.1, 1.2, 1.9 — no dependency)
  - **Parallel Group**: Wave 1
  - **Blocks**: 1.6, 1.7 (pages need this), 1.8 (router), all Flutter UI tasks
  - **Blocked By**: 0.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:1557-1664` — Section 6 Frontend Architecture (React/Vite — adapt concepts to Flutter: state management → Riverpod, routing → go_router, API client → dio)
  - `C:\Users\user\osee-prep-hub-blueprint.md:1665-1745` — Key frontend components (adapt to Flutter widgets)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2680-2701` — Section 13 frontend/ structure (adapt to flutter/lib/)
  - `D:\claude telegram bot\frontend\` — EduBot's React frontend (for understanding the API contract patterns, not for copying code)

  **WHY Each Reference Matters**:
  - Section 6 describes the frontend architecture concepts — state management, routing, API client. Translate these to Flutter equivalents: Zustand→Riverpod, React Router→go_router, fetch→dio.
  - Key components section lists what UI components are needed — adapt to Flutter widget tree.
  - Section 13 folder structure shows the intended organization — adapt to Flutter's lib/ convention.
  - EduBot's frontend shows the API contract — what endpoints the frontend calls, what shapes responses have. The Flutter dio client needs to call the same endpoints.

  **Acceptance Criteria**:
  - [ ] `flutter/pubspec.yaml` exists with all dependencies
  - [ ] `flutter/lib/main.dart` exists with ProviderScope + router
  - [ ] `flutter/lib/core/api_client.dart` exists with dio + auth interceptor
  - [ ] `flutter/lib/core/router.dart` exists with go_router + placeholder routes
  - [ ] `flutter/lib/app/theme.dart` exists with Material 3 theme
  - [ ] `flutter analyze` passes with no issues
  - [ ] `flutter test` passes (smoke test)
  - [ ] `flutter build web --no-tree-shake-icons` succeeds (or `flutter build web`)

  **QA Scenarios**:
  ```
  Scenario: Flutter app builds for web
    Tool: Bash
    Preconditions: Flutter SDK installed, Task 1.5 complete
    Steps:
      1. cd flutter && flutter pub get
      2. Run: flutter analyze
      3. Assert: exit code 0, no issues
      4. Run: flutter build web
      5. Assert: build/web/ directory exists
      6. Assert: build/web/index.html exists
    Expected Result: Flutter Web build produces deployable output
    Evidence: .sisyphus/evidence/task-1.5-flutter-build.txt

  Scenario: Router has all placeholder routes
    Tool: Bash
    Preconditions: Task 1.5 complete
    Steps:
      1. Run: Get-Content flutter/lib/core/router.dart
      2. Assert: contains "/login"
      3. Assert: contains "/register"
      4. Assert: contains "/teacher"
      5. Assert: contains "/student"
    Expected Result: Router configured with all main routes
    Evidence: .sisyphus/evidence/task-1.5-router.txt

  Scenario: Smoke test passes
    Tool: Bash
    Preconditions: Task 1.5 complete
    Steps:
      1. cd flutter && flutter test test/smoke_test.dart
      2. Assert: exit code 0
      3. Assert: "All tests passed"
    Expected Result: Flutter test framework operational
    Evidence: .sisyphus/evidence/task-1.5-smoke-test.txt
  ```

  **Commit**: YES
  - Message: `task(1.5): init Flutter Web project - Riverpod, go_router, dio, Material 3 theme`
  - Files: flutter/ (entire project)
  - Pre-commit: `cd flutter && flutter analyze && flutter test`

- [ ] 1.9. Admin React project init (frontend-admin/)

  **What to do**:
  - Create `frontend-admin/package.json` with React + Vite + TypeScript + Tailwind
  - Create `frontend-admin/vite.config.ts` — Vite config with API proxy to localhost:8787
  - Create `frontend-admin/tsconfig.json` — strict mode
  - Create `frontend-admin/tailwind.config.js` — Tailwind config
  - Create `frontend-admin/index.html` — root HTML
  - Create `frontend-admin/src/main.tsx` — React entry
  - Create `frontend-admin/src/App.tsx` — root component with router (react-router-dom)
  - Create `frontend-admin/src/api/client.ts` — fetch wrapper with auth
  - Create `frontend-admin/src/pages/` — placeholder admin pages (Dashboard, Users, Content, Commission, Analytics)
  - Install dependencies

  **Must NOT do**:
  - Do not build full admin UI (Phase 4 admin tasks)
  - Do not use Flutter for admin (Flutter is for portals only)
  - Do not add complex state management (admin is simple, use React Query or fetch)

  **Recommended Agent Profile**:
  - **Category**: `quick` — standard Vite + React scaffolding
  - **Skills**: [] — no specialized skills needed

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.1, 1.2, 1.5)
  - **Parallel Group**: Wave 1
  - **Blocks**: Phase 4 admin tasks (13.1, 14.1, 18.4)
  - **Blocked By**: 0.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:1557-1664` — Section 6 Frontend Architecture (React/Vite patterns — apply to admin)
  - `D:\claude telegram bot\frontend\` — EduBot's React/Vite frontend as pattern reference
  - `C:\Users\user\osee-prep-hub-blueprint.md:2680-2701` — Section 13 frontend/ structure

  **WHY Each Reference Matters**:
  - Section 6 is React/Vite-specific — admin tooling follows these patterns directly (no Flutter adaptation needed)
  - EduBot's frontend shows this team's React conventions — component structure, API client pattern, styling approach
  - Section 13 structure shows the intended file organization

  **Acceptance Criteria**:
  - [ ] `frontend-admin/package.json` exists with React, Vite, TypeScript, Tailwind, react-router-dom
  - [ ] `frontend-admin/vite.config.ts` proxies /api to localhost:8787
  - [ ] `frontend-admin/src/App.tsx` has router with placeholder admin routes
  - [ ] `frontend-admin/src/api/client.ts` has fetch wrapper
  - [ ] `npm run build` succeeds
  - [ ] `npx tsc --noEmit` passes

  **QA Scenarios**:
  ```
  Scenario: Admin frontend builds
    Tool: Bash
    Preconditions: Task 1.9 complete
    Steps:
      1. cd frontend-admin && npm install
      2. Run: npm run build
      3. Assert: dist/ directory exists
      4. Assert: dist/index.html exists
    Expected Result: Admin React app builds successfully
    Evidence: .sisyphus/evidence/task-1.9-admin-build.txt

  Scenario: Dev server starts
    Tool: Bash
    Preconditions: Task 1.9 complete
    Steps:
      1. cd frontend-admin && npm run dev
      2. Wait 3 seconds
      3. Run: curl http://localhost:5173
      4. Assert: HTML response containing "OSEE" or "admin"
    Expected Result: Admin dev server serves the app
    Evidence: .sisyphus/evidence/task-1.9-admin-dev.txt
  ```

  **Commit**: YES
  - Message: `task(1.9): init admin React/Vite project - Tailwind, router, API client`
  - Files: frontend-admin/ (entire project)
  - Pre-commit: `cd frontend-admin && npm run build`

- [ ] 1.6. Registration page (Flutter) with referral code support

  **What to do**:
  - Create `flutter/lib/features/auth/pages/register_page.dart` — registration form with fields: email, password, confirm password, name, role selector (teacher/student), referral code (optional, pre-filled from URL param)
  - Create `flutter/lib/features/auth/providers/auth_provider.dart` — Riverpod notifier that calls `/api/auth/register`
  - Create `flutter/lib/features/auth/models/user.dart` — User model with json_serializable
  - Form validation: email format, password min 8 chars, password match, name required
  - If role=student and referral code present, show "Referred by: [teacher name]" after validation
  - On success: store JWT, navigate to appropriate dashboard (/teacher or /student)
  - Deep link support: `/r/CODE` route pre-fills referral code (also used by Task 2.3)
  - Write widget test: `flutter/test/features/auth/register_page_test.dart`

  **Must NOT do**:
  - Do not build login page (Task 1.7)
  - Do not build dashboard pages (Phase 2)
  - Do not implement auth guard (Task 1.8)
  - No excessive form fields — only what blueprint specifies

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering` — UI page with form, validation, state
  - **Skills**: [] — Flutter UI is in agent's base capabilities

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.7 — both depend on 1.3 + 1.5, independent pages)
  - **Parallel Group**: Wave 1
  - **Blocks**: 2.3 (referral link uses this page)
  - **Blocked By**: 1.3 (auth API), 1.5 (Flutter project)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2481` — Task 1.5: Build registration page with referral code support
  - `C:\Users\user\osee-prep-hub-blueprint.md:1239-1340` — Section 5 API spec for register endpoint
  - `C:\Users\user\osee-prep-hub-blueprint.md:2488` — Task 2.3: Student registration via referral link (/r/CODE)

  **WHY Each Reference Matters**:
  - Blueprint Task 1.5 defines what the page must do
  - API spec gives the exact request shape for /api/auth/register
  - Task 2.3 shows the /r/CODE deep link pattern — registration page must accept referral code from URL

  **Acceptance Criteria**:
  - [ ] Register page renders with all fields
  - [ ] Form validation prevents invalid submissions
  - [ ] Role selector switches between teacher/student
  - [ ] Referral code field accepts URL param pre-fill
  - [ ] On success, navigates to dashboard route
  - [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Register page renders all fields
    Tool: Playwright (Flutter Web build)
    Preconditions: flutter build web complete, serving on localhost:8080
    Steps:
      1. Navigate to http://localhost:8080/#/register
      2. Assert: page contains "Register" heading
      3. Assert: input fields for email, password, name visible
      4. Assert: role selector with "Teacher" and "Student" options
      5. Assert: referral code field visible (optional)
      6. Screenshot: .sisyphus/evidence/task-1.6-register-page.png
    Expected Result: All form elements visible and correctly laid out
    Evidence: .sisyphus/evidence/task-1.6-register-page.png

  Scenario: Form validation blocks invalid input
    Tool: Playwright
    Preconditions: register page loaded
    Steps:
      1. Click "Register" button without filling fields
      2. Assert: validation error messages appear for required fields
      3. Enter "invalid-email" in email field, click Register
      4. Assert: email format error message
      5. Enter "short" in password field
      6. Assert: password length error
    Expected Result: Form prevents submission with invalid data
    Evidence: .sisyphus/evidence/task-1.6-validation.png

  Scenario: Referral code pre-fill from URL
    Tool: Playwright
    Preconditions: register page loaded
    Steps:
      1. Navigate to http://localhost:8080/#/register?ref=ABC123
      2. Assert: referral code field contains "ABC123"
    Expected Result: Deep link pre-fills referral code
    Evidence: .sisyphus/evidence/task-1.6-referral-prefill.png
  ```

  **Commit**: YES
  - Message: `task(1.6): build Flutter registration page with referral code support`
  - Files: flutter/lib/features/auth/ (pages, providers, models), flutter/test/features/auth/register_page_test.dart
  - Pre-commit: `cd flutter && flutter test`

- [ ] 1.7. Login page (Flutter)

  **What to do**:
  - Create `flutter/lib/features/auth/pages/login_page.dart` — login form with: email, password, "Login" button, "Register" link
  - Use same auth_provider as register (Task 1.6) — add login method to notifier
  - Form validation: email format, password required
  - On success: store JWT, navigate to dashboard based on role
  - Error display: show error message on failed login
  - Write widget test: `flutter/test/features/auth/login_page_test.dart`

  **Must NOT do**:
  - Do not build password reset (not in blueprint)
  - Do not build "remember me" (not in blueprint)
  - Do not build OAuth (not in blueprint)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering` — UI page
  - **Skills**: [] — Flutter UI

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 1.6 — independent pages)
  - **Parallel Group**: Wave 1
  - **Blocks**: None directly
  - **Blocked By**: 1.3 (auth API), 1.5 (Flutter project)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2482` — Task 1.6: Build login page
  - `C:\Users\user\osee-prep-hub-blueprint.md:1239-1340` — Section 5 API spec for login endpoint

  **WHY Each Reference Matters**:
  - Blueprint Task 1.6 defines login page requirement
  - API spec gives exact login endpoint request/response

  **Acceptance Criteria**:
  - [ ] Login page renders with email, password, submit button, register link
  - [ ] Form validation works
  - [ ] On success, navigates to dashboard
  - [ ] On failure, shows error message
  - [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Login page renders
    Tool: Playwright
    Preconditions: flutter build web, serving
    Steps:
      1. Navigate to http://localhost:8080/#/login
      2. Assert: "Login" heading visible
      3. Assert: email and password fields visible
      4. Assert: "Login" button visible
      5. Assert: link/text to register page
      6. Screenshot
    Expected Result: Login form fully rendered
    Evidence: .sisyphus/evidence/task-1.7-login-page.png

  Scenario: Login failure shows error
    Tool: Playwright
    Preconditions: login page loaded
    Steps:
      1. Enter "nonexistent@test.com" in email
      2. Enter "wrongpass" in password
      3. Click Login button
      4. Assert: error message appears (e.g. "Invalid credentials")
      5. Assert: still on login page (not navigated away)
    Expected Result: Failed login shows error, stays on page
    Evidence: .sisyphus/evidence/task-1.7-login-fail.png
  ```

  **Commit**: YES
  - Message: `task(1.7): build Flutter login page`
  - Files: flutter/lib/features/auth/pages/login_page.dart, flutter/test/features/auth/login_page_test.dart
  - Pre-commit: `cd flutter && flutter test`

- [ ] 1.8. Auth guard router — role-based routing (Flutter go_router)

  **What to do**:
  - Update `flutter/lib/core/router.dart` with go_router redirect logic:
    - If not authenticated and route is protected → redirect to /login
    - If authenticated and route is /login or /register → redirect to dashboard
    - If role=teacher and route is /student/* → redirect to /teacher
    - If role=student and route is /teacher/* → redirect to /student
    - If role=partner and route is /teacher/* or /student/* → redirect to /partner
    - If role=teacher and route is /partner/* → redirect to /teacher (unless also has partner privileges)
    - If role=admin and route is /admin/* → allow
  - Add `/partner/*` route group to router for partner dashboard, orders, teachers management
  - Create `flutter/lib/features/auth/providers/auth_state_provider.dart` — Riverpod provider tracking: isAuthenticated, currentUser, role
  - Create auth state persistence: store JWT in localStorage (web) via shared_preferences or secure_storage
  - On app start: check stored JWT, call /api/auth/verify, hydrate auth state
  - Write widget test for redirect logic

  **Must NOT do**:
  - Do not implement admin portal UI (Phase 4)
  - Do not build dashboard pages (just route to placeholders that say "Teacher Dashboard" etc.)
  - Do not store JWT in plain localStorage without considering XSS (Flutter Web is in iframe-like context; use httponly cookie if possible, fallback to localStorage with note)

  **Recommended Agent Profile**:
  - **Category**: `deep` — routing logic, state management, security
  - **Skills**: [] — Flutter + Riverpod expertise in agent capabilities

  **Parallelization**:
  - **Can Run In Parallel**: NO (needs 1.3 for verify endpoint, 1.5 for router, 1.6/1.7 for auth pages)
  - **Parallel Group**: Wave 1 (last task of wave)
  - **Blocks**: All portal pages (2.1, 2.2, etc. rely on router working)
  - **Blocked By**: 1.3, 1.5, 1.6, 1.7

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2483` — Task 1.7: auth guard router (role-based: teacher/student/admin)
  - `C:\Users\user\osee-prep-hub-blueprint.md:274-333` — Section 3 auth flow
  - go_router docs: https://pub.dev/documentation/go_router/latest/ (redirect function)

  **WHY Each Reference Matters**:
  - Blueprint Task 1.7 defines the requirement — role-based guard
  - Section 3 auth flow shows how auth state should work across the app
  - go_router docs show how to implement redirect callbacks for auth guards

  **Acceptance Criteria**:
  - [ ] go_router redirect logic handles all cases (unauthenticated, wrong role, authenticated visiting login)
  - [ ] Auth state provider tracks isAuthenticated, currentUser, role
  - [ ] JWT persisted across page reloads
  - [ ] On app start, verify endpoint called to hydrate state
  - [ ] Widget test covers: unauthenticated → /login redirect, teacher accessing /student → redirect, expired token → /login

  **QA Scenarios**:
  ```
  Scenario: Unauthenticated user redirected to login
    Tool: Playwright
    Preconditions: flutter build web, serving, no stored JWT
    Steps:
      1. Navigate to http://localhost:8080/#/teacher
      2. Assert: URL changes to /#/login
      3. Assert: login page visible
    Expected Result: Protected routes redirect unauthenticated users
    Evidence: .sisyphus/evidence/task-1.8-redirect-unauth.png

  Scenario: Teacher redirected from student route
    Tool: Playwright
    Preconditions: logged in as teacher (JWT stored)
    Steps:
      1. Navigate to http://localhost:8080/#/student
      2. Assert: URL changes to /#/teacher
    Expected Result: Role mismatch redirect works
    Evidence: .sisyphus/evidence/task-1.8-role-redirect.png

  Scenario: Authenticated user redirected from login
    Tool: Playwright
    Preconditions: logged in as teacher
    Steps:
      1. Navigate to http://localhost:8080/#/login
      2. Assert: URL changes to /#/teacher
    Expected Result: No login page for authenticated users
    Evidence: .sisyphus/evidence/task-1.8-auth-redirect.png
  ```

  **Commit**: YES
  - Message: `task(1.8): implement role-based auth guard router with go_router redirect logic`
  - Files: flutter/lib/core/router.dart (update), flutter/lib/features/auth/providers/auth_state_provider.dart, flutter/test/features/auth/auth_guard_test.dart
  - Pre-commit: `cd flutter && flutter test`

- [ ] 2.1. Teacher dashboard page (Flutter)

  **What to do**:
  - Create `flutter/lib/features/teacher/pages/teacher_dashboard_page.dart` — stats overview:
    - Total students (count from classrooms)
    - Active classrooms (count)
    - Commission earned this month (sum from commission_ledger)
    - AI credits remaining (quota from user record)
    - Recent activity feed (latest webhook events for their students)
    - **Order section**: quick link to order mock tests + official tests (link to /teacher/orders from Task 15.7)
    - **Voucher stats**: vouchers purchased, redeemed, active (count from vouchers table)
  - Create `worker/src/routes/teacher.ts` — GET /api/teacher/dashboard endpoint returning aggregated stats
  - Create `flutter/lib/features/teacher/providers/dashboard_provider.dart` — Riverpod notifier fetching stats
  - Create `flutter/lib/features/teacher/models/dashboard_stats.dart` — stats model
  - Write vitest test for the dashboard API endpoint
  - Write widget test for the dashboard page

  **Must NOT do**:
  - Do not build classroom management UI (Task 2.2)
  - Do not build commission dashboard (Task 12.1)
  - Do not show student list (that's classroom detail, not dashboard)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering` — Flutter UI + worker API
  - **Skills**: [] — standard full-stack

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 2.5, 2.6 — independent components)
  - **Parallel Group**: Wave 2
  - **Blocks**: None directly
  - **Blocked By**: 1.8 (router), Phase 1A complete

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2486` — Task 2.1: Teacher dashboard page (stats overview)
  - `C:\Users\user\osee-prep-hub-blueprint.md:1239-1554` — Section 5 API spec (teacher endpoints)
  - `D:\claude telegram bot\worker\src\routes\` — EduBot route patterns

  **WHY Each Reference Matters**:
  - Blueprint Task 2.1 defines the dashboard requirement
  - API spec gives response shapes for teacher endpoints
  - EduBot routes show this team's Hono route patterns

  **Acceptance Criteria**:
  - [ ] Teacher dashboard renders with 4 stat cards + activity feed
  - [ ] GET /api/teacher/dashboard returns correct aggregated data
  - [ ] Stats are real (queried from Supabase, not hardcoded)
  - [ ] Vitest test passes for API endpoint
  - [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Dashboard shows real stats
    Tool: Playwright + Bash
    Preconditions: teacher logged in, has 1 classroom with 3 students, some commission entries
    Steps:
      1. curl -H "Authorization: Bearer <token>" http://localhost:8787/api/teacher/dashboard
      2. Assert: JSON with totalStudents=3, activeClassrooms=1, commissionThisMonth>0
      3. Navigate Flutter to /teacher
      4. Assert: "3" appears (student count)
      5. Assert: "1" appears (classroom count)
      6. Screenshot
    Expected Result: Dashboard reflects real database data
    Evidence: .sisyphus/evidence/task-2.1-dashboard-stats.png, task-2.1-api-response.txt

  Scenario: Empty state when no data
    Tool: Playwright
    Preconditions: new teacher, no classrooms, no students
    Steps:
      1. Navigate to /teacher
      2. Assert: "0" for student count
      3. Assert: "0" for classroom count
      4. Assert: "Rp 0" for commission
      5. Assert: no crash, empty activity feed shows placeholder text
    Expected Result: Empty state handled gracefully
    Evidence: .sisyphus/evidence/task-2.1-empty-state.png
  ```

  **Commit**: YES
  - Message: `task(2.1): build teacher dashboard page with stats overview + API endpoint`
  - Files: flutter/lib/features/teacher/pages/teacher_dashboard_page.dart, flutter/lib/features/teacher/providers/dashboard_provider.dart, flutter/lib/features/teacher/models/dashboard_stats.dart, worker/src/routes/teacher.ts, worker/src/routes/teacher.test.ts
  - Pre-commit: `cd worker && npx vitest run && cd ../flutter && flutter test`

- [ ] 2.2. Classroom creation + join code generation

  **What to do**:
  - Add to `worker/src/routes/teacher.ts`:
    - `POST /api/teacher/classrooms` — create classroom (name, description), generate unique 6-char join code, return classroom
    - `GET /api/teacher/classrooms` — list teacher's classrooms
    - `GET /api/teacher/classrooms/:id` — classroom detail with enrolled students
  - Create `worker/src/services/classroom.ts` — classroom service: createClassroom, generateJoinCode (6 random alphanumeric chars, collision-checked), getClassrooms, getClassroomById
  - Generate referral_code for teacher on registration if not already (update auth route or add to classroom service)
  - Create `flutter/lib/features/teacher/pages/classroom_create_page.dart` — form to create classroom
  - Create `flutter/lib/features/teacher/pages/classroom_list_page.dart` — list of classrooms with join codes
  - Write vitest tests for classroom service and routes
  - Write widget tests

  **Must NOT do**:
  - Do not build enrollment UI (Task 2.4)
  - Do not build student-side classroom view
  - Join code must be unique — check for collisions

  **Recommended Agent Profile**:
  - **Category**: `deep` — worker service + routes + Flutter pages + tests
  - **Skills**: [] — standard full-stack

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 2.5, 2.6)
  - **Parallel Group**: Wave 2
  - **Blocks**: 2.4 (enrollment needs classrooms to exist)
  - **Blocked By**: Phase 1A complete

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2487` — Task 2.2: Classroom creation + join code generation
  - `C:\Users\user\osee-prep-hub-blueprint.md:335-1236` — Section 4 schema (classrooms table, referral_codes table)
  - `D:\claude telegram bot\worker\src\services\classroom.ts` — EduBot's classroom service (pattern reference)
  - `D:\claude telegram bot\worker\src\routes\classes.ts` — EduBot's classes routes

  **WHY Each Reference Matters**:
  - Blueprint task defines requirement
  - Schema shows classrooms table structure (id, teacher_id, name, join_code, etc.)
  - EduBot's classroom service shows how this team implements classroom logic — adapt patterns but for Supabase instead of D1

  **Acceptance Criteria**:
  - [ ] POST /api/teacher/classrooms creates classroom with unique 6-char join code
  - [ ] GET /api/teacher/classrooms returns teacher's classrooms
  - [ ] GET /api/teacher/classrooms/:id returns detail with students
  - [ ] Join codes are unique (collision check)
  - [ ] Flutter create + list pages work
  - [ ] Vitest + widget tests pass

  **QA Scenarios**:
  ```
  Scenario: Create classroom and get join code
    Tool: Bash
    Preconditions: teacher logged in
    Steps:
      1. curl -X POST /api/teacher/classrooms -d '{"name":"Class 10A","description":"Grade 10 English"}'
      2. Assert: HTTP 201
      3. Assert: response contains "join_code" (6 alphanumeric chars)
      4. curl /api/teacher/classrooms
      5. Assert: response array contains the new classroom
    Expected Result: Classroom created with unique join code
    Evidence: .sisyphus/evidence/task-2.2-create-classroom.txt

  Scenario: Join code uniqueness
    Tool: Bash
    Preconditions: existing classrooms with join codes
    Steps:
      1. Create 10 classrooms
      2. Query: SELECT join_code FROM classrooms WHERE teacher_id='<id>'
      3. Assert: all 10 codes are unique (no duplicates)
    Expected Result: No join code collisions
    Evidence: .sisyphus/evidence/task-2.2-unique-codes.txt
  ```

  **Commit**: YES
  - Message: `task(2.2): classroom creation + join code generation (worker + Flutter)`
  - Files: worker/src/routes/teacher.ts (update), worker/src/services/classroom.ts, worker/src/routes/teacher.test.ts (update), flutter/lib/features/teacher/pages/classroom_create_page.dart, flutter/lib/features/teacher/pages/classroom_list_page.dart
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 2.3. Student registration via referral link (/r/CODE)

  **What to do**:
  - Add route in Flutter router: `/r/:code` → redirects to /register with referral code pre-filled
  - Update register_page (from 1.6) to handle deep link referral
  - Add to `worker/src/routes/auth.ts`: validate referral code on register — check code exists in referral_codes table, link student to teacher
  - Create `worker/src/services/referral.ts` — validateReferralCode, linkStudentToTeacher
  - Write tests for referral validation (valid code, invalid code, self-referral prevention)

  **Must NOT do**:
  - Do not build referral dashboard (Task 12.1)
  - Do not allow self-referral (teacher referring themselves)
  - Do not allow referral to non-existent teacher

  **Recommended Agent Profile**:
  - **Category**: `deep` — routing + auth integration + validation logic
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 2.5, 2.6)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: 1.6 (register page), Phase 1A

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2488` — Task 2.3: Student registration via referral link (/r/CODE)
  - `C:\Users\user\osee-prep-hub-blueprint.md:36-46` — Viral loop (referral flow)
  - `D:\claude telegram bot\worker\src\services\referral-commission.ts` — EduBot's referral logic

  **WHY Each Reference Matters**:
  - Blueprint task defines /r/CODE route
  - Viral loop shows the referral flow in context
  - EduBot's referral service shows how this team handles referral logic — adapt for Hub

  **Acceptance Criteria**:
  - [ ] `/r/:code` route pre-fills referral code on register page
  - [ ] Invalid referral code shows error
  - [ ] Self-referral prevented
  - [ ] Valid referral links student to teacher (referred_by set in unified_profiles)
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Referral link redirects to register with code
    Tool: Playwright
    Preconditions: teacher with referral code "ABC123" exists
    Steps:
      1. Navigate to http://localhost:8080/#/r/ABC123
      2. Assert: URL is /#/register?ref=ABC123
      3. Assert: referral code field contains "ABC123"
    Expected Result: Deep link works
    Evidence: .sisyphus/evidence/task-2.3-referral-link.png

  Scenario: Invalid referral code rejected
    Tool: Bash
    Preconditions: wrangler dev running
    Steps:
      1. curl -X POST /api/auth/register -d '{"email":"new@test.com","password":"Pass123!","name":"New","role":"student","referral_code":"INVALID"}'
      2. Assert: HTTP 400 or 404
      3. Assert: error message about invalid referral code
    Expected Result: Invalid referral code rejected at API
    Evidence: .sisyphus/evidence/task-2.3-invalid-referral.txt
  ```

  **Commit**: YES
  - Message: `task(2.3): student registration via referral link /r/CODE with validation`
  - Files: flutter/lib/core/router.dart (update), worker/src/routes/auth.ts (update), worker/src/services/referral.ts, worker/src/routes/auth.test.ts (update)
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 2.4. Classroom enrollment system

  **What to do**:
  - Add to `worker/src/routes/student.ts` (create if not exists):
    - `POST /api/student/classrooms/join` — accept join_code, enroll student in classroom
    - `GET /api/student/classrooms` — list student's enrolled classrooms
  - Add to `worker/src/services/classroom.ts`: enrollStudent, getStudentClassrooms
  - Prevent duplicate enrollment (student can't join same classroom twice)
  - Create `flutter/lib/features/student/pages/classroom_join_page.dart` — form to enter join code
  - Create `flutter/lib/features/student/pages/my_classrooms_page.dart` — list of enrolled classrooms
  - Write tests

  **Must NOT do**:
  - Do not build teacher-side enrollment view (Task 2.2 already lists students in classroom detail)
  - Do not allow teacher to join classrooms as student

  **Recommended Agent Profile**:
  - **Category**: `deep` — worker + Flutter + enrollment logic
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 2.5, 2.6)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: 2.2 (classrooms must exist to join)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2489` — Task 2.4: Classroom enrollment system
  - `C:\Users\user\osee-prep-hub-blueprint.md:335-1236` — Section 4 schema (classroom_enrollments table)
  - `D:\claude telegram bot\worker\src\services\classroom.ts` — EduBot's classroom patterns

  **Acceptance Criteria**:
  - [ ] POST /api/student/classrooms/join enrolls student via join code
  - [ ] Duplicate enrollment returns 409
  - [ ] GET /api/student/classrooms returns enrolled classrooms
  - [ ] Flutter join + list pages work
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Student joins classroom with code
    Tool: Bash
    Preconditions: student logged in, classroom with code "XYZ789" exists
    Steps:
      1. curl -X POST /api/student/classrooms/join -d '{"join_code":"XYZ789"}'
      2. Assert: HTTP 201
      3. curl /api/student/classrooms
      4. Assert: response contains classroom with code XYZ789
    Expected Result: Student enrolled successfully
    Evidence: .sisyphus/evidence/task-2.4-join.txt

  Scenario: Duplicate enrollment blocked
    Tool: Bash
    Preconditions: student already enrolled in classroom
    Steps:
      1. curl -X POST /api/student/classrooms/join -d '{"join_code":"XYZ789"}'
      2. Assert: HTTP 409
      3. Assert: error "already enrolled"
    Expected Result: No duplicate enrollments
    Evidence: .sisyphus/evidence/task-2.4-duplicate.txt
  ```

  **Commit**: YES
  - Message: `task(2.4): classroom enrollment system - join via code, list enrolled`
  - Files: worker/src/routes/student.ts, worker/src/services/classroom.ts (update), worker/src/routes/student.test.ts, flutter/lib/features/student/pages/classroom_join_page.dart, flutter/lib/features/student/pages/my_classrooms_page.dart
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 2.5. OSEE branding widget component (Flutter)

  **What to do**:
  - Create `flutter/lib/shared/widgets/osee_branding_widget.dart` — reusable widget showing OSEE logo + tagline "Powered by OSEE Education Hub"
  - Configure: visible by default, hideable if branding config says hide (for Pro tier — Task 15.4)
  - Add widget to student portal pages (footer or corner)
  - Logo asset: create `flutter/assets/images/osee-logo.png` (placeholder if no logo provided — use text "OSEE" styled)
  - Make widget responsive (small on mobile, full on desktop)

  **Must NOT do**:
  - Do not hardcode visibility — read from branding config (or default to visible)
  - Do not make it intrusive (no popups, no blocking)

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering` — UI component
  - **Skills**: [] — Flutter UI

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 2.1-2.4, 2.6)
  - **Parallel Group**: Wave 2
  - **Blocks**: 15.4 (branding hide/show uses this widget)
  - **Blocked By**: 1.5 (Flutter project)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2490` — Task 2.5: OSEE branding widget component
  - `C:\Users\user\osee-prep-hub-blueprint.md:41-46` — Viral loop (student sees OSEE branding)

  **Acceptance Criteria**:
  - [ ] Branding widget renders OSEE logo + tagline
  - [ ] Widget is reusable across pages
  - [ ] Widget respects visibility config (default visible)
  - [ ] Widget is responsive

  **QA Scenarios**:
  ```
  Scenario: Branding widget renders
    Tool: Playwright
    Preconditions: any student page loaded
    Steps:
      1. Navigate to /student
      2. Assert: page contains "OSEE" or "Powered by OSEE"
      3. Screenshot
    Expected Result: Branding visible on student pages
    Evidence: .sisyphus/evidence/task-2.5-branding.png
  ```

  **Commit**: YES
  - Message: `task(2.5): OSEE branding widget component (Flutter)`
  - Files: flutter/lib/shared/widgets/osee_branding_widget.dart, flutter/assets/ (logo placeholder)
  - Pre-commit: `cd flutter && flutter analyze`

- [ ] 2.6. Tutor Bot link component (floating CTA)

  **What to do**:
  - Create `flutter/lib/shared/widgets/tutor_bot_fab.dart` — floating action button linking to Telegram EduBot
  - Button shows "Ask Tutor Bot" or chat icon
  - On click: opens https://t.me/osee_edubot (from VITE_EDUBOT_URL equivalent in Flutter env)
  - Position: bottom-right, above branding widget
  - Only visible to students (not teachers)
  - Smooth animation on appear

  **Must NOT do**:
  - Do not embed Telegram widget (just link out)
  - Do not show to teachers

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering` — UI component with animation
  - **Skills**: [] — Flutter UI

  **Parallelization**:
  - **Can Run In Parallel**: YES (with all 2.x)
  - **Parallel Group**: Wave 2
  - **Blocks**: None
  - **Blocked By**: 1.5

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2491` — Task 2.6: Tutor Bot link component (floating CTA)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2784` — VITE_EDUBOT_URL=https://t.me/osee_edubot

  **Acceptance Criteria**:
  - [ ] FAB renders on student pages
  - [ ] FAB not visible on teacher pages
  - [ ] Click opens t.me/osee_edubot
  - [ ] Animation smooth

  **QA Scenarios**:
  ```
  Scenario: FAB visible to students
    Tool: Playwright
    Preconditions: student logged in
    Steps:
      1. Navigate to /student
      2. Assert: floating button visible (bottom-right area)
      3. Assert: button has "Tutor" or chat icon text
    Expected Result: FAB present for students
    Evidence: .sisyphus/evidence/task-2.6-fab-student.png

  Scenario: FAB hidden from teachers
    Tool: Playwright
    Preconditions: teacher logged in
    Steps:
      1. Navigate to /teacher
      2. Assert: no floating tutor button visible
    Expected Result: FAB not shown to teachers
    Evidence: .sisyphus/evidence/task-2.6-fab-teacher.png
  ```

  **Commit**: YES
  - Message: `task(2.6): Tutor Bot floating CTA component (student-only)`
  - Files: flutter/lib/shared/widgets/tutor_bot_fab.dart
  - Pre-commit: `cd flutter && flutter analyze`

- [ ] 3.1. Webhook receiver endpoints (6 platforms)

  **What to do**:
  - Create `worker/src/routes/webhook.ts` with 6 POST endpoints:
    - `POST /api/webhook/ibt` — from ibt.osee.co.id (TOEFL iBT practice)
    - `POST /api/webhook/itp` — from test.osee.co.id (TOEFL ITP)
    - `POST /api/webhook/ielts` — from ielts.osee.co.id
    - `POST /api/webhook/toeic` — from toeic.osee.co.id
    - `POST /api/webhook/booking` — from osee.co.id (test booking)
    - `POST /api/webhook/edubot` — from EduBot
  - Each endpoint: verify secret (Task 3.5), parse event, store in webhook_events table, queue for processing
  - Define event payload schema in `worker/src/types.ts`: WebhookEvent { platform, event_type, student_id, timestamp, data }
  - Expected event types: practice_completed, test_booked, test_completed, bot_session_started
  - Write vitest tests for each endpoint with mock payloads

  **Must NOT do**:
  - Do not process events in this task (Task 3.2 handles processing)
  - Do not skip secret verification
  - Do not accept unstructured payloads — enforce schema

  **Recommended Agent Profile**:
  - **Category**: `deep` — 6 endpoints, payload validation, security
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: NO (3.2-3.5 depend on these endpoints existing)
  - **Parallel Group**: Wave 3
  - **Blocks**: 3.2 (processing pipeline), 3.3 (progress updates), 3.4 (commission triggers)
  - **Blocked By**: Phase 1B complete (auth for secret auth), 1.1 (webhook_events table)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2494` — Task 3.1: Webhook receiver endpoints
  - `C:\Users\user\osee-prep-hub-blueprint.md:299-333` — Section 3 Webhook flow
  - `C:\Users\user\osee-prep-hub-blueprint.md:335-1236` — Section 4 schema (webhook_events table)

  **WHY Each Reference Matters**:
  - Blueprint task lists all 6 platforms
  - Section 3 webhook flow shows the architecture: platform → webhook → process → update tables → trigger commission
  - Schema shows webhook_events table structure (id, platform, event_type, payload, processed, created_at)

  **Acceptance Criteria**:
  - [ ] All 6 endpoints accept POST and validate payload schema
  - [ ] Invalid payload returns 400 with error details
  - [ ] Valid payload stored in webhook_events table with processed=false
  - [ ] Each endpoint returns 202 Accepted (async processing)
  - [ ] Vitest tests cover all 6 endpoints + invalid payload cases

  **QA Scenarios**:
  ```
  Scenario: IBT webhook accepts practice_completed event
    Tool: Bash
    Preconditions: wrangler dev running, WEBHOOK_SECRET_IBT set
    Steps:
      1. curl -X POST /api/webhook/ibt -H "X-Webhook-Secret: <secret>" -d '{"event_type":"practice_completed","student_id":"<uuid>","data":{"score":85,"section":"reading"}}'
      2. Assert: HTTP 202
      3. Query: SELECT * FROM webhook_events WHERE platform='ibt' ORDER BY created_at DESC LIMIT 1
      4. Assert: row exists with processed=false
    Expected Result: Event received and stored
    Evidence: .sisyphus/evidence/task-3.1-ibt-webhook.txt

  Scenario: Invalid payload rejected
    Tool: Bash
    Steps:
      1. curl -X POST /api/webhook/ibt -H "X-Webhook-Secret: <secret>" -d '{"foo":"bar"}'
      2. Assert: HTTP 400
      3. Assert: error about missing required fields
    Expected Result: Malformed payload rejected
    Evidence: .sisyphus/evidence/task-3.1-invalid-payload.txt

  Scenario: Wrong secret rejected
    Tool: Bash
    Steps:
      1. curl -X POST /api/webhook/ibt -H "X-Webhook-Secret: wrongsecret" -d '{"event_type":"practice_completed","student_id":"x","data":{}}'
      2. Assert: HTTP 401
    Expected Result: Invalid secret blocked
    Evidence: .sisyphus/evidence/task-3.1-wrong-secret.txt
  ```

  **Commit**: YES
  - Message: `task(3.1): webhook receiver endpoints for 6 platforms with payload validation`
  - Files: worker/src/routes/webhook.ts, worker/src/routes/webhook.test.ts, worker/src/types.ts (update)
  - Pre-commit: `cd worker && npx vitest run src/routes/webhook.test.ts`

- [ ] 3.2. Webhook event processing pipeline

  **What to do**:
  - Create `worker/src/services/webhook-processor.ts` — process unprocessed webhook_events
  - Processing logic: read event, based on platform + event_type, update relevant tables:
    - practice_completed → update student_progress_unified
    - test_booked → create commission_ledger entry (Task 3.4)
    - test_completed → update student_progress_unified + commission
  - Mark event as processed=true after successful processing
  - Error handling: if processing fails, mark processed=true with error in error_message column (don't block queue)
  - Add `POST /api/webhook/process` endpoint (internal, cron-triggered) to process batch
  - Write tests with mock events for each event_type

  **Must NOT do**:
  - Do not process events synchronously in webhook receiver (that's 3.1's job — just store)
  - Do not retry indefinitely (mark failed and move on)
  - Do not process events out of order (process by created_at ASC)

  **Recommended Agent Profile**:
  - **Category**: `deep` — event processing logic, multiple table updates
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 3.5 — different concerns)
  - **Parallel Group**: Wave 3
  - **Blocks**: 3.3, 3.4 (these are called by processor)
  - **Blocked By**: 3.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2495` — Task 3.2: Webhook event processing pipeline
  - `C:\Users\user\osee-prep-hub-blueprint.md:299-333` — Section 3 Webhook flow
  - `C:\Users\user\osee-prep-hub-blueprint.md:335-1236` — Schema (webhook_events, student_progress_unified tables)

  **Acceptance Criteria**:
  - [ ] Processor reads unprocessed events in order
  - [ ] Each event_type handled correctly
  - [ ] Successful processing marks processed=true
  - [ ] Failed processing marks processed=true with error_message
  - [ ] POST /api/webhook/process triggers batch
  - [ ] Tests cover all event types + failure case

  **QA Scenarios**:
  ```
  Scenario: Process practice_completed event
    Tool: Bash
    Preconditions: unprocessed ibt practice_completed event in webhook_events
    Steps:
      1. curl -X POST /api/webhook/process
      2. Assert: HTTP 200 with count of processed events
      3. Query: SELECT processed, error_message FROM webhook_events WHERE id='<event_id>'
      4. Assert: processed=true, error_message is null
      5. Query: SELECT * FROM student_progress_unified WHERE student_id='<uuid>' AND platform='ibt'
      6. Assert: row exists with updated score/section data
    Expected Result: Event processed, progress updated
    Evidence: .sisyphus/evidence/task-3.2-process-practice.txt

  Scenario: Failed processing records error
    Tool: Bash
    Preconditions: event with malformed data that will fail processing
    Steps:
      1. Insert bad event into webhook_events
      2. curl -X POST /api/webhook/process
      3. Query: SELECT processed, error_message FROM webhook_events WHERE id='<bad_event>'
      4. Assert: processed=true, error_message is not null
    Expected Result: Failures recorded, don't block queue
    Evidence: .sisyphus/evidence/task-3.2-process-failure.txt
  ```

  **Commit**: YES
  - Message: `task(3.2): webhook event processing pipeline with error handling`
  - Files: worker/src/services/webhook-processor.ts, worker/src/services/webhook-processor.test.ts, worker/src/routes/webhook.ts (update)
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 3.3. Student progress unified table updates

  **What to do**:
  - Create `worker/src/services/student-progress.ts` — update student_progress_unified table from webhook events
  - For each practice_completed: upsert into student_progress_unified (student_id, platform, exam_type, section, score, completed_at)
  - Aggregate: keep latest score per section, running best score, total practice count
  - Add `GET /api/student/progress` endpoint — student's full progress across all platforms
  - Add `GET /api/teacher/students/:id/progress` — teacher view of student progress
  - Write tests

  **Must NOT do**:
  - Do not delete old progress records (keep history)
  - Do not expose progress to other students

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high` — service + 2 endpoints + tests
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 3.4, 3.5 — but called by 3.2, so really 3.2 calls into this)
  - **Parallel Group**: Wave 3
  - **Blocks**: Phase 3 (reports need this data), 11.3 (progress page)
  - **Blocked By**: 3.1, 3.2

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2496` — Task 3.3: Student progress unified table updates
  - `C:\Users\user\osee-prep-hub-blueprint.md:335-1236` — Schema (student_progress_unified)

  **Acceptance Criteria**:
  - [ ] student_progress_unified upserted on practice_completed
  - [ ] GET /api/student/progress returns all platforms' progress
  - [ ] GET /api/teacher/students/:id/progress works
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Progress updated after practice
    Tool: Bash
    Preconditions: student completes practice (webhook fired + processed)
    Steps:
      1. curl /api/student/progress
      2. Assert: JSON array with platform, section, score, completed_at
      3. Assert: includes the practice that was just completed
    Expected Result: Progress reflects latest practice
    Evidence: .sisyphus/evidence/task-3.3-progress.txt
  ```

  **Commit**: YES
  - Message: `task(3.3): student progress unified table updates + progress endpoints`
  - Files: worker/src/services/student-progress.ts, worker/src/routes/student.ts (update), worker/src/routes/teacher.ts (update), worker/src/services/student-progress.test.ts
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 3.4. Commission trigger on webhook events

  **What to do**:
  - Create `worker/src/services/commission.ts` — commission calculation engine
  - Trigger on webhook events (called from webhook-processor):
    - practice_completed (first time per student) → Rp 10k commission to teacher
    - test_booked → Rp 50k commission to teacher
    - edubot premium subscribed → Rp 15k/month recurring
  - Insert into commission_ledger: { teacher_id, student_id, amount, type, reference_event_id, status: pending }
  - Ambassador teachers get 2x rate (check teacher's is_ambassador flag)
  - Add `GET /api/teacher/commission/recent` — recent commission entries
  - Write tests covering all trigger types + ambassador multiplier

  **Must NOT do**:
  - Do not double-pay commission (check if already paid for that event)
  - Do not process commission for students without referring teacher
  - Do not mark commission as paid (that's Task 12.3)

  **Recommended Agent Profile**:
  - **Category**: `deep` — financial logic, multiple trigger types, idempotency
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 3.3, 3.5 — but called by 3.2)
  - **Parallel Group**: Wave 3
  - **Blocks**: 12.1 (commission dashboard), 12.2 (payouts)
  - **Blocked By**: 3.1, 3.2

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2497` — Task 3.4: Commission trigger on webhook events
  - `C:\Users\user\osee-prep-hub-blueprint.md:60-67` — Revenue model (commission rates)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2193-2321` — Section 9 Commission System (full flow)
  - `D:\claude telegram bot\worker\src\services\referral-commission.ts` — EduBot's commission logic
  - `D:\claude telegram bot\worker\src\services\referral-commission.test.ts` — EduBot's commission tests

  **WHY Each Reference Matters**:
  - Blueprint task defines trigger requirement
  - Revenue model lists exact rates: Rp 10k first practice, Rp 50k test booking, Rp 15k/month EduBot premium
  - Section 9 has full commission flow with idempotency logic
  - EduBot's commission service + test shows how this team implements commission — adapt for Hub's webhook-driven flow

  **Acceptance Criteria**:
  - [ ] practice_completed (first per student) → Rp 10k to teacher
  - [ ] test_booked → Rp 50k to teacher
  - [ ] edubot premium subscribed → Rp 15k/month recurring
  - [ ] Ambassador gets 2x rate
  - [ ] No double-payments (idempotency check)
  - [ ] No commission for students without teacher
  - [ ] GET /api/teacher/commission/recent works
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: First practice triggers Rp 10k commission
    Tool: Bash
    Preconditions: student with teacher, no prior practice_completed events
    Steps:
      1. Fire ibt webhook with practice_completed
      2. Process webhooks
      3. Query: SELECT amount FROM commission_ledger WHERE teacher_id='<id>' AND student_id='<id>' AND type='first_practice'
      4. Assert: amount = 10000
    Expected Result: Rp 10k commission recorded
    Evidence: .sisyphus/evidence/task-3.4-first-practice.txt

  Scenario: Second practice does NOT trigger commission
    Tool: Bash
    Preconditions: student already has first_practice commission
    Steps:
      1. Fire another ibt practice_completed webhook
      2. Process webhooks
      3. Query: SELECT count(*) FROM commission_ledger WHERE student_id='<id>' AND type='first_practice'
      4. Assert: count = 1 (no new entry)
    Expected Result: Idempotency — no double payment
    Evidence: .sisyphus/evidence/task-3.4-idempotency.txt

  Scenario: Ambassador gets 2x
    Tool: Bash
    Preconditions: ambassador teacher's student completes first practice
    Steps:
      1. Fire practice_completed
      2. Query commission_ledger
      3. Assert: amount = 20000 (2x 10k)
    Expected Result: Ambassador multiplier applied
    Evidence: .sisyphus/evidence/task-3.4-ambassador.txt
  ```

  **Commit**: YES
  - Message: `task(3.4): commission trigger on webhook events with idempotency + ambassador multiplier`
  - Files: worker/src/services/commission.ts, worker/src/services/commission.test.ts, worker/src/routes/teacher.ts (update)
  - Pre-commit: `cd worker && npx vitest run src/services/commission.test.ts`

- [ ] 3.5. Webhook secret authentication

  **What to do**:
  - Create `worker/src/middleware/webhook-auth.ts` — middleware that verifies X-Webhook-Secret header against env var for each platform
  - Each platform has its own secret: WEBHOOK_SECRET_IBT, WEBHOOK_SECRET_ITP, etc.
  - Middleware extracts platform from route, loads correct secret, compares
  - Apply middleware to all webhook routes (from 3.1)
  - Log failed auth attempts (no PII)
  - Write tests for valid + invalid secrets

  **Must NOT do**:
  - Do not use shared secret across platforms
  - Do not log the secret value
  - Do not accept webhook without header

  **Recommended Agent Profile**:
  - **Category**: `quick` — middleware + tests
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 3.2-3.4 — this is auth layer, they're processing logic)
  - **Parallel Group**: Wave 3
  - **Blocks**: None (3.1 already has basic auth, this formalizes it)
  - **Blocked By**: 3.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2498` — Task 3.5: Webhook secret authentication
  - `C:\Users\user\osee-prep-hub-blueprint.md:2749-2755` — Section 14 webhook secrets env vars

  **Acceptance Criteria**:
  - [ ] Middleware verifies X-Webhook-Secret per platform
  - [ ] Missing header → 401
  - [ ] Wrong secret → 401
  - [ ] Correct secret → passes through
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Correct secret passes
    Tool: Bash
    Steps:
      1. curl -X POST /api/webhook/ibt -H "X-Webhook-Secret: <correct>" -d '<valid payload>'
      2. Assert: HTTP 202
    Expected Result: Authenticated webhook accepted
    Evidence: .sisyphus/evidence/task-3.5-correct-secret.txt

  Scenario: Missing header rejected
    Tool: Bash
    Steps:
      1. curl -X POST /api/webhook/ibt -d '<valid payload>'
      2. Assert: HTTP 401
    Expected Result: No secret = rejected
    Evidence: .sisyphus/evidence/task-3.5-missing-secret.txt
  ```

  **Commit**: YES
  - Message: `task(3.5): webhook secret authentication middleware per-platform`
  - Files: worker/src/middleware/webhook-auth.ts, worker/src/middleware/webhook-auth.test.ts, worker/src/routes/webhook.ts (update to use middleware)
  - Pre-commit: `cd worker && npx vitest run`

> **PHASE 1 BOUNDARY**: After Task 3.5, create git tag `phase-1-complete`. All Phase 1 tasks (1.1-1.9, 2.1-2.6, 3.1-3.5) must be complete and committed before starting Phase 2.

- [ ] 4.1. Enable pgvector extension in Supabase

  **What to do**:
  - Verify pgvector extension already enabled (Task 1.1 should have done this)
  - Create `documents` table for RAG if not in schema: `CREATE TABLE IF NOT EXISTS documents (id uuid PRIMARY KEY, content text, embedding vector(1536), metadata jsonb, created_at timestamptz);`
  - Create index: `CREATE INDEX ON documents USING ivfflat (embedding vector_cosine_ops);`
  - Add to schema.sql if missing

  **Must NOT do**:
  - Do not ingest documents (Task 4.3, 4.4)
  - Do not build search function (Task 4.5)

  **Recommended Agent Profile**: `quick` | Skills: [] | Wave 4 | Blocks: 4.2-4.6 | Blocked By: Phase 1

  **References**: blueprint:2505 (Task 4.1), blueprint:1746-1831 (Section 7 RAG architecture)

  **Acceptance Criteria**:
  - [ ] pgvector extension active
  - [ ] documents table exists with vector(1536) embedding column
  - [ ] ivfflat index created

  **QA Scenarios**:
  ```
  Scenario: pgvector and documents table ready
    Tool: Bash
    Steps:
      1. psql -c "SELECT extname FROM pg_extension WHERE extname='vector';" → "vector"
      2. psql -c "\d documents" → table exists with embedding column of type vector
    Expected Result: RAG infrastructure ready
    Evidence: .sisyphus/evidence/task-4.1-pgvector.txt
  ```

  **Commit**: YES | `task(4.1): enable pgvector + create documents table with vector index`

- [ ] 4.2. Document ingestion script

  **What to do**:
  - Create `scripts/ingest-knowledge-base.ts` — TypeScript script that:
    - Reads document files from `docs/knowledge-base/` (markdown, txt, pdf)
    - Chunks documents (split by sections/paragraphs, max 1000 tokens per chunk)
    - Generates embeddings via OpenAI embeddings API (text-embedding-3-small, 1536 dims)
    - Inserts into documents table with metadata (source, section, tags)
  - Support document types: .md, .txt, .pdf (use pdf-parse for PDFs)
  - Idempotent: skip documents already ingested (check metadata.source)
  - CLI args: --source <dir>, --dry-run, --limit <n>

  **Must NOT do**:
  - Do not ingest actual materials (Tasks 4.3, 4.4)
  - Do not hardcode OpenAI key (use env)
  - Do not skip chunking (inserting whole documents = poor retrieval)

  **Recommended Agent Profile**: `deep` | Skills: [] | Wave 4 | Blocks: 4.3, 4.4 | Blocked By: 4.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:1832-1914` — Section 7 Ingestion script (detailed spec)
  - `C:\Users\user\osee-prep-hub-blueprint.md:1746-1831` — Section 7 RAG architecture

  **Acceptance Criteria**:
  - [ ] Script runs: `npx tsx scripts/ingest-knowledge-base.ts --dry-run`
  - [ ] Chunks documents correctly (max 1000 tokens)
  - [ ] Generates embeddings via OpenAI
  - [ ] Inserts into documents table
  - [ ] Idempotent (re-running skips existing)
  - [ ] --dry-run shows what would be ingested without writing

  **QA Scenarios**:
  ```
  Scenario: Dry run on sample documents
    Tool: Bash
    Preconditions: 2-3 sample .md files in docs/knowledge-base/sample/
    Steps:
      1. npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/sample --dry-run
      2. Assert: output lists documents that would be ingested
      3. Assert: NO rows inserted (SELECT count(*) FROM documents → 0 or unchanged)
    Expected Result: Dry run shows plan without writing
    Evidence: .sisyphus/evidence/task-4.2-dry-run.txt

  Scenario: Real ingestion
    Tool: Bash
    Preconditions: sample docs
    Steps:
      1. npx tsx scripts/ingest-knowledge-base.ts --source docs/knowledge-base/sample
      2. Assert: documents table has new rows
      3. Assert: embedding column is not null
      4. Assert: metadata contains source path
    Expected Result: Documents ingested with embeddings
    Evidence: .sisyphus/evidence/task-4.2-ingest.txt
  ```

  **Commit**: YES | `task(4.2): document ingestion script with chunking + OpenAI embeddings`
  - Files: scripts/ingest-knowledge-base.ts, scripts/ingest-knowledge-base.test.ts

- [ ] 4.3. Ingest Tier 1 materials (CEFR, Kurikulum Merdeka, ETS specs)

  **What to do**:
  - Create `docs/knowledge-base/tier1/` directory
  - Source or create reference documents:
    - CEFR descriptors (A1-C2, all 4 skills) — public CEFR reference
    - Kurikulum Merdeka English curriculum (Indonesian Ministry of Education)
    - ETS TOEFL iBT/ITP/TOEIC test specifications
    - IELTS band descriptors
  - If actual documents not available, create structured markdown summaries from official sources
  - Run ingestion script (from 4.2) on tier1/
  - Verify: SELECT count(*) FROM documents WHERE metadata->>'tier' = '1' → expected 50+ chunks

  **Must NOT do**:
  - Do not violate copyright (use public domain, official specs, or create summaries)
  - Do not ingest Tier 2 materials (Task 4.4)

  **Recommended Agent Profile**: `unspecified-high` | Skills: [] | Wave 4 | Blocks: 4.5 (search needs data) | Blocked By: 4.2

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2507` — Task 4.3: Ingest Tier 1 materials
  - `C:\Users\user\osee-prep-hub-blueprint.md:1746-1831` — Section 7 RAG architecture (tier definitions)

  **Acceptance Criteria**:
  - [ ] docs/knowledge-base/tier1/ has documents for CEFR, Kurikulum Merdeka, ETS, IELTS
  - [ ] Ingestion completed
  - [ ] documents table has 50+ rows with tier=1 metadata
  - [ ] Spot-check: search for "CEFR B1 writing" returns relevant chunks

  **QA Scenarios**:
  ```
  Scenario: Tier 1 materials ingested
    Tool: Bash
    Steps:
      1. psql -c "SELECT count(*) FROM documents WHERE metadata->>'tier'='1';"
      2. Assert: count >= 50
      3. psql -c "SELECT content FROM documents WHERE content ILIKE '%CEFR%' LIMIT 3;"
      4. Assert: results returned
    Expected Result: Tier 1 knowledge base populated
    Evidence: .sisyphus/evidence/task-4.3-tier1-ingested.txt
  ```

  **Commit**: YES | `task(4.3): ingest Tier 1 materials - CEFR, Kurikulum Merdeka, ETS specs`
  - Files: docs/knowledge-base/tier1/*, (no code changes)

- [ ] 4.4. Ingest EduBot error pattern data

  **What to do**:
  - Create `scripts/ingest-edubot-errors.ts` — query EduBot's D1 database (or export) for common student error patterns
  - If D1 access not available from Hub, create `docs/knowledge-base/edubot-errors/` with structured error patterns (extracted from EduBot's error analysis services)
  - Read `D:\claude telegram bot\worker\src\services\weakness-analysis.ts` to understand error categorization
  - Read `D:\claude telegram bot\worker\src\services\student-report.ts` for error pattern reporting
  - Ingest error patterns into documents table with tier=2, source=edubot

  **Must NOT do**:
  - Do not copy EduBot's source code
  - Do not access EduBot's D1 directly without permission
  - Do not include student PII in error patterns

  **Recommended Agent Profile**: `unspecified-high` | Skills: [] | Wave 4 | Blocks: 4.5 | Blocked By: 4.2

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2508` — Task 4.4
  - `D:\claude telegram bot\worker\src\services\weakness-analysis.ts` — error categorization
  - `D:\claude telegram bot\worker\src\services\student-report.ts` — error reporting

  **Acceptance Criteria**:
  - [ ] Error patterns ingested (tier=2, source=edubot)
  - [ ] No PII in ingested data
  - [ ] documents table has error pattern entries

  **QA Scenarios**:
  ```
  Scenario: Error patterns available for RAG
    Tool: Bash
    Steps:
      1. psql -c "SELECT count(*) FROM documents WHERE metadata->>'source'='edubot';"
      2. Assert: count > 0
    Expected Result: EduBot error patterns in knowledge base
    Evidence: .sisyphus/evidence/task-4.4-edubot-errors.txt
  ```

  **Commit**: YES | `task(4.4): ingest EduBot error pattern data into RAG knowledge base`

- [ ] 4.5. Vector search function (match_documents)

  **What to do**:
  - Create Supabase SQL function `match_documents`:
    ```sql
    CREATE OR REPLACE FUNCTION match_documents(
      query_embedding vector(1536),
      match_count int DEFAULT 10,
      filter jsonb DEFAULT '{}'
    ) RETURNS TABLE (
      id uuid, content text, metadata jsonb, similarity float
    ) AS $$
    SELECT d.id, d.content, d.metadata,
      1 - (d.embedding <=> query_embedding) AS similarity
    FROM documents d
    WHERE d.metadata @> filter
    ORDER BY d.embedding <=> query_embedding
    LIMIT match_count;
    $$ LANGUAGE sql;
    ```
  - Add to schema.sql
  - Test with sample embedding

  **Must NOT do**:
  - Do not build the API endpoint (Task 4.6)
  - Do not use Euclidean distance (use cosine: `<=>`)

  **Recommended Agent Profile**: `deep` | Skills: [] | Wave 4 | Blocks: 4.6 | Blocked By: 4.1, 4.3, 4.4

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2509` — Task 4.5
  - `C:\Users\user\osee-prep-hub-blueprint.md:1915-1976` — Section 7 RAG retrieval
  - pgvector docs: https://github.com/pgvector/pgvector (cosine distance operator)

  **Acceptance Criteria**:
  - [ ] match_documents function exists in Supabase
  - [ ] Returns relevant documents sorted by similarity
  - [ ] Filter parameter works (e.g. {"tier": "1"})
  - [ ] Test query returns results

  **QA Scenarios**:
  ```
  Scenario: Vector search returns relevant docs
    Tool: Bash
    Preconditions: Tier 1 ingested
    Steps:
      1. Generate embedding for "CEFR B1 writing skills"
      2. psql -c "SELECT * FROM match_documents('<embedding>'::vector, 5, '{"tier":"1"}'::jsonb);"
      3. Assert: 5 results returned
      4. Assert: similarity scores > 0.5
      5. Assert: content relates to CEFR/writing
    Expected Result: Relevant documents retrieved
    Evidence: .sisyphus/evidence/task-4.5-vector-search.txt
  ```

  **Commit**: YES | `task(4.5): create match_documents vector search function with cosine similarity`
  - Files: schema.sql (update), scripts/test-vector-search.ts

- [ ] 4.6. RAG search API endpoint

  **What to do**:
  - Create `worker/src/routes/ai.ts` (or `rag.ts`) with:
    - `POST /api/ai/rag-search` — accepts {query, filter?, limit?}, generates embedding for query, calls match_documents, returns results
  - Create `worker/src/services/rag-search.ts` — generateQueryEmbedding, searchDocuments
  - Use OpenAI text-embedding-3-small for query embedding
  - Rate limit: 100 requests/minute per user
  - Write tests

  **Must NOT do**:
  - Do not expose internal document IDs (return content + metadata only)
  - Do not allow unauthenticated access

  **Recommended Agent Profile**: `quick` | Skills: [] | Wave 4 | Blocks: 5.1 (grader uses RAG), 6.1 (generator uses RAG) | Blocked By: 4.5

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2510` — Task 4.6
  - `C:\Users\user\osee-prep-hub-blueprint.md:1915-1976` — Section 7 RAG retrieval at generation time

  **Acceptance Criteria**:
  - [ ] POST /api/ai/rag-search returns relevant documents
  - [ ] Filter parameter works
  - [ ] Unauthenticated → 401
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: RAG search returns results
    Tool: Bash
    Preconditions: authenticated, Tier 1 ingested
    Steps:
      1. curl -X POST /api/ai/rag-search -H "Authorization: Bearer <token>" -d '{"query":"How to assess B1 writing?","limit":5}'
      2. Assert: HTTP 200
      3. Assert: JSON array with 5 results
      4. Assert: each result has content, metadata, similarity
      5. Assert: content relates to writing assessment
    Expected Result: RAG search functional
    Evidence: .sisyphus/evidence/task-4.6-rag-search.txt
  ```

  **Commit**: YES | `task(4.6): RAG search API endpoint with OpenAI embeddings`
  - Files: worker/src/routes/ai.ts, worker/src/services/rag-search.ts, worker/src/routes/ai.test.ts

> **PHASE 2A BOUNDARY**: Tasks 4.1-4.6 complete. Continue to Phase 2B (AI Writing Grader).

- [ ] 5.1. gradeWriting service (GPT-4o-mini + RAG)

  **What to do**:
  - Create `worker/src/services/ai-grading.ts` — gradeWriting(essay, rubric, examType, level):
    1. RAG search for relevant rubric/assessment criteria (from Task 4.6)
    2. Build prompt: essay + rubric + RAG context + exam-specific scoring guide
    3. Call OpenAI GPT-4o-mini with structured output (JSON: score, band, feedback, criteria_scores, improvements)
    4. Return structured result
  - Create `worker/src/routes/ai.ts` (update) — POST /api/ai/grade-writing
  - Write tests with mock OpenAI response

  **Must NOT do**:
  - Do not build queue system (Task 5.2)
  - Do not build UI (Task 5.3)
  - Do not hardcode prompts — use prompt templates in `worker/src/services/prompts/`

  **Recommended Agent Profile**: `deep` | Skills: [] | Wave 5 | Blocks: 5.2, 5.3 | Blocked By: 4.6

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2513` — Task 5.1
  - `C:\Users\user\osee-prep-hub-blueprint.md:2078-2158` — Section 8 Writing Grader spec (detailed prompt structure)
  - `C:\Users\user\osee-prep-hub-blueprint.md:1977-2075` — Section 7 RAG-grounded material generation (retrieval pattern)
  - `D:\claude telegram bot\worker\src\routes\writing.ts` — EduBot's writing route
  - `D:\claude telegram bot\worker\src\services\ai.ts` — EduBot's AI service (OpenAI call patterns)

  **Acceptance Criteria**:
  - [ ] POST /api/ai/grade-writing returns structured grading result
  - [ ] Result has: score, band, feedback, criteria_scores[], improvements[]
  - [ ] RAG context injected into prompt
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Grade a sample essay
    Tool: Bash
    Preconditions: authenticated, RAG populated
    Steps:
      1. curl -X POST /api/ai/grade-writing -d '{"essay":"My hometown is beautiful...","rubric":"ielts_task2","examType":"IELTS","level":"B1"}'
      2. Assert: HTTP 200
      3. Assert: response has score (number), band (string), feedback (string), criteria_scores (array)
    Expected Result: Essay graded with structured feedback
    Evidence: .sisyphus/evidence/task-5.1-grade-essay.txt
  ```

  **Commit**: YES | `task(5.1): gradeWriting service with GPT-4o-mini + RAG context`

- [ ] 5.2. Grading queue system (pending → processing → completed)

  **What to do**:
  - Use ai_grading_queue table from schema
  - POST /api/ai/grade-writing creates queue entry (status=pending), returns queue_id
  - Add `POST /api/ai/grading/:id/process` — internal endpoint to process queue item
  - Add `GET /api/ai/grading/:id` — check status + result
  - Add cron trigger or on-demand processing
  - Update gradeWriting service to work in queue mode

  **Must NOT do**: Do not process synchronously in POST /grade-writing (return queue_id immediately)

  **Recommended Agent Profile**: `deep` | Wave 5 | Blocks: 5.3 | Blocked By: 5.1

  **References**: blueprint:2514, blueprint schema (ai_grading_queue table)

  **Acceptance Criteria**:
  - [ ] Queue entry created on submit
  - [ ] Status transitions: pending → processing → completed
  - [ ] GET /api/ai/grading/:id returns current status + result when complete
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Submit essay and poll for result
    Tool: Bash
    Steps:
      1. POST /api/ai/grade-writing → 202 with queue_id
      2. GET /api/ai/grading/<queue_id> → status: pending or processing
      3. Wait + retry
      4. GET /api/ai/grading/<queue_id> → status: completed, result present
    Expected Result: Async grading via queue
    Evidence: .sisyphus/evidence/task-5.2-queue.txt
  ```

  **Commit**: YES | `task(5.2): grading queue system with async processing`

- [ ] 5.3. AI grader UI page (Flutter)

  **What to do**:
  - Create `flutter/lib/features/teacher/pages/ai_grader_page.dart`:
    - Essay text area (paste or type)
    - Rubric selector (IELTS Task 1/2, TOEFL iBT, TOEFL ITP, TOEIC)
    - Exam type + level selectors
    - Submit button → shows queue status
    - Result display: score, band, feedback, criteria breakdown, improvements
  - Use Riverpod provider to manage submission + polling

  **Must NOT do**: Do not build speaking grader UI (Task 7.2)

  **Recommended Agent Profile**: `visual-engineering` | Wave 5 | Blocks: none | Blocked By: 5.2

  **References**: blueprint:2515, blueprint:2078-2158 (result structure)

  **Acceptance Criteria**:
  - [ ] Page renders with essay input, rubric selector, submit button
  - [ ] Submit creates queue entry, shows status
  - [ ] Result displayed when complete
  - [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Grade essay via UI
    Tool: Playwright
    Steps:
      1. Navigate to /teacher/ai-grader
      2. Type essay in text area
      3. Select rubric "IELTS Task 2"
      4. Click "Grade"
      5. Assert: status indicator appears (pending/processing)
      6. Wait
      7. Assert: result displayed with score, feedback
      8. Screenshot
    Expected Result: Full grading flow works via UI
    Evidence: .sisyphus/evidence/task-5.3-grader-ui.png
  ```

  **Commit**: YES | `task(5.3): AI grader UI page (Flutter) - essay input, rubric, results`

- [ ] 5.4. Quota checking (free: 50/month, pro: unlimited)

  **What to do**:
  - Create `worker/src/services/quota.ts` — checkQuota(userId, type): count this month's usage, compare to limit
  - Free tier: 50 grading credits/month
  - Pro tier: unlimited
  - Apply in grade-writing route before queueing
  - Add `GET /api/ai/quota` — user's current usage + limit
  - Write tests

  **Must NOT do**: Do not implement quota bonus system (Task 12.4)

  **Recommended Agent Profile**: `unspecified-high` | Wave 5 | Blocks: 6.6, 7.4 | Blocked By: 5.1

  **References**: blueprint:2516, blueprint:50-52 (revenue model quotas)

  **Acceptance Criteria**:
  - [ ] Free user blocked after 50 grading requests/month
  - [ ] Pro user unlimited
  - [ ] GET /api/ai/quota returns {used, limit, remaining}
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Free user hits quota
    Tool: Bash
    Steps:
      1. As free user, submit 50 grading requests
      2. Submit 51st
      3. Assert: HTTP 429 with "quota exceeded"
    Expected Result: Quota enforced
    Evidence: .sisyphus/evidence/task-5.4-quota-exceeded.txt
  ```

  **Commit**: YES | `task(5.4): quota checking - free 50/month, pro unlimited`

- [ ] 5.5. Store results in ai_grading_queue table

  **What to do**:
  - Update gradeWriting service to store full result JSON in ai_grading_queue.result column
  - Add `GET /api/ai/grading/history` — user's grading history
  - Ensure result persists after completion

  **Must NOT do**: Do not store results outside ai_grading_queue

  **Recommended Agent Profile**: `quick` | Wave 5 | Blocked By: 5.2

  **References**: blueprint:2517, blueprint schema (ai_grading_queue table)

  **Acceptance Criteria**:
  - [ ] Result JSON stored in ai_grading_queue.result
  - [ ] GET /api/ai/grading/history returns list
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Grading history accessible
    Tool: Bash
    Steps:
      1. Complete a grading
      2. GET /api/ai/grading/history
      3. Assert: array with completed grading
    Expected Result: History persisted
    Evidence: .sisyphus/evidence/task-5.5-history.txt
  ```

  **Commit**: YES | `task(5.5): store grading results + history endpoint`

- [ ] 5.6. Bridge to EduBot writing route (alternative path)

  **What to do**:
  - Add `POST /api/ai/grade-writing/edubot` — proxy to EduBot's writing evaluation endpoint
  - Read `D:\claude telegram bot\worker\src\routes\writing.ts` to understand EduBot's API contract
  - Set EDUBOT_INTERNAL_SECRET header for auth
  - Return EduBot's result in Hub's format (transform if needed)

  **Must NOT do**: Do not modify EduBot

  **Recommended Agent Profile**: `deep` | Wave 5 | Blocked By: 5.1

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2518` — Task 5.6
  - `D:\claude telegram bot\worker\src\routes\writing.ts` — EduBot's writing route contract
  - `C:\Users\user\osee-prep-hub-blueprint.md:2745-2747` — EDUBOT_API_URL, EDUBOT_INTERNAL_SECRET

  **Acceptance Criteria**:
  - [ ] POST /api/ai/grade-writing/edubot proxies to EduBot
  - [ ] Result transformed to Hub format
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: EduBot bridge grading
    Tool: Bash
    Steps:
      1. POST /api/ai/grade-writing/edubot with essay
      2. Assert: HTTP 200 with grading result
    Expected Result: Bridge to EduBot works
    Evidence: .sisyphus/evidence/task-5.6-edubot-bridge.txt
  ```

  **Commit**: YES | `task(5.6): bridge to EduBot writing evaluation route`

- [ ] 6.1. generateMaterial service (GPT-4o-mini + RAG)

  **What to do**:
  - Create `worker/src/services/ai-generation.ts` — generateMaterial(type, exam, level, topic, options):
    1. RAG search for relevant reference materials
    2. Build prompt: type + exam + level + topic + RAG context + options
    3. Call GPT-4o-mini
    4. Return generated material (reading passage, questions, grammar exercise, etc.)
  - Add POST /api/ai/generate-material to routes/ai.ts
  - Write tests

  **Recommended Agent Profile**: `deep` | Wave 6 | Blocks: 6.2-6.6 | Blocked By: 4.6

  **References**: blueprint:2521, blueprint:1977-2075 (RAG-grounded generation), `D:\claude telegram bot\worker\src\services\contentGenerator.ts`

  **Acceptance Criteria**:
  - [ ] POST /api/ai/generate-material returns generated material
  - [ ] RAG context used
  - [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Generate reading passage
    Tool: Bash
    Steps:
      1. POST /api/ai/generate-material -d '{"type":"reading","exam":"TOEFL_IBT","level":"B2","topic":"environment"}'
      2. Assert: HTTP 200 with passage + questions
    Expected Result: Material generated
    Evidence: .sisyphus/evidence/task-6.1-generate.txt
  ```

  **Commit**: YES | `task(6.1): generateMaterial service with GPT-4o-mini + RAG`

- [ ] 6.2. Generation queue system

  **What to do**: Same pattern as 5.2 but for generation. Use generation queue table.

  **Recommended Agent Profile**: `deep` | Wave 6 | Blocked By: 6.1

  **References**: blueprint:2522

  **Acceptance Criteria**: [ ] Async generation via queue, [ ] Status polling, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Submit generation and poll
    Tool: Bash
    Steps: POST /api/ai/generate-material → 202 queue_id; poll GET /api/ai/generation/:id → completed
    Expected Result: Async generation
    Evidence: .sisyphus/evidence/task-6.2-queue.txt
  ```

  **Commit**: YES | `task(6.2): generation queue system`

- [ ] 6.3. Material generator UI page (Flutter)

  **What to do**: Create `flutter/lib/features/teacher/pages/material_generator_page.dart` with: type selector, exam selector, level selector, topic input, options, generate button, preview of result, "Add to syllabus" button (links to Task 6.5).

  **Recommended Agent Profile**: `visual-engineering` | Wave 6 | Blocked By: 6.2

  **References**: blueprint:2523

  **Acceptance Criteria**: [ ] Page renders all selectors, [ ] Generate creates queue entry, [ ] Result preview displayed, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Generate material via UI
    Tool: Playwright
    Steps: Navigate to /teacher/generator, select type/exam/level, enter topic, click Generate, wait, assert result preview
    Expected Result: Full generation flow via UI
    Evidence: .sisyphus/evidence/task-6.3-generator-ui.png
  ```

  **Commit**: YES | `task(6.3): material generator UI page (Flutter)`

- [ ] 6.4. Content validation pipeline (reuse EduBot's contentValidator pattern)

  **What to do**:
  - Create `worker/src/services/content-validator.ts` — validate generated content for: appropriateness, accuracy, format compliance, bias
  - Follow pattern from `D:\claude telegram bot\worker\src\services\content-validator.ts`
  - Run validation after generation, before storing
  - Add validation result to generation output: {valid, issues[], warnings[]}

  **Must NOT do**: Do not copy EduBot's code verbatim — adapt to Hub's TypeScript patterns

  **Recommended Agent Profile**: `deep` | Wave 6 | Blocked By: 6.1

  **References**: blueprint:2524, `D:\claude telegram bot\worker\src\services\content-validator.ts`, `D:\claude telegram bot\worker\src\services\content-auditor.ts`

  **Acceptance Criteria**: [ ] Validation runs on generated content, [ ] Invalid content flagged, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Invalid content flagged
    Tool: Bash
    Steps: Generate content with problematic input, assert validation issues in response
    Expected Result: Validation catches issues
    Evidence: .sisyphus/evidence/task-6.4-validation.txt
  ```

  **Commit**: YES | `task(6.4): content validation pipeline (adapted from EduBot)`

- [ ] 6.5. Generated material preview + add to syllabus

  **What to do**: Update generator UI (6.3) with "Add to Syllabus" button that creates syllabus_item with source_type='ai_generated'. Requires syllabus to exist (Phase 3 Task 10.1) — add minimal syllabus creation endpoint if needed.

  **Recommended Agent Profile**: `visual-engineering` | Wave 6 | Blocked By: 6.3

  **References**: blueprint:2525

  **Acceptance Criteria**: [ ] Preview shows formatted material, [ ] "Add to Syllabus" creates syllabus_item, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Add generated material to syllabus
    Tool: Playwright
    Steps: Generate material, click "Add to Syllabus", select syllabus, assert item added
    Expected Result: Material added to syllabus
    Evidence: .sisyphus/evidence/task-6.5-add-to-syllabus.png
  ```

  **Commit**: YES | `task(6.5): generated material preview + add to syllabus`

- [ ] 6.6. Quota checking (free: 10/month)

  **What to do**: Update quota service (5.4) to support generation quota: free 10/month, pro unlimited. Add to generation route.

  **Recommended Agent Profile**: `quick` | Wave 6 | Blocked By: 5.4, 6.1

  **References**: blueprint:2526

  **Acceptance Criteria**: [ ] Free user blocked after 10 generations/month, [ ] Pro unlimited, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Generation quota enforced
    Tool: Bash
    Steps: 10 generations, 11th blocked with 429
    Expected Result: Quota enforced
    Evidence: .sisyphus/evidence/task-6.6-quota.txt
  ```

  **Commit**: YES | `task(6.6): generation quota checking - free 10/month`

- [ ] 7.1. Bridge to EduBot speaking evaluation (Whisper + GPT)

  **What to do**:
  - Create `POST /api/ai/grade-speaking` — accepts audio URL (from R2, Task 7.3), proxies to EduBot's speaking route
  - Read `D:\claude telegram bot\worker\src\routes\speaking.ts` for contract
  - Return: transcription, pronunciation score, fluency, feedback

  **Must NOT do**: Do not rebuild Whisper integration — use EduBot's

  **Recommended Agent Profile**: `deep` | Wave 7 | Blocks: 7.2 | Blocked By: Phase 2A

  **References**: blueprint:2529, `D:\claude telegram bot\worker\src\routes\speaking.ts`

  **Acceptance Criteria**: [ ] POST /api/ai/grade-speaking returns evaluation, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Grade speaking sample
    Tool: Bash
    Steps: POST with audio URL, assert 200 with transcription + scores
    Expected Result: Speaking evaluation via EduBot bridge
    Evidence: .sisyphus/evidence/task-7.1-speaking.txt
  ```

  **Commit**: YES | `task(7.1): bridge to EduBot speaking evaluation`

- [ ] 7.2. Speaking grader UI (Flutter)

  **What to do**: Create `flutter/lib/features/teacher/pages/speaking_grader_page.dart` — record audio (Flutter mic), upload to R2, submit for grading, display results.

  **Recommended Agent Profile**: `visual-engineering` | Wave 7 | Blocked By: 7.1, 7.3

  **References**: blueprint:2530

  **Acceptance Criteria**: [ ] Record audio via mic, [ ] Upload to R2, [ ] Submit + display results, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Record and grade speaking
    Tool: Playwright (may need mic permission — use pre-recorded sample upload fallback)
    Steps: Upload sample audio, click "Grade", assert results displayed
    Expected Result: Speaking grading flow works
    Evidence: .sisyphus/evidence/task-7.2-speaking-ui.png
  ```

  **Commit**: YES | `task(7.2): speaking grader UI (Flutter)`

- [ ] 7.3. R2 audio upload pipeline

  **What to do**:
  - Create `worker/src/routes/upload.ts` — POST /api/upload/audio — accepts audio file, uploads to R2 bucket, returns R2 URL
  - Create `worker/src/services/r2.ts` — R2 client using Cloudflare bindings
  - Use presigned URLs for direct upload from Flutter Web (CORS-safe)

  **Recommended Agent Profile**: `deep` | Wave 7 | Blocks: 7.2 | Blocked By: 1.2

  **References**: blueprint:2531, blueprint:2760-2765 (R2 config)

  **Acceptance Criteria**: [ ] Audio upload to R2 works, [ ] Returns accessible URL, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Upload audio to R2
    Tool: Bash
    Steps: POST /api/upload/audio with sample.mp3, assert 200 with URL, curl URL → audio
    Expected Result: R2 upload pipeline functional
    Evidence: .sisyphus/evidence/task-7.3-r2-upload.txt
  ```

  **Commit**: YES | `task(7.3): R2 audio upload pipeline`

- [ ] 7.4. Quota checking for speaking

  **What to do**: Update quota service to support speaking quota: free 10/month, pro unlimited.

  **Recommended Agent Profile**: `quick` | Wave 7 | Blocked By: 5.4, 7.1

  **References**: blueprint:2532

  **Acceptance Criteria**: [ ] Speaking quota enforced, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Speaking quota
    Tool: Bash
    Steps: 10 speaking grades, 11th blocked
    Expected Result: Quota enforced
    Evidence: .sisyphus/evidence/task-7.4-quota.txt
  ```

  **Commit**: YES | `task(7.4): speaking quota checking`

> **PHASE 2 BOUNDARY**: Tasks 4.1-7.4 complete. Git tag `phase-2-complete`.

- [ ] 8.1. Report generation service

  **What to do**:
  - Create `worker/src/services/reports.ts` — generateStudentReport(studentId): aggregate progress, scores, weaknesses, recommendations
  - Read `D:\claude telegram bot\worker\src\services\student-report.ts` for pattern
  - Add `GET /api/teacher/students/:id/report` endpoint
  - Return JSON report structure

  **Recommended Agent Profile**: `deep` | Wave 8 | Blocks: 8.2-8.5 | Blocked By: Phase 2

  **References**: blueprint:2539, `D:\claude telegram bot\worker\src\services\student-report.ts`, blueprint:335-1236 (schema)

  **Acceptance Criteria**: [ ] Report service generates structured report, [ ] Endpoint returns report, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Generate student report
    Tool: Bash
    Steps: GET /api/teacher/students/:id/report, assert 200 with progress, scores, weaknesses
    Expected Result: Report generated
    Evidence: .sisyphus/evidence/task-8.1-report.txt
  ```

  **Commit**: YES | `task(8.1): student report generation service`

- [ ] 8.2. Student report PDF template

  **What to do**:
  - Create `worker/src/services/pdf.ts` — PDF generation library (use puppeteer or jsPDF or @react-pdf/renderer)
  - Create student report PDF template with: teacher branding (logo if Pro), student name, progress charts, scores, weaknesses, OSEE footer
  - Add `GET /api/teacher/students/:id/report.pdf` — returns PDF

  **Must NOT do**: Do not use Flutter for PDF generation (server-side only)

  **Recommended Agent Profile**: `deep` | Wave 8 | Blocks: 8.3 | Blocked By: 8.1

  **References**: blueprint:2540

  **Acceptance Criteria**: [ ] PDF generated with correct content, [ ] Teacher branding visible, [ ] OSEE footer present, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Download student report PDF
    Tool: Bash
    Steps: GET /api/teacher/students/:id/report.pdf, assert content-type application/pdf, save file, verify non-empty
    Expected Result: PDF generated
    Evidence: .sisyphus/evidence/task-8.2-report.pdf
  ```

  **Commit**: YES | `task(8.2): student report PDF template with teacher branding`

- [ ] 8.3. Report viewer page (Flutter)

  **What to do**: Create `flutter/lib/features/teacher/pages/report_viewer_page.dart` — displays report (from 8.1) in formatted view, download PDF button (from 8.2).

  **Recommended Agent Profile**: `visual-engineering` | Wave 8 | Blocked By: 8.1, 8.2

  **References**: blueprint:2541

  **Acceptance Criteria**: [ ] Page displays report, [ ] Download button works, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: View report in UI
    Tool: Playwright
    Steps: Navigate to student report, assert report content visible, click Download, assert PDF downloaded
    Expected Result: Report viewer functional
    Evidence: .sisyphus/evidence/task-8.3-viewer.png
  ```

  **Commit**: YES | `task(8.3): report viewer page (Flutter)`

- [ ] 8.4. Batch report generation (all students in classroom)

  **What to do**: Add `POST /api/teacher/classrooms/:id/reports` — generate reports for all students, return array. Add batch PDF generation.

  **Recommended Agent Profile**: `unspecified-high` | Wave 8 | Blocked By: 8.2

  **References**: blueprint:2542

  **Acceptance Criteria**: [ ] Batch generation works for all students, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Batch generate reports
    Tool: Bash
    Steps: POST /api/teacher/classrooms/:id/reports, assert array of reports returned
    Expected Result: Batch generation
    Evidence: .sisyphus/evidence/task-8.4-batch.txt
  ```

  **Commit**: YES | `task(8.4): batch report generation for classroom`

- [ ] 8.5. Report download/email feature

  **What to do**: Add email sending (use Cloudflare Email Workers or external service), `POST /api/teacher/students/:id/report/email` — sends PDF to parent/student email.

  **Recommended Agent Profile**: `unspecified-high` | Wave 8 | Blocked By: 8.2

  **References**: blueprint:2543

  **Acceptance Criteria**: [ ] Email with PDF attachment sent, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Email report
    Tool: Bash
    Steps: POST /api/teacher/students/:id/report/email -d '{"to":"parent@test.com"}', assert 202
    Expected Result: Email queued
    Evidence: .sisyphus/evidence/task-8.5-email.txt
  ```

  **Commit**: YES | `task(8.5): report download/email feature`

- [ ] 9.1. Classroom report aggregation service

  **What to do**: Create `worker/src/services/classroom-reports.ts` — aggregate all students' progress in a classroom: average scores, common weaknesses, progress trends. Add `GET /api/teacher/classrooms/:id/report`.

  **Recommended Agent Profile**: `deep` | Wave 9 | Blocks: 9.2-9.4 | Blocked By: 8.1

  **References**: blueprint:2546

  **Acceptance Criteria**: [ ] Classroom report aggregates correctly, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Classroom report
    Tool: Bash
    Steps: GET /api/teacher/classrooms/:id/report, assert averages, weaknesses, trends
    Expected Result: Aggregated classroom report
    Evidence: .sisyphus/evidence/task-9.1-classroom-report.txt
  ```

  **Commit**: YES | `task(9.1): classroom report aggregation service`

- [ ] 9.2. Classroom report PDF template

  **What to do**: Extend pdf.ts service with classroom report template: all students summary, charts, weakness distribution.

  **Recommended Agent Profile**: `deep` | Wave 9 | Blocked By: 9.1, 8.2

  **References**: blueprint:2547

  **Acceptance Criteria**: [ ] PDF generated, [ ] Contains all students, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Download classroom report PDF
    Tool: Bash
    Steps: GET /api/teacher/classrooms/:id/report.pdf, assert PDF
    Expected Result: Classroom PDF
    Evidence: .sisyphus/evidence/task-9.2-classroom-report.pdf
  ```

  **Commit**: YES | `task(9.2): classroom report PDF template`

- [ ] 9.3. Weakness heatmap visualization (Flutter)

  **What to do**: Create `flutter/lib/features/teacher/widgets/weakness_heatmap.dart` — visualize weakness areas across classroom as heatmap grid (sections × students, color-coded by weakness severity).

  **Recommended Agent Profile**: `visual-engineering` | Wave 9 | Blocked By: 9.1

  **References**: blueprint:2548

  **Acceptance Criteria**: [ ] Heatmap renders, [ ] Color-coded by severity, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Heatmap displays
    Tool: Playwright
    Steps: Navigate to classroom report, assert heatmap visible with color-coded cells
    Expected Result: Weakness heatmap
    Evidence: .sisyphus/evidence/task-9.3-heatmap.png
  ```

  **Commit**: YES | `task(9.3): weakness heatmap visualization (Flutter)`

- [ ] 9.4. Teacher effectiveness metrics

  **What to do**: Add to classroom report: teacher effectiveness metrics (student improvement rate, engagement, completion rate).

  **Recommended Agent Profile**: `deep` | Wave 9 | Blocked By: 9.1

  **References**: blueprint:2549

  **Acceptance Criteria**: [ ] Effectiveness metrics calculated, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Effectiveness metrics
    Tool: Bash
    Steps: GET classroom report, assert effectiveness section with metrics
    Expected Result: Teacher effectiveness shown
    Evidence: .sisyphus/evidence/task-9.4-effectiveness.txt
  ```

  **Commit**: YES | `task(9.4): teacher effectiveness metrics in classroom report`

- [ ] 10.1. Material library component (Flutter — left column)

  **What to do**: Create `flutter/lib/features/teacher/pages/syllabus_builder_page.dart` with two-column layout. Left column: material library (browsable list of materials from all platforms + AI-generated). Fetches from `GET /api/teacher/materials` which aggregates from platform bridge API.

  **Recommended Agent Profile**: `visual-engineering` | Wave 10 | Blocks: 10.3 | Blocked By: Phase 2

  **References**: blueprint:2551, blueprint:499-527 (syllabus_items source_type values)

  **Acceptance Criteria**: [ ] Material library renders, [ ] Materials from multiple sources, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Material library displays
    Tool: Playwright
    Steps: Navigate to syllabus builder, assert left column with material list
    Expected Result: Material library visible
    Evidence: .sisyphus/evidence/task-10.1-material-library.png
  ```

  **Commit**: YES | `task(10.1): material library component (Flutter)`

- [ ] 10.2. Syllabus timeline component (Flutter — right column)

  **What to do**: Right column of syllabus builder: timeline/list of syllabus items in order, with drag handles (for 10.3), unlock logic indicators, flavor tags.

  **Recommended Agent Profile**: `visual-engineering` | Wave 10 | Blocks: 10.3 | Blocked By: 10.1

  **References**: blueprint:2552, blueprint:483-527 (syllabus_items schema)

  **Acceptance Criteria**: [ ] Timeline renders syllabus items, [ ] Items in sort_order, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Timeline displays items
    Tool: Playwright
    Steps: Create syllabus with items, navigate to builder, assert items in timeline
    Expected Result: Syllabus timeline visible
    Evidence: .sisyphus/evidence/task-10.2-timeline.png
  ```

  **Commit**: YES | `task(10.2): syllabus timeline component (Flutter)`

- [ ] 10.3. Drag-and-drop implementation (Flutter ReorderableList)

  **What to do**: Implement drag-and-drop using Flutter's `ReorderableListView` (blueprint says @dndkit which is React — use Flutter equivalent). Drag items from material library (left) to timeline (right), reorder within timeline. On drop, update sort_order.

  **Must NOT do**: Do not use @dnd-kit (React library). Use Flutter's built-in ReorderableListView or package: flutter_reorderable_grid

  **Recommended Agent Profile**: `deep` | Wave 10 | Blocked By: 10.1, 10.2

  **References**: blueprint:2553, Flutter ReorderableListView docs

  **Acceptance Criteria**: [ ] Drag from library to timeline works, [ ] Reorder within timeline works, [ ] sort_order updated, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Drag material to syllabus
    Tool: Playwright
    Steps: Drag material from left column to right column, assert item added to timeline
    Expected Result: Drag-and-drop functional
    Evidence: .sisyphus/evidence/task-10.3-drag-drop.png

  Scenario: Reorder syllabus items
    Tool: Playwright
    Steps: Drag item from position 3 to position 1, assert order changed
    Expected Result: Reorder works
    Evidence: .sisyphus/evidence/task-10.3-reorder.png
  ```

  **Commit**: YES | `task(10.3): drag-and-drop syllabus builder (Flutter ReorderableList)`

- [ ] 10.4. Batch save (PUT syllabus items)

  **What to do**: Add `PUT /api/teacher/syllabi/:id/items` — accepts full array of syllabus items, replaces existing. Handle sort_order updates.

  **Recommended Agent Profile**: `quick` | Wave 10 | Blocked By: 10.3

  **References**: blueprint:2554

  **Acceptance Criteria**: [ ] Batch save works, [ ] sort_order preserved, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Batch save syllabus
    Tool: Bash
    Steps: PUT with 5 items, GET syllabus, assert 5 items in order
    Expected Result: Batch save
    Evidence: .sisyphus/evidence/task-10.4-batch-save.txt
  ```

  **Commit**: YES | `task(10.4): batch save syllabus items`

- [ ] 10.5. Material browser from all platforms (via platform bridge API)

  **What to do**: Create `worker/src/routes/platform.ts` — bridge API that fetches material catalogs from each practice platform. Add `GET /api/platforms/materials?platform=ibt` etc. If platforms don't have APIs, create curated catalog in Hub database.

  **Recommended Agent Profile**: `deep` | Wave 10 | Blocked By: Phase 2

  **References**: blueprint:2555, blueprint:299-333 (webhook flow shows platform integration)

  **Acceptance Criteria**: [ ] Materials from all platforms browsable, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Browse platform materials
    Tool: Bash
    Steps: GET /api/platforms/materials?platform=ibt, assert array of materials
    Expected Result: Platform bridge works
    Evidence: .sisyphus/evidence/task-10.5-platform-materials.txt
  ```

  **Commit**: YES | `task(10.5): material browser from all platforms via bridge API`

- [ ] 10.6. AI-generated materials integration (from Phase 2)

  **What to do**: Update material library (10.1) to include AI-generated materials (from 6.5) as a source. Filter by source_type=ai_generated.

  **Recommended Agent Profile**: `unspecified-high` | Wave 10 | Blocked By: 6.5, 10.1

  **References**: blueprint:2556

  **Acceptance Criteria**: [ ] AI-generated materials appear in library, [ ] Can be added to syllabus, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: AI materials in library
    Tool: Playwright
    Steps: Generate material (6.5), open syllabus builder, assert AI material in library
    Expected Result: AI materials integrated
    Evidence: .sisyphus/evidence/task-10.6-ai-materials.png
  ```

  **Commit**: YES | `task(10.6): AI-generated materials integration in syllabus builder`

- [ ] 11.1. Student dashboard (syllabus, progress, readiness)

  **What to do**: Create `flutter/lib/features/student/pages/student_dashboard_page.dart` — shows: current syllabus, recent progress, readiness gauge, cross-exam score map, book test CTA.

  **Recommended Agent Profile**: `visual-engineering` | Wave 11 | Blocks: 11.2-11.6 | Blocked By: 10.x

  **References**: blueprint:2560

  **Acceptance Criteria**: [ ] Dashboard renders all sections, [ ] Real data from API, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Student dashboard
    Tool: Playwright
    Steps: Login as student, navigate to /student, assert syllabus, progress, readiness visible
    Expected Result: Dashboard complete
    Evidence: .sisyphus/evidence/task-11.1-student-dashboard.png
  ```

  **Commit**: YES | `task(11.1): student dashboard (syllabus, progress, readiness)`

- [ ] 11.2. Syllabus view page (with deep links to practice platforms)

  **What to do**: Create `flutter/lib/features/student/pages/syllabus_view_page.dart` — displays assigned syllabus with items, deep links to practice platforms (ibt.osee.co.id etc.) for platform_ibt source items.

  **Recommended Agent Profile**: `visual-engineering` | Wave 11 | Blocked By: 11.1

  **References**: blueprint:2561, blueprint:494-498 (source_platform_url field)

  **Acceptance Criteria**: [ ] Syllabus items displayed, [ ] Deep links open platforms, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Click deep link
    Tool: Playwright
    Steps: View syllabus, click item with platform link, assert navigation to platform URL
    Expected Result: Deep links work
    Evidence: .sisyphus/evidence/task-11.2-deep-link.png
  ```

  **Commit**: YES | `task(11.2): syllabus view with deep links to practice platforms`

- [ ] 11.3. Progress tracking page

  **What to do**: Create `flutter/lib/features/student/pages/progress_page.dart` — visual progress over time, scores per section, improvement trends.

  **Recommended Agent Profile**: `visual-engineering` | Wave 11 | Blocked By: 11.1, 3.3

  **References**: blueprint:2562

  **Acceptance Criteria**: [ ] Progress charts render, [ ] Data from /api/student/progress, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Progress page
    Tool: Playwright
    Steps: Navigate to progress, assert charts/scores visible
    Expected Result: Progress tracked
    Evidence: .sisyphus/evidence/task-11.3-progress.png
  ```

  **Commit**: YES | `task(11.3): progress tracking page (Flutter)`

- [ ] 11.4. Readiness gauge component (Flutter)

  **What to do**: Create `flutter/lib/features/student/widgets/readiness_gauge.dart` — circular gauge showing exam readiness percentage based on progress data.

  **Recommended Agent Profile**: `visual-engineering` | Wave 11 | Blocked By: 11.1

  **References**: blueprint:2563

  **Acceptance Criteria**: [ ] Gauge renders with percentage, [ ] Color-coded (red/yellow/green), [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Readiness gauge
    Tool: Playwright
    Steps: View dashboard, assert gauge visible with percentage
    Expected Result: Readiness gauge
    Evidence: .sisyphus/evidence/task-11.4-gauge.png
  ```

  **Commit**: YES | `task(11.4): readiness gauge component (Flutter)`

- [ ] 11.5. Cross-exam score map component (Flutter)

  **What to do**: Create `flutter/lib/features/student/widgets/cross_exam_map.dart` — shows student's scores across TOEFL iBT, IELTS, TOEIC side by side with conversion chart.

  **Recommended Agent Profile**: `visual-engineering` | Wave 11 | Blocked By: 11.1

  **References**: blueprint:2564

  **Acceptance Criteria**: [ ] Cross-exam scores displayed, [ ] Conversion shown, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Cross-exam map
    Tool: Playwright
    Steps: View dashboard, assert cross-exam section with scores
    Expected Result: Cross-exam comparison
    Evidence: .sisyphus/evidence/task-11.5-cross-exam.png
  ```

  **Commit**: YES | `task(11.5): cross-exam score map component (Flutter)`

- [ ] 11.6. Contextual "Book Official Test" CTA (only when readiness > 80%)

  **What to do**: Add CTA banner that appears only when readiness > 80%, links to osee.co.id booking.

  **Recommended Agent Profile**: `quick` | Wave 11 | Blocked By: 11.4

  **References**: blueprint:2565

  **Acceptance Criteria**: [ ] CTA hidden when readiness < 80%, [ ] CTA visible when > 80%, [ ] Links to osee.co.id

  **QA Scenarios**:
  ```
  Scenario: CTA hidden at low readiness
    Tool: Playwright
    Steps: Student with 60% readiness, assert no "Book Test" CTA
    Expected Result: CTA hidden
    Evidence: .sisyphus/evidence/task-11.6-cta-hidden.png

  Scenario: CTA shown at high readiness
    Tool: Playwright
    Steps: Student with 85% readiness, assert "Book Official Test" CTA visible
    Expected Result: CTA shown
    Evidence: .sisyphus/evidence/task-11.6-cta-shown.png
  ```

  **Commit**: YES | `task(11.6): contextual Book Official Test CTA (readiness > 80%)`

> **PHASE 3 BOUNDARY**: Tasks 8.1-11.6 complete. Git tag `phase-3-complete`.

- [ ] 12.1. Commission dashboard page (Flutter)

  **What to do**: Create `flutter/lib/features/teacher/pages/commission_dashboard_page.dart` — earnings summary, breakdown by type (first_practice, test_booking, edubot_premium), history table. Add `GET /api/teacher/commission/dashboard`.

  **Recommended Agent Profile**: `visual-engineering` | Wave 12 | Blocked By: Phase 3, 3.4

  **References**: blueprint:2572, blueprint:2193-2321 (Section 9 Commission System)

  **Acceptance Criteria**: [ ] Dashboard shows earnings, breakdown, history, [ ] Real data from commission_ledger, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Commission dashboard
    Tool: Playwright
    Steps: Navigate to /teacher/commission, assert earnings total, breakdown chart, history table
    Expected Result: Commission dashboard complete
    Evidence: .sisyphus/evidence/task-12.1-commission-dashboard.png
  ```

  **Commit**: YES | `task(12.1): commission dashboard page (Flutter)`

- [ ] 12.2. Payout request system (worker + Flutter)

  **What to do**: Add `POST /api/teacher/commission/payout` — teacher requests payout of accumulated commission. Creates payout request in commission_ledger with status=pending_payout. Add UI form on dashboard.

  **Recommended Agent Profile**: `deep` | Wave 12 | Blocked By: 12.1

  **References**: blueprint:2573, blueprint:2193-2321

  **Acceptance Criteria**: [ ] Payout request creates entry, [ ] Min payout amount enforced, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Request payout
    Tool: Bash
    Steps: POST /api/teacher/commission/payout -d '{"amount":50000,"method":"bank_transfer"}', assert 201
    Expected Result: Payout requested
    Evidence: .sisyphus/evidence/task-12.2-payout.txt
  ```

  **Commit**: YES | `task(12.2): payout request system`

- [ ] 12.3. Payout tracking (pending → confirmed → paid)

  **What to do**: Add admin endpoints: `POST /api/admin/payouts/:id/confirm`, `POST /api/admin/payouts/:id/mark-paid`. Update status transitions. Admin UI in frontend-admin.

  **Recommended Agent Profile**: `deep` | Wave 12 | Blocked By: 12.2

  **References**: blueprint:2574

  **Acceptance Criteria**: [ ] Status transitions work, [ ] Admin can confirm/mark paid, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Mark payout paid
    Tool: Bash
    Steps: POST /api/admin/payouts/:id/mark-paid, assert status=paid
    Expected Result: Payout tracking
    Evidence: .sisyphus/evidence/task-12.3-payout-tracking.txt
  ```

  **Commit**: YES | `task(12.3): payout tracking - pending → confirmed → paid`

- [ ] 12.4. AI quota bonus system

  **What to do**: Create `worker/src/services/quota-bonus.ts` — teachers earn bonus AI credits by bringing students. E.g. +5 grading credits per student who completes first practice. Update quota checking to add bonus.

  **Recommended Agent Profile**: `deep` | Wave 12 | Blocked By: 3.4, 5.4

  **References**: blueprint:2575, blueprint:2293-2321 (AI quota bonus)

  **Acceptance Criteria**: [ ] Bonus credits awarded on student milestones, [ ] Quota reflects bonus, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Earn bonus credits
    Tool: Bash
    Steps: Student completes first practice, teacher's quota limit increases by 5
    Expected Result: Bonus system active
    Evidence: .sisyphus/evidence/task-12.4-bonus.txt
  ```

  **Commit**: YES | `task(12.4): AI quota bonus system`

- [ ] 12.5. Ambassador program (2x rates, badge, featured)

  **What to do**: Add `is_ambassador` flag to unified_profiles. Admin endpoint to set ambassador. Commission service (3.4) already handles 2x — verify. Add ambassador badge UI, featured listing. Add `GET /api/ambassadors` public endpoint.

  **Recommended Agent Profile**: `unspecified-high` | Wave 12 | Blocked By: 3.4

  **References**: blueprint:2576

  **Acceptance Criteria**: [ ] Ambassador flag works, [ ] 2x commission (already in 3.4), [ ] Badge displays, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Ambassador badge
    Tool: Playwright
    Steps: Set teacher as ambassador, view their profile, assert badge visible
    Expected Result: Ambassador recognized
    Evidence: .sisyphus/evidence/task-12.5-ambassador.png
  ```

  **Commit**: YES | `task(12.5): ambassador program - 2x rates, badge, featured`

- [ ] 13.1. Video course management (admin React)

  **What to do**: Create `frontend-admin/src/pages/VideoCourses.tsx` — CRUD for video courses: title, description, category, free/premium, YouTube preview URL, R2 full video URL.

  **Recommended Agent Profile**: `visual-engineering` | Wave 13 | Blocked By: Phase 3, 1.9

  **References**: blueprint:2579, blueprint:2322-2410 (Section 10 Video Content)

  **Acceptance Criteria**: [ ] Admin can create/edit/delete video courses, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Create video course
    Tool: Playwright
    Steps: Navigate admin, create course, assert in list
    Expected Result: Video course management
    Evidence: .sisyphus/evidence/task-13.1-video-admin.png
  ```

  **Commit**: YES | `task(13.1): video course management (admin React)`

- [ ] 13.2. Video lesson player (Flutter — with comprehension quiz overlay)

  **What to do**: Create `flutter/lib/features/student/widgets/video_player.dart` — plays video (YouTube embed or R2 stream), shows comprehension quiz overlay at timestamps.

  **Recommended Agent Profile**: `visual-engineering` | Wave 13 | Blocked By: 13.1

  **References**: blueprint:2580

  **Acceptance Criteria**: [ ] Video plays, [ ] Quiz overlay appears at timestamps, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Video with quiz
    Tool: Playwright
    Steps: Play video, wait for quiz timestamp, assert quiz overlay
    Expected Result: Interactive video
    Evidence: .sisyphus/evidence/task-13.2-video-player.png
  ```

  **Commit**: YES | `task(13.2): video lesson player with comprehension quiz (Flutter)`

- [ ] 13.3. Video progress tracking

  **What to do**: Track video watch progress, quiz completion. Add `POST /api/student/videos/:id/progress` endpoint.

  **Recommended Agent Profile**: `deep` | Wave 13 | Blocked By: 13.2

  **References**: blueprint:2581

  **Acceptance Criteria**: [ ] Progress tracked, [ ] Quiz scores saved, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Track video progress
    Tool: Bash
    Steps: POST progress 50%, assert saved
    Expected Result: Progress tracked
    Evidence: .sisyphus/evidence/task-13.3-progress.txt
  ```

  **Commit**: YES | `task(13.3): video progress tracking`

- [ ] 13.4. Video course library page (Flutter student)

  **What to do**: Create `flutter/lib/features/student/pages/video_library_page.dart` — browsable library of video courses with free/premium filter.

  **Recommended Agent Profile**: `visual-engineering` | Wave 13 | Blocked By: 13.1

  **References**: blueprint:2582

  **Acceptance Criteria**: [ ] Library renders, [ ] Free/premium filter works, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Video library
    Tool: Playwright
    Steps: Navigate to /student/videos, assert course list, filter free
    Expected Result: Video library
    Evidence: .sisyphus/evidence/task-13.4-video-library.png
  ```

  **Commit**: YES | `task(13.4): video course library page (Flutter)`

- [ ] 13.5. Free preview (YouTube) vs premium (R2) gating

  **What to do**: Video player shows YouTube preview for free users, R2 full video for premium. Check user subscription status.

  **Recommended Agent Profile**: `deep` | Wave 13 | Blocked By: 13.2

  **References**: blueprint:2583

  **Acceptance Criteria**: [ ] Free users see preview only, [ ] Premium see full video, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Free user sees preview
    Tool: Playwright
    Steps: As free user, open video, assert YouTube preview, no R2 access
    Expected Result: Gating works
    Evidence: .sisyphus/evidence/task-13.5-gating.png
  ```

  **Commit**: YES | `task(13.5): free preview vs premium video gating`

- [ ] 13.6. Teacher assigns video lessons to syllabus

  **What to do**: Update syllabus builder (10.x) to allow adding video lessons as syllabus_items with source_type='video_lesson'.

  **Recommended Agent Profile**: `unspecified-high` | Wave 13 | Blocked By: 10.3, 13.1

  **References**: blueprint:2584

  **Acceptance Criteria**: [ ] Videos can be added to syllabus, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Add video to syllabus
    Tool: Playwright
    Steps: In syllabus builder, add video lesson, assert in timeline
    Expected Result: Video assignable
    Evidence: .sisyphus/evidence/task-13.6-video-syllabus.png
  ```

  **Commit**: YES | `task(13.6): teacher can assign video lessons to syllabus`

- [ ] 14.1. Live class management (admin React form)

  **What to do**: Create `frontend-admin/src/pages/LiveClasses.tsx` — form to schedule live classes: title, date, time, Zoom link, description, target audience.

  **Recommended Agent Profile**: `visual-engineering` | Wave 14 | Blocked By: Phase 3

  **References**: blueprint:2587, blueprint:2411-2470 (Section 11 Live Class)

  **Acceptance Criteria**: [ ] Admin can create/edit live classes, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Schedule live class
    Tool: Playwright
    Steps: Admin form, create class, assert in list
    Expected Result: Live class scheduled
    Evidence: .sisyphus/evidence/task-14.1-live-class.png
  ```

  **Commit**: YES | `task(14.1): live class management (admin React)`

- [ ] 14.2. Upcoming classes page (Flutter student)

  **What to do**: Create `flutter/lib/features/student/pages/upcoming_classes_page.dart` — list of upcoming live classes with join button.

  **Recommended Agent Profile**: `visual-engineering` | Wave 14 | Blocked By: 14.1

  **References**: blueprint:2588

  **Acceptance Criteria**: [ ] Upcoming classes displayed, [ ] Join button opens Zoom link, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: View upcoming classes
    Tool: Playwright
    Steps: Navigate to /student/classes, assert list, click join
    Expected Result: Classes visible
    Evidence: .sisyphus/evidence/task-14.2-classes.png
  ```

  **Commit**: YES | `task(14.2): upcoming classes page (Flutter)`

- [ ] 14.3. EduBot integration (Zoom link sharing via Telegram)

  **What to do**: Create service that sends live class notifications to EduBot Telegram bot. Add `POST /api/classes/:id/notify` — triggers Telegram message via EduBot bridge.

  **Must NOT do**: Do not modify EduBot — use its API

  **Recommended Agent Profile**: `deep` | Wave 14 | Blocked By: 14.1

  **References**: blueprint:2589, `D:\claude telegram bot\worker\src\` (EduBot API)

  **Acceptance Criteria**: [ ] Telegram notification sent via EduBot, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Notify via Telegram
    Tool: Bash
    Steps: POST /api/classes/:id/notify, assert 200, check Telegram message sent (mock or real)
    Expected Result: Notification sent
    Evidence: .sisyphus/evidence/task-14.3-telegram.txt
  ```

  **Commit**: YES | `task(14.3): EduBot integration - Zoom link via Telegram`

- [ ] 14.4. Auto-reminder cron (1 hour before class)

  **What to do**: Create Cloudflare Workers Cron Trigger that runs every minute, checks for classes starting in ~1 hour, sends reminders.

  **Recommended Agent Profile**: `deep` | Wave 14 | Blocked By: 14.3

  **References**: blueprint:2590

  **Acceptance Criteria**: [ ] Cron trigger configured in wrangler.toml, [ ] Reminders sent 1hr before, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Reminder fires
    Tool: Bash
    Steps: Insert class starting in 55 min, trigger cron manually, assert reminder sent
    Expected Result: Auto-reminder
    Evidence: .sisyphus/evidence/task-14.4-cron.txt
  ```

  **Commit**: YES | `task(14.4): auto-reminder cron (1 hour before class)`

- [ ] 14.5. Post-class recording upload + notification

  **What to do**: Admin uploads recording to R2, students notified. Add `POST /api/classes/:id/recording` upload endpoint + notification trigger.

  **Recommended Agent Profile**: `unspecified-high` | Wave 14 | Blocked By: 14.3

  **References**: blueprint:2591

  **Acceptance Criteria**: [ ] Recording uploaded to R2, [ ] Students notified, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Upload recording
    Tool: Bash
    Steps: POST recording, assert URL returned, notification sent
    Expected Result: Recording available
    Evidence: .sisyphus/evidence/task-14.5-recording.txt
  ```

  **Commit**: YES | `task(14.5): post-class recording upload + notification`

- [ ] 15.1. Branding config system

  **What to do**: Create `worker/src/services/branding.ts` — manages branding config per institution: logo URL, primary color, custom name, hide OSEE branding flag. Store in branding_config table. Add `GET /api/branding/:institutionId`.

  **Recommended Agent Profile**: `deep` | Wave 15 | Blocked By: Phase 3

  **References**: blueprint:2594

  **Acceptance Criteria**: [ ] Branding config CRUD, [ ] Institutions can customize, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Custom branding
    Tool: Bash
    Steps: Set branding config, GET /api/branding/:id, assert custom values
    Expected Result: Branding configurable
    Evidence: .sisyphus/evidence/task-15.1-branding.txt
  ```

  **Commit**: YES | `task(15.1): branding config system`

- [ ] 15.2. Pro tier upgrade page + payment (TriPay bridge)

  **What to do**: Create `flutter/lib/features/teacher/pages/upgrade_page.dart` — Pro tier upgrade with payment via TriPay. Bridge to EduBot's TriPay service. Add `POST /api/payment/pro` endpoint. Read `D:\claude telegram bot\worker\src\routes\payment.ts` and `D:\claude telegram bot\worker\src\services\tripay.ts`.

  **Recommended Agent Profile**: `deep` | Wave 15 | Blocked By: 15.1

  **References**: blueprint:2595, `D:\claude telegram bot\worker\src\routes\payment.ts`, `D:\claude telegram bot\worker\src\services\tripay.ts`

  **Acceptance Criteria**: [ ] Upgrade page renders, [ ] Payment via TriPay works, [ ] Pro status updated, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Upgrade to Pro
    Tool: Playwright + Bash
    Steps: Navigate to upgrade, select Pro, complete payment (test mode), assert pro status
    Expected Result: Upgrade flow
    Evidence: .sisyphus/evidence/task-15.2-upgrade.png
  ```

  **Commit**: YES | `task(15.2): Pro tier upgrade page + TriPay payment`

- [ ] 15.3. Institution tier (custom subdomain, multi-teacher)

  **What to do**: Support institution accounts: custom subdomain (e.g. school.prep.osee.co.id), multiple teachers under one institution, admin dashboard for institution admin.

  **Recommended Agent Profile**: `deep` | Wave 15 | Blocked By: 15.1

  **References**: blueprint:2596

  **Acceptance Criteria**: [ ] Institution can have multiple teachers, [ ] Custom subdomain routes, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Institution multi-teacher
    Tool: Bash
    Steps: Create institution, add 3 teachers, assert all under institution
    Expected Result: Institution tier
    Evidence: .sisyphus/evidence/task-15.3-institution.txt
  ```

  **Commit**: YES | `task(15.3): institution tier - custom subdomain, multi-teacher`

- [ ] 15.4. OSEE branding hide/show logic (free = visible, pro = hideable)

  **What to do**: Update branding widget (2.5) to read branding config. Free tier: always visible. Pro: can hide. Institution: always hidden (white-label).

  **Recommended Agent Profile**: `quick` | Wave 15 | Blocked By: 15.1, 2.5

  **References**: blueprint:2597

  **Acceptance Criteria**: [ ] Free: branding visible, [ ] Pro: can hide, [ ] Institution: hidden, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Pro hides branding
    Tool: Playwright
    Steps: Pro teacher toggles hide branding, assert widget not visible
    Expected Result: Branding hideable for Pro
    Evidence: .sisyphus/evidence/task-15.4-branding-hide.png
  ```

  **Commit**: YES | `task(15.4): OSEE branding hide/show logic by tier`

- [ ] 15.5. Pricing config system (admin sets prices per role per test type)

  **What to do**:
  - Create `worker/src/services/pricing.ts` — getPricing(itemType, role): looks up pricing_config table, returns price for that item_type + role combination. Falls back to student price if no specific pricing found.
  - Add admin API endpoints in `worker/src/routes/admin.ts`:
    - `GET /api/admin/pricing` — list all pricing config entries
    - `POST /api/admin/pricing` — set/update price for {item_type, role, price}
    - `DELETE /api/admin/pricing/:id` — deactivate a pricing entry
  - Add `GET /api/pricing` (public, no admin auth) — returns pricing for current user's role (for display on order pages)
  - Seed default pricing: student pays full price, teacher gets discount, partner gets bigger discount:
    - mock_itp: student Rp 120k, teacher Rp 100k, partner Rp 80k
    - mock_ibt: student Rp 250k, teacher Rp 220k, partner Rp 200k
    - mock_ielts: student Rp 250k, teacher Rp 220k, partner Rp 200k
    - mock_toeic: student Rp 150k, teacher Rp 130k, partner Rp 110k
    - tutor_bot_premium: student Rp 30k/mo, teacher Rp 25k/mo, partner Rp 20k/mo
    - official_toefl: student Rp 2.500k, teacher Rp 2.300k, partner Rp 2.100k
    - official_toeic: student Rp 800k, teacher Rp 750k, partner Rp 700k
  - Create `scripts/seed-pricing.ts` to seed default pricing
  - Write vitest tests: getPricing returns correct price per role, fallback to student price, admin can update

  **Must NOT do**:
  - Do not hardcode prices in the order service — always query pricing_config
  - Do not allow negative prices
  - Do not expose admin pricing endpoints to non-admin users

  **Recommended Agent Profile**:
  - **Category**: `quick` — service + CRUD endpoints + seed script
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 15.6 — pricing is read, order is write)
  - **Parallel Group**: Wave 15
  - **Blocks**: 15.6 (order service needs pricing), 15.7, 15.8 (order pages need pricing display)
  - **Blocked By**: 1.1 (schema with pricing_config table), 15.1 (branding system — Phase 4D context)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:48-67` — Revenue model (existing commission rates)
  - `C:\Users\user\osee-prep-hub-blueprint.md:102-108` — Existing Assets (platform pricing: IBT Rp 250k/session, etc.)
  - Order system schema (added in Task 1.1): pricing_config table definition

  **WHY Each Reference Matters**:
  - Revenue model shows existing pricing context — new pricing must align with commission system
  - Existing Assets section lists current platform prices (IBT Rp 250k) — teacher/partner discounts should be below these
  - The pricing_config table (added to schema in Task 1.1) is the data model for this service

  **Acceptance Criteria**:
  - [ ] `worker/src/services/pricing.ts` exists with getPricing(itemType, role)
  - [ ] Admin endpoints work: GET/POST/DELETE for pricing config
  - [ ] `GET /api/pricing` returns prices for current user's role
  - [ ] `scripts/seed-pricing.ts` seeds all 7 item types × 3 roles (21 entries)
  - [ ] getPricing falls back to student price if role-specific price missing
  - [ ] Negative prices rejected
  - [ ] Non-admin cannot access admin pricing endpoints (403)
  - [ ] Vitest tests pass

  **QA Scenarios**:
  ```
  Scenario: Get pricing for teacher role
    Tool: Bash
    Preconditions: pricing seeded, authenticated as teacher
    Steps:
      1. curl -H "Authorization: Bearer <teacher_token>" http://localhost:8787/api/pricing
      2. Assert: HTTP 200
      3. Assert: JSON contains all 7 item types with teacher prices
      4. Assert: mock_ibt price = 220000 (less than student 250000)
    Expected Result: Teacher sees discounted pricing
    Evidence: .sisyphus/evidence/task-15.5-teacher-pricing.txt

  Scenario: Admin updates pricing
    Tool: Bash
    Preconditions: admin authenticated
    Steps:
      1. curl -X POST /api/admin/pricing -d '{"item_type":"mock_ibt","role":"teacher","price":210000}'
      2. Assert: HTTP 201 or 200
      3. curl /api/pricing (as teacher)
      4. Assert: mock_ibt price now 210000
    Expected Result: Admin can update pricing
    Evidence: .sisyphus/evidence/task-15.5-update-pricing.txt

  Scenario: Non-admin cannot set pricing
    Tool: Bash
    Preconditions: teacher authenticated
    Steps:
      1. curl -X POST /api/admin/pricing -d '{"item_type":"mock_ibt","role":"teacher","price":1}' -H "Authorization: Bearer <teacher_token>"
      2. Assert: HTTP 403
    Expected Result: Only admin can modify pricing
    Evidence: .sisyphus/evidence/task-15.5-non-admin-blocked.txt
  ```

  **Commit**: YES | `task(15.5): pricing config system - admin CRUD + getPricing service + seed script`
  - Files: worker/src/services/pricing.ts, worker/src/routes/admin.ts, worker/src/routes/admin.test.ts, scripts/seed-pricing.ts
  - Pre-commit: `cd worker && npx vitest run`

- [ ] 15.6. Order service + API (create order, 4 modes, vouchers, fulfillment)

  **What to do**:
  - Create `worker/src/services/orders.ts` with:
    - `createOrder(userId, items[], orderType)` — validates pricing (from 15.5), calculates total, creates order + order_items, returns order
    - `processPayment(orderId, paymentMethod)` — calls TriPay (reuse EduBot's TriPay pattern), updates order.status='paid' on success
    - `fulfillOrder(orderId)` — based on order_type:
      - voucher_resale: generate N voucher codes per item, store in vouchers table
      - book_for_student: bridge to osee.co.id booking system for official tests (Task 15.10)
      - bulk_purchase: generate vouchers + assign to specified students
      - self_purchase: grant access to the buyer directly
    - `getOrder(orderId)`, `listOrders(userId)`, `cancelOrder(orderId)`
    - `generateVoucherCode()` — 12-char alphanumeric, collision-checked
  - Create `worker/src/routes/orders.ts`:
    - `POST /api/orders` — create order (auth required)
    - `GET /api/orders` — list user's orders
    - `GET /api/orders/:id` — order detail with items + vouchers
    - `POST /api/orders/:id/cancel` — cancel pending order
    - `POST /api/orders/:id/pay` — initiate payment (returns TriPay redirect URL)
    - `POST /api/orders/webhook/tripay` — TriPay payment callback webhook
  - Register routes in index.ts
  - Write vitest tests covering: order creation, pricing validation, voucher generation, all 4 order types, cancellation

  **Must NOT do**:
  - Do not fulfill orders before payment confirms (except self_purchase for free items)
  - Do not generate vouchers without collision check
  - Do not allow ordering items not in pricing_config
  - Do not allow cross-user order access

  **Recommended Agent Profile**:
  - **Category**: `deep` — financial logic, 4 fulfillment modes, payment integration, voucher system
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: NO (depends on 15.5 for pricing)
  - **Parallel Group**: Wave 15
  - **Blocks**: 15.7 (teacher order UI), 15.8 (partner order UI), 15.9 (voucher redemption)
  - **Blocked By**: 15.5 (pricing), 1.1 (schema with orders/vouchers tables), 15.2 (TriPay integration pattern)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2666-2668` — Section 13 folder structure (commission.ts, quota.ts services pattern)
  - `D:\claude telegram bot\worker\src\routes\payment.ts` — EduBot's payment route (TriPay integration pattern)
  - `D:\claude telegram bot\worker\src\services\tripay.ts` — EduBot's TriPay service (reuse pattern)
  - `D:\claude telegram bot\worker\src\services\referral-commission.ts` — EduBot's commission logic (pattern for financial transactions)
  - `D:\claude telegram bot\worker\src\services\referral-commission.test.ts` — EduBot's financial test patterns
  - Order system schema (Task 1.1): orders, order_items, vouchers table definitions

  **WHY Each Reference Matters**:
  - EduBot's payment route + TriPay service shows how this team integrates payments — follow same pattern for order payments
  - EduBot's commission service + tests show how this team handles financial logic with idempotency — same patterns needed for orders
  - The order system schema (added to schema.sql in Task 1.1) defines the data model

  **Acceptance Criteria**:
  - [ ] POST /api/orders creates order with correct pricing
  - [ ] Order total calculated from pricing_config (not hardcoded)
  - [ ] Payment via TriPay works (test mode)
  - [ ] Voucher codes generated (12-char, unique) for voucher_resale + bulk_purchase
  - [ ] Vouchers assigned to students for bulk_purchase
  - [ ] book_for_student creates external booking (via Task 15.10 bridge)
  - [ ] self_purchase grants access directly
  - [ ] Order cancellation works (pending only, refunds if paid)
  - [ ] TriPay webhook updates order status
  - [ ] Cross-user access prevented (403)
  - [ ] Vitest tests pass

  **QA Scenarios**:
  ```
  Scenario: Create voucher resale order (teacher buys 5 IBT vouchers)
    Tool: Bash
    Preconditions: authenticated as teacher, pricing seeded
    Steps:
      1. curl -X POST /api/orders -d '{"order_type":"voucher_resale","items":[{"item_type":"mock_ibt","quantity":5}]}'
      2. Assert: HTTP 201
      3. Assert: response has order with total_amount = 5 * 220000 = 1100000
      4. Assert: status = "pending"
      5. Note order_id
      6. curl -X POST /api/orders/<order_id>/pay -d '{"payment_method":"tripay_qris"}'
      7. Assert: 200 with payment redirect URL
    Expected Result: Order created with correct pricing
    Evidence: .sisyphus/evidence/task-15.6-create-order.txt

  Scenario: Paid order generates vouchers
    Tool: Bash
    Preconditions: order paid (simulate TriPay webhook)
    Steps:
      1. curl -X POST /api/orders/webhook/tripay -d '{"merchant_ref":"<order_id>","status":"paid"}' -H "X-Callback-Signature: <sig>"
      2. Assert: HTTP 200
      3. curl /api/orders/<order_id>
      4. Assert: status = "paid"
      5. Assert: 5 vouchers with unique codes in response
      6. Assert: each voucher status = "active"
    Expected Result: Payment triggers voucher generation
    Evidence: .sisyphus/evidence/task-15.6-vouchers-generated.txt

  Scenario: Bulk purchase assigns vouchers to students
    Tool: Bash
    Preconditions: teacher with 3 students enrolled
    Steps:
      1. curl -X POST /api/orders -d '{"order_type":"bulk_purchase","items":[{"item_type":"mock_ielts","quantity":3,"assigned_student_ids":["<id1>","<id2>","<id3>"]}]}'
      2. Pay order (simulate webhook)
      3. curl /api/orders/<order_id>
      4. Assert: 3 vouchers, each assigned to a student via order_items.assigned_student_id
    Expected Result: Bulk purchase assigns to specific students
    Evidence: .sisyphus/evidence/task-15.6-bulk-purchase.txt

  Scenario: Book official test for student
    Tool: Bash
    Preconditions: teacher has student
    Steps:
      1. curl -X POST /api/orders -d '{"order_type":"book_for_student","items":[{"item_type":"official_toefl","quantity":1,"assigned_student_id":"<id>"}]}'
      2. Pay order
      3. Assert: fulfillment_status = "booking_confirmed" or "pending" (awaiting Task 15.10 bridge)
      4. Assert: external_booking_id set (if bridge available) or order queued
    Expected Result: Official test booking initiated
    Evidence: .sisyphus/evidence/task-15.6-book-official.txt

  Scenario: Cancel pending order
    Tool: Bash
    Steps:
      1. Create order (pending)
      2. curl -X POST /api/orders/<order_id>/cancel
      3. Assert: status = "cancelled"
      4. Assert: no vouchers generated
    Expected Result: Pending orders cancellable
    Evidence: .sisyphus/evidence/task-15.6-cancel.txt

  Scenario: Cross-user access blocked
    Tool: Bash
    Preconditions: order owned by teacher A
    Steps:
      1. As teacher B, curl /api/orders/<teacher_a_order_id>
      2. Assert: HTTP 403 or 404
    Expected Result: Users can only see their own orders
    Evidence: .sisyphus/evidence/task-15.6-cross-user-blocked.txt
  ```

  **Commit**: YES | `task(15.6): order service + API - 4 modes, vouchers, TriPay payment, fulfillment`
  - Files: worker/src/services/orders.ts, worker/src/routes/orders.ts, worker/src/routes/orders.test.ts, worker/src/index.ts (route registration)
  - Pre-commit: `cd worker && npx vitest run src/routes/orders.test.ts`

- [ ] 15.7. Teacher order page (Flutter)

  **What to do**:
  - Create `flutter/lib/features/teacher/pages/order_page.dart` — test ordering interface:
    - Grid/list of 7 orderable items with prices (fetched from GET /api/pricing)
    - Each item card: icon, name, description, price (teacher rate), "Order" button
    - Order modal: select quantity, order_type (voucher_resale, bulk_purchase, self_purchase, book_for_student if official test), select students (for bulk/book_for_student), "Place Order" button
    - Order confirmation: shows total, payment method (TriPay), redirects to payment
    - Order history tab: list of past orders with status
    - Voucher management tab: list active vouchers with codes, copy code button, share button
  - Create `flutter/lib/features/teacher/providers/order_provider.dart` — Riverpod notifier managing: fetch pricing, create order, poll payment status, fetch order history, fetch vouchers
  - Create `flutter/lib/features/teacher/models/order.dart` — Order, OrderItem, Voucher models with json_serializable
  - Write widget tests

  **Must NOT do**:
  - Do not build partner-specific UI (Task 15.8)
  - Do not show student pricing (teacher sees teacher prices)
  - Do not allow ordering without payment method selection

  **Recommended Agent Profile**:
  - **Category**: `visual-engineering` — Flutter UI with multiple views, forms, payment flow
  - **Skills**: [] — Flutter UI

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 15.8 — different role UIs)
  - **Parallel Group**: Wave 15
  - **Blocks**: none
  - **Blocked By**: 15.5 (pricing API), 15.6 (order API), 1.5 (Flutter project)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2595` — Task 15.2 upgrade page pattern (payment UI in Flutter)
  - `D:\claude telegram bot\frontend\src\` — EduBot's React frontend (for understanding payment UI patterns, not copying)

  **WHY Each Reference Matters**:
  - Task 15.2 establishes the Flutter payment UI pattern — order page follows same TriPay flow
  - EduBot's frontend shows how this team structures payment-adjacent UIs

  **Acceptance Criteria**:
  - [ ] Order page renders 7 item cards with correct teacher prices
  - [ ] Order modal allows selecting quantity + order_type
  - [ ] For bulk_purchase: student multi-select works
  - [ ] For book_for_student: student select works
  - [ ] Place Order creates order via API
  - [ ] Payment redirects to TriPay
  - [ ] Order history tab shows past orders with status
  - [ ] Voucher tab shows codes with copy/share
  - [ ] Widget tests pass

  **QA Scenarios**:
  ```
  Scenario: Teacher views orderable items with prices
    Tool: Playwright
    Preconditions: teacher logged in, pricing seeded
    Steps:
      1. Navigate to /teacher/orders
      2. Assert: 7 item cards visible (ITP, IBT, IELTS, TOEIC, Tutor Bot, Official TOEFL, Official TOEIC)
      3. Assert: each shows teacher price (not student price)
      4. Assert: IBT shows Rp 220,000 (or configured teacher price)
      5. Screenshot
    Expected Result: All 7 orderable items displayed with teacher pricing
    Evidence: .sisyphus/evidence/task-15.7-order-page.png

  Scenario: Teacher orders 3 ITP vouchers
    Tool: Playwright
    Preconditions: on order page
    Steps:
      1. Click "Order" on ITP mock card
      2. Select quantity: 3
      3. Select order_type: "Buy vouchers to resell"
      4. Click "Place Order"
      5. Assert: confirmation shows total = 3 × teacher ITP price
      6. Click "Pay" → redirects to TriPay
      7. Screenshot
    Expected Result: Order placed with correct total
    Evidence: .sisyphus/evidence/task-15.7-order-vouchers.png

  Scenario: Teacher bulk-purchases for students
    Tool: Playwright
    Preconditions: teacher with enrolled students
    Steps:
      1. Click "Order" on IELTS card
      2. Select order_type: "Bulk purchase for students"
      3. Select 3 students from dropdown
      4. Assert: quantity auto-set to 3
      5. Place Order, Pay
      6. Navigate to Voucher tab
      7. Assert: 3 vouchers, each assigned to a student
    Expected Result: Bulk purchase assigns vouchers
    Evidence: .sisyphus/evidence/task-15.7-bulk-purchase.png

  Scenario: Teacher books official TOEFL for student
    Tool: Playwright
    Preconditions: teacher with student needing official test
    Steps:
      1. Click "Order" on Official TOEFL card
      2. Select order_type: "Book test for student"
      3. Select student
      4. Place Order, Pay
      5. Assert: order status "booking_confirmed" or "pending"
    Expected Result: Official test booking initiated
    Evidence: .sisyphus/evidence/task-15.7-book-official.png

  Scenario: Order history displays
    Tool: Playwright
    Preconditions: past orders exist
    Steps:
      1. Navigate to order page, click "History" tab
      2. Assert: list of past orders with status badges
      3. Click an order → detail view with items + vouchers
    Expected Result: Order history accessible
    Evidence: .sisyphus/evidence/task-15.7-history.png

  Scenario: Voucher codes copyable
    Tool: Playwright
    Preconditions: paid order with vouchers
    Steps:
      1. Navigate to Voucher tab
      2. Assert: voucher codes visible
      3. Click "Copy" on a voucher
      4. Assert: clipboard contains the code (or toast "Copied!")
    Expected Result: Vouchers manageable
    Evidence: .sisyphus/evidence/task-15.7-vouchers.png
  ```

  **Commit**: YES | `task(15.7): teacher order page (Flutter) - 7 items, 4 modes, payment, vouchers`
  - Files: flutter/lib/features/teacher/pages/order_page.dart, flutter/lib/features/teacher/providers/order_provider.dart, flutter/lib/features/teacher/models/order.dart, flutter/test/features/teacher/order_page_test.dart
  - Pre-commit: `cd flutter && flutter test`

- [ ] 15.8. Partner dashboard + order page (Flutter)

  **What to do**:
  - Create `flutter/lib/features/partner/pages/partner_dashboard_page.dart` — institution/inorganization dashboard:
    - Teachers managed (count, list)
    - Students across all teachers (count)
    - Total orders placed (count + total amount)
    - Commission/override earnings (if partner earns from teachers they manage)
    - Active vouchers (count)
    - Quick actions: Order tests, Add teacher, View teachers, View orders
  - Create `flutter/lib/features/partner/pages/partner_order_page.dart` — same 7-item ordering UI as teacher (15.7) but with partner pricing. Partner can order for any teacher's students in their institution.
  - Create `flutter/lib/features/partner/pages/partner_teachers_page.dart` — manage teachers: invite teacher, view teacher's students, view teacher's orders
  - Create `flutter/lib/features/partner/providers/partner_provider.dart` — Riverpod notifier
  - Create `worker/src/routes/partner.ts` — partner-specific API endpoints:
    - `GET /api/partner/dashboard` — aggregated stats across institution
    - `GET /api/partner/teachers` — list teachers in institution
    - `POST /api/partner/teachers/invite` — invite teacher to institution
    - `GET /api/partner/orders` — all orders by institution
  - Update auth middleware to allow partner role access to /api/partner/*
  - Write vitest tests for partner routes
  - Write widget tests for partner pages

  **Must NOT do**:
  - Do not duplicate order logic from 15.6 — partner order page calls same /api/orders endpoint, just with partner pricing
  - Do not allow partner to access teacher-only AI tools (grader, generator) unless they're also a teacher
  - Do not allow partner to manage teachers outside their institution

  **Recommended Agent Profile**:
  - **Category**: `deep` — new role, dashboard, order UI, teacher management, API routes
  - **Skills**: [] — standard full-stack

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 15.7 — different role UIs, share order API)
  - **Parallel Group**: Wave 15
  - **Blocks**: none
  - **Blocked By**: 15.5 (pricing), 15.6 (order API), 1.5 (Flutter), 1.8 (router with /partner routes)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:2596` — Task 15.3 Institution tier (overlaps with partner role)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2486-2491` — Teacher dashboard pattern (adapt for partner)
  - `D:\claude telegram bot\worker\src\services\classroom.ts` — EduBot's classroom/institution patterns

  **WHY Each Reference Matters**:
  - Task 15.3 defines institution tier — partner role is the implementation of this. Merge concepts.
  - Teacher dashboard pattern (2.1) shows how to structure a dashboard — adapt for partner (institution-wide stats vs single teacher)
  - EduBot's classroom service shows institution/group management patterns

  **Acceptance Criteria**:
  - [ ] Partner dashboard renders with institution-wide stats
  - [ ] Partner sees all 7 orderable items at partner pricing
  - [ ] Partner can order for any teacher's students in their institution
  - [ ] Partner can invite teachers to institution
  - [ ] Partner can view all teachers + their students
  - [ ] Partner cannot access teacher-only AI tools (unless also teacher)
  - [ ] Partner cannot manage teachers outside their institution
  - [ ] Vitest + widget tests pass

  **QA Scenarios**:
  ```
  Scenario: Partner dashboard shows institution stats
    Tool: Playwright
    Preconditions: partner logged in, has 3 teachers each with students, has placed orders
    Steps:
      1. Navigate to /partner
      2. Assert: "Teachers: 3", "Students: N", "Total Orders: M"
      3. Assert: commission/override earnings displayed
      4. Assert: quick action buttons visible
      5. Screenshot
    Expected Result: Partner dashboard shows institution-wide data
    Evidence: .sisyphus/evidence/task-15.8-partner-dashboard.png

  Scenario: Partner orders at partner pricing
    Tool: Playwright
    Preconditions: partner logged in
    Steps:
      1. Navigate to /partner/orders
      2. Assert: 7 items visible
      3. Assert: prices are PARTNER rates (lower than teacher rates)
      4. Assert: IBT shows Rp 200,000 (or configured partner price)
    Expected Result: Partner sees partner pricing
    Evidence: .sisyphus/evidence/task-15.8-partner-pricing.png

  Scenario: Partner orders for teacher's student
    Tool: Playwright
    Preconditions: partner has teachers with students
    Steps:
      1. On order page, select "Bulk purchase for students"
      2. Assert: can select from ALL teachers' students (not just own)
      3. Select 5 students across different teachers
      4. Place order, pay
      5. Assert: 5 vouchers generated, assigned to students
    Expected Result: Partner can order for any student in institution
    Evidence: .sisyphus/evidence/task-15.8-partner-order-students.png

  Scenario: Partner invites teacher
    Tool: Playwright
    Preconditions: partner logged in
    Steps:
      1. Navigate to /partner/teachers
      2. Click "Invite Teacher"
      3. Enter teacher email
      4. Submit
      5. Assert: invitation sent (or teacher appears as pending)
    Expected Result: Partner can recruit teachers
    Evidence: .sisyphus/evidence/task-15.8-invite-teacher.png

  Scenario: Partner cannot access teacher AI tools
    Tool: Playwright
    Preconditions: partner logged in (partner-only, not also teacher)
    Steps:
      1. Try navigating to /teacher/ai-grader
      2. Assert: redirected to /partner (auth guard blocks)
    Expected Result: Partner role restricted from teacher tools
    Evidence: .sisyphus/evidence/task-15.8-blocked-ai-tools.png

  Scenario: Partner cannot manage other institution's teachers
    Tool: Bash
    Preconditions: two partners (A and B) with separate institutions
    Steps:
      1. As partner A, curl /api/partner/teachers
      2. Assert: only partner A's teachers listed
      3. As partner A, try to access partner B's teacher: curl /api/teacher/students/<partner_b_teacher_student>
      4. Assert: 403
    Expected Result: Institution isolation enforced
    Evidence: .sisyphus/evidence/task-15.8-institution-isolation.txt
  ```

  **Commit**: YES | `task(15.8): partner dashboard + order page + teacher management (Flutter + worker)`
  - Files: flutter/lib/features/partner/ (pages, providers, models), worker/src/routes/partner.ts, worker/src/routes/partner.test.ts, worker/src/middleware/auth.ts (update for partner role)
  - Pre-commit: `cd worker && npx vitest run && cd ../flutter && flutter test`

- [ ] 15.9. Voucher redemption system

  **What to do**:
  - Create `worker/src/routes/voucher.ts`:
    - `POST /api/vouchers/redeem` — accepts {code, student_id}, validates voucher (active, not expired, belongs to redeemable type), marks as redeemed, grants access on the relevant practice platform
    - `GET /api/vouchers/:code/validate` — check if code is valid (for UI preview before redeem)
  - Create `worker/src/services/voucher.ts`:
    - `redeemVoucher(code, studentId)` — validate, update vouchers.redeemed_by/at, trigger platform access
    - `validateVoucher(code)` — returns {valid, item_type, expires_at, status}
    - For mock tests (mock_itp/ibt/ielts/toeic): send webhook to practice platform granting session access, OR generate access token the platform can verify
    - For tutor_bot_premium: bridge to EduBot to activate premium subscription
    - For official tests: N/A (official tests use booking system, not voucher redemption)
  - Define webhook contract for voucher redemption: Hub sends `POST https://<platform>.osee.co.id/api/voucher/redeem` with {code, student_id, item_type, signature}
  - Write vitest tests: redeem valid voucher, redeem expired (fail), redeem already redeemed (fail), redeem wrong type

  **Must NOT do**:
  - Do not allow voucher redemption without authentication (student must be logged in)
  - Do not redeem official test vouchers via this system (those are booking-based)
  - Do not allow redemption of vouchers assigned to another student (for bulk_purchase assigned vouchers)

  **Recommended Agent Profile**:
  - **Category**: `deep` — voucher logic, cross-platform webhooks, access granting
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 15.10 — different integration concerns)
  - **Parallel Group**: Wave 15
  - **Blocks**: none (end of order pipeline)
  - **Blocked By**: 15.6 (vouchers created by order fulfillment), 3.1 (webhook pattern reference)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:299-333` — Section 3 Webhook flow (reverse direction: Hub → platform)
  - `C:\Users\user\osee-prep-hub-blueprint.md:102-108` — Existing Assets (platform URLs)
  - `D:\claude telegram bot\worker\src\routes\payment.ts` — EduBot's payment pattern (access granting after payment)
  - Voucher schema (Task 1.1): vouchers table definition

  **WHY Each Reference Matters**:
  - Webhook flow section shows how Hub communicates with practice platforms — voucher redemption sends the reverse webhook (Hub → platform)
  - Existing Assets lists platform URLs — vouchers need to call these platforms' APIs
  - EduBot's payment route shows how this team grants access after payment — same pattern for voucher redemption
  - Voucher table definition is the data model

  **Acceptance Criteria**:
  - [ ] POST /api/vouchers/redeem works for valid voucher
  - [ ] Voucher marked as redeemed (status, redeemed_by, redeemed_at)
  - [ ] Platform webhook sent (mock_ibt → ibt.osee.co.id, etc.)
  - [ ] Tutor Bot premium activation bridges to EduBot
  - [ ] Expired voucher → 400 with error
  - [ ] Already redeemed → 400 with error
  - [ ] Assigned voucher can only be redeemed by assigned student
  - [ ] Unauthenticated → 401
  - [ ] Vitest tests pass

  **QA Scenarios**:
  ```
  Scenario: Redeem valid IBT voucher
    Tool: Bash
    Preconditions: active voucher with code "IBT2024XYZ123" exists, student logged in
    Steps:
      1. curl -X POST /api/vouchers/redeem -d '{"code":"IBT2024XYZ123"}' -H "Authorization: Bearer <student_token>"
      2. Assert: HTTP 200
      3. Assert: response contains "access_granted" or platform redirect URL
      4. Query: SELECT status, redeemed_by, redeemed_at FROM vouchers WHERE code='IBT2024XYZ123'
      5. Assert: status='redeemed', redeemed_by set, redeemed_at set
    Expected Result: Voucher redeemed, access granted
    Evidence: .sisyphus/evidence/task-15.9-redeem-valid.txt

  Scenario: Redeem expired voucher fails
    Tool: Bash
    Preconditions: voucher with expires_at in past
    Steps:
      1. curl -X POST /api/vouchers/redeem -d '{"code":"EXPIRED123"}'
      2. Assert: HTTP 400
      3. Assert: error message "expired"
    Expected Result: Expired vouchers rejected
    Evidence: .sisyphus/evidence/task-15.9-expired.txt

  Scenario: Double redemption fails
    Tool: Bash
    Preconditions: voucher already redeemed
    Steps:
      1. curl -X POST /api/vouchers/redeem -d '{"code":"ALREADYREDEEMED"}'
      2. Assert: HTTP 400
      3. Assert: error "already redeemed"
    Expected Result: No double redemption
    Evidence: .sisyphus/evidence/task-15.9-double-redeem.txt

  Scenario: Assigned voucher only for assigned student
    Tool: Bash
    Preconditions: voucher assigned to student A via bulk_purchase
    Steps:
      1. As student B, curl -X POST /api/vouchers/redeem -d '{"code":"ASSIGNED123"}'
      2. Assert: HTTP 403
      3. As student A, curl -X POST /api/vouchers/redeem -d '{"code":"ASSIGNED123"}'
      4. Assert: HTTP 200
    Expected Result: Assigned vouchers restricted to assigned student
    Evidence: .sisyphus/evidence/task-15.9-assigned.txt

  Scenario: Validate voucher before redeem
    Tool: Bash
    Steps:
      1. curl /api/vouchers/IBT2024XYZ123/validate
      2. Assert: HTTP 200 with {valid: true, item_type: "mock_ibt", status: "active"}
    Expected Result: Validation endpoint works
    Evidence: .sisyphus/evidence/task-15.9-validate.txt
  ```

  **Commit**: YES | `task(15.9): voucher redemption system - validate, redeem, cross-platform access granting`
  - Files: worker/src/routes/voucher.ts, worker/src/services/voucher.ts, worker/src/routes/voucher.test.ts, worker/src/index.ts (route registration)
  - Pre-commit: `cd worker && npx vitest run src/routes/voucher.test.ts`

- [ ] 15.10. Official test booking bridge to osee.co.id

  **What to do**:
  - Create `worker/src/services/booking-bridge.ts` — bridge between Hub and osee.co.id booking system:
    - `createBooking(orderItem)` — for book_for_student orders with official_toefl/official_toeic items, calls osee.co.id booking API to create a test slot reservation
    - `getBookingStatus(bookingId)` — check booking status on osee.co.id
    - `cancelBooking(bookingId)` — cancel booking (if allowed)
  - Define osee.co.id API contract (may need to be created/added on osee.co.id side):
    - `POST https://osee.co.id/api/hub/booking` — create booking {test_type, student_name, student_email, date_preference, partner_ref}
    - `GET https://osee.co.id/api/hub/booking/:id` — get status
    - `DELETE https://osee.co.id/api/hub/booking/:id` — cancel
  - Auth: shared secret header `X-Hub-Secret` (set in env: OSEE_BOOKING_API_SECRET)
  - Update order fulfillment (15.6) to call booking bridge for official_toefl/official_toeic items
  - Add `GET /api/orders/:id/booking-status` — returns booking status for official test orders
  - Add webhook receiver `POST /api/webhook/booking` — osee.co.id sends booking status updates (confirmed, scheduled, completed, cancelled) — integrates with existing Task 3.1 webhook
  - Write vitest tests with mocked osee.co.id responses

  **Must NOT do**:
  - Do not assume osee.co.id has the API — if it doesn't exist, the plan should note that osee.co.id needs to add these endpoints. For now, mock the integration and test against mocks.
  - Do not store student PII in booking logs without consent
  - Do not allow booking without payment confirmation

  **Recommended Agent Profile**:
  - **Category**: `deep` — cross-system integration, booking lifecycle, webhook handling
  - **Skills**: [] — standard

  **Parallelization**:
  - **Can Run In Parallel**: YES (with 15.9 — different concerns)
  - **Parallel Group**: Wave 15
  - **Blocks**: 15.6 (order fulfillment for official tests — but 15.6 can mock this, so they can run in parallel with 15.6 using a stub)
  - **Blocked By**: 1.1 (schema), 3.1 (webhook pattern), 15.6 (order context)

  **References**:
  - `C:\Users\user\osee-prep-hub-blueprint.md:103` — OSEE main site (osee.co.id, ETS-certified test center)
  - `C:\Users\user\osee-prep-hub-blueprint.md:2754` — WEBHOOK_SECRET_BOOKING env var
  - `C:\Users\user\osee-prep-hub-blueprint.md:299-333` — Webhook flow (Hub ← booking platform)

  **WHY Each Reference Matters**:
  - OSEE main site is the booking platform — this task bridges to it
  - WEBHOOK_SECRET_BOOKING is the shared secret for booking webhook auth
  - Webhook flow shows how booking events flow into Hub (Task 3.1 already handles receipt; this task handles the outbound booking creation)

  **Acceptance Criteria**:
  - [ ] `booking-bridge.ts` createBooking() calls osee.co.id API (or mock if API doesn't exist yet)
  - [ ] Booking ID stored in order_items.external_booking_id
  - [ ] getBookingStatus() returns current status
  - [ ] cancelBooking() works
  - [ ] Webhook receiver updates booking status in Hub
  - [ ] GET /api/orders/:id/booking-status returns booking info
  - [ ] Booking only created after payment confirmed
  - [ ] Vitest tests pass (with mocked osee.co.id)

  **QA Scenarios**:
  ```
  Scenario: Create official TOEFL booking
    Tool: Bash
    Preconditions: paid order with official_toefl item, osee.co.id API available (or mocked)
    Steps:
      1. Fulfillment runs for paid order
      2. Assert: booking-bridge.createBooking called
      3. Assert: order_items.external_booking_id set
      4. curl /api/orders/<order_id>/booking-status
      5. Assert: booking details returned (date, venue, status)
    Expected Result: Official test booked on osee.co.id
    Evidence: .sisyphus/evidence/task-15.10-create-booking.txt

  Scenario: Booking webhook updates status
    Tool: Bash
    Preconditions: booking exists on osee.co.id
    Steps:
      1. Simulate osee.co.id sending webhook: curl -X POST /api/webhook/booking -d '{"event_type":"booking_confirmed","booking_id":"<id>","date":"2025-08-15","venue":"Jakarta"}' -H "X-Webhook-Secret: <secret>"
      2. Assert: HTTP 202
      3. curl /api/orders/<order_id>/booking-status
      4. Assert: status = "confirmed", date and venue present
    Expected Result: Booking status synced from osee.co.id
    Evidence: .sisyphus/evidence/task-15.10-booking-webhook.txt

  Scenario: Cancel booking
    Tool: Bash
    Preconditions: confirmed booking
    Steps:
      1. curl -X POST /api/orders/<order_id>/cancel
      2. Assert: booking-bridge.cancelBooking called
      3. Assert: order status = "cancelled"
      4. Assert: booking status = "cancelled" (via webhook or direct update)
    Expected Result: Cancellation propagates to osee.co.id
    Evidence: .sisyphus/evidence/task-15.10-cancel-booking.txt

  Scenario: Booking without payment fails
    Tool: Bash
    Preconditions: pending (unpaid) order with official test
    Steps:
      1. Try to trigger fulfillment manually
      2. Assert: 400 error "payment required" or fulfillment skipped
    Expected Result: No booking without payment
    Evidence: .sisyphus/evidence/task-15.10-no-payment.txt
  ```

  **Commit**: YES | `task(15.10): official test booking bridge to osee.co.id`
  - Files: worker/src/services/booking-bridge.ts, worker/src/routes/orders.ts (update), worker/src/services/booking-bridge.test.ts, worker/src/routes/webhook.ts (update for booking webhook)
  - Pre-commit: `cd worker && npx vitest run src/services/booking-bridge.test.ts`

> **PHASE 4 BOUNDARY**: Tasks 12.1-15.10 complete (includes order system: pricing, orders, vouchers, booking bridge, partner dashboard). Git tag `phase-4-complete`.

- [ ] 16.1. Link Telegram account to OSEE account

  **What to do**: Create `POST /api/auth/link-telegram` — accepts Telegram ID + OSEE token, links accounts. Read `D:\claude telegram bot\worker\src\routes\auth.ts` for EduBot's auth flow. Update unified_profiles with telegram_id field.

  **Must NOT do**: Do not modify EduBot — bridge via API only

  **Recommended Agent Profile**: `deep` | Wave 16 | Blocks: 16.2-16.5 | Blocked By: Phase 4

  **References**: blueprint:2604, `D:\claude telegram bot\worker\src\routes\auth.ts`, `D:\claude telegram bot\worker\src\services\auth.ts`

  **Acceptance Criteria**: [ ] Telegram ID linked to OSEE account, [ ] Duplicate link prevented, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Link Telegram
    Tool: Bash
    Steps: POST /api/auth/link-telegram -d '{"telegram_id":"123456"}', assert 200, verify telegram_id in profile
    Expected Result: Accounts linked
    Evidence: .sisyphus/evidence/task-16.1-link-telegram.txt
  ```

  **Commit**: YES | `task(16.1): link Telegram account to OSEE account`

- [ ] 16.2. EduBot reads student progress from Hub API

  **What to do**: Add `GET /api/external/student/:telegram_id/progress` (internal API for EduBot). EduBot calls this to get student's Hub progress. Requires EDUBOT_INTERNAL_SECRET auth.

  **Must NOT do**: Do not modify EduBot's code — just provide the API endpoint

  **Recommended Agent Profile**: `deep` | Wave 16 | Blocked By: 16.1, 3.3

  **References**: blueprint:2605

  **Acceptance Criteria**: [ ] Endpoint returns progress for linked Telegram user, [ ] Secret auth required, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: EduBot reads progress
    Tool: Bash
    Steps: GET /api/external/student/:telegram_id/progress with secret header, assert progress data
    Expected Result: Progress API for EduBot
    Evidence: .sisyphus/evidence/task-16.2-edubot-progress.txt
  ```

  **Commit**: YES | `task(16.2): EduBot reads student progress from Hub API`

- [ ] 16.3. EduBot deep-links students to practice platforms

  **What to do**: Add `GET /api/external/student/:telegram_id/syllabus` — returns syllabus with deep links. EduBot uses these to deep-link students.

  **Recommended Agent Profile**: `unspecified-high` | Wave 16 | Blocked By: 16.2, 10.x

  **References**: blueprint:2606

  **Acceptance Criteria**: [ ] Syllabus with deep links returned, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Get syllabus for EduBot
    Tool: Bash
    Steps: GET /api/external/student/:id/syllabus, assert items with platform URLs
    Expected Result: Syllabus API for EduBot
    Evidence: .sisyphus/evidence/task-16.3-edubot-syllabus.txt
  ```

  **Commit**: YES | `task(16.3): EduBot deep-links students to practice platforms`

- [ ] 16.4. EduBot knows teacher's syllabus → tutors on those topics

  **What to do**: Add `GET /api/external/teacher/:telegram_id/syllabus` — returns teacher's syllabus topics. EduBot uses to align tutoring.

  **Recommended Agent Profile**: `deep` | Wave 16 | Blocked By: 16.1, 10.x

  **References**: blueprint:2607

  **Acceptance Criteria**: [ ] Teacher syllabus topics returned, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Teacher syllabus for EduBot
    Tool: Bash
    Steps: GET /api/external/teacher/:id/syllabus, assert topics
    Expected Result: Teacher context for EduBot
    Evidence: .sisyphus/evidence/task-16.4-teacher-syllabus.txt
  ```

  **Commit**: YES | `task(16.4): EduBot knows teacher's syllabus for topic-aligned tutoring`

- [ ] 16.5. EduBot reports progress back to Hub

  **What to do**: Add `POST /api/external/progress-report` — EduBot posts student progress (study sessions, quiz results) to Hub. Stored in student_progress_unified with platform=edubot.

  **Must NOT do**: Do not modify EduBot — EduBot will call this endpoint

  **Recommended Agent Profile**: `deep` | Wave 16 | Blocked By: 16.1, 3.3

  **References**: blueprint:2608

  **Acceptance Criteria**: [ ] Progress report accepted, [ ] Stored in student_progress_unified, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: EduBot reports progress
    Tool: Bash
    Steps: POST /api/external/progress-report with session data, assert 201, verify in DB
    Expected Result: Bidirectional progress sync
    Evidence: .sisyphus/evidence/task-16.5-edubot-report.txt
  ```

  **Commit**: YES | `task(16.5): EduBot reports progress back to Hub`

- [ ] 17.1. Ambassador recruitment page (Flutter)

  **What to do**: Create `flutter/lib/features/teacher/pages/ambassador_page.dart` — info about ambassador program, benefits, apply button. Add `POST /api/ambassador/apply`.

  **Recommended Agent Profile**: `visual-engineering` | Wave 17 | Blocked By: Phase 4, 12.5

  **References**: blueprint:2611

  **Acceptance Criteria**: [ ] Page renders program info, [ ] Application submits, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Ambassador apply
    Tool: Playwright
    Steps: Navigate to ambassador page, click Apply, fill form, submit
    Expected Result: Application submitted
    Evidence: .sisyphus/evidence/task-17.1-ambassador-apply.png
  ```

  **Commit**: YES | `task(17.1): ambassador recruitment page (Flutter)`

- [ ] 17.2. Ambassador dashboard (recruited teachers, bonuses)

  **What to do**: Create `flutter/lib/features/teacher/pages/ambassador_dashboard_page.dart` — shows recruited teachers, total bonuses, impact metrics.

  **Recommended Agent Profile**: `visual-engineering` | Wave 17 | Blocked By: 17.1

  **References**: blueprint:2612

  **Acceptance Criteria**: [ ] Dashboard shows recruited teachers + bonuses, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Ambassador dashboard
    Tool: Playwright
    Steps: Navigate to ambassador dashboard, assert recruited list, bonuses
    Expected Result: Ambassador dashboard
    Evidence: .sisyphus/evidence/task-17.2-ambassador-dashboard.png
  ```

  **Commit**: YES | `task(17.2): ambassador dashboard (Flutter)`

- [ ] 17.3. Teacher proposal document (PDF template)

  **What to do**: Extend pdf.ts with teacher proposal template — for teachers to present OSEE to their school/institution. Includes: program overview, benefits, pricing, commission structure.

  **Recommended Agent Profile**: `deep` | Wave 17 | Blocked By: 8.2

  **References**: blueprint:2613

  **Acceptance Criteria**: [ ] PDF generated with proposal content, [ ] Downloadable

  **QA Scenarios**:
  ```
  Scenario: Download proposal
    Tool: Bash
    Steps: GET /api/teacher/proposal.pdf, assert PDF
    Expected Result: Proposal PDF
    Evidence: .sisyphus/evidence/task-17.3-proposal.pdf
  ```

  **Commit**: YES | `task(17.3): teacher proposal document (PDF template)`

- [ ] 17.4. Landing page (prep.osee.co.id)

  **What to do**: Create `flutter/lib/features/landing/pages/landing_page.dart` — public landing page: hero, features, how it works, pricing, CTA to register. SEO: use Flutter Web's SEO techniques (html title, meta, server-side rendering if possible).

  **Recommended Agent Profile**: `visual-engineering` | Wave 17 | Blocked By: Phase 4

  **References**: blueprint:2614

  **Acceptance Criteria**: [ ] Landing page renders, [ ] CTA navigates to register, [ ] Widget test passes

  **QA Scenarios**:
  ```
  Scenario: Landing page
    Tool: Playwright
    Steps: Navigate to /, assert hero, features, CTA
    Expected Result: Landing page complete
    Evidence: .sisyphus/evidence/task-17.4-landing.png
  ```

  **Commit**: YES | `task(17.4): landing page (Flutter)`

- [ ] 17.5. SEO optimization (osee.co.id blog integration)

  **What to do**: Add meta tags, structured data, sitemap.xml, robots.txt for Flutter Web. If Flutter Web SEO is limited, consider pre-rendering or separate static HTML landing page.

  **Recommended Agent Profile**: `unspecified-high` | Wave 17 | Blocked By: 17.4

  **References**: blueprint:2615

  **Acceptance Criteria**: [ ] Meta tags present, [ ] Sitemap accessible, [ ] Lighthouse SEO score > 80

  **QA Scenarios**:
  ```
  Scenario: SEO check
    Tool: Bash
    Steps: curl /, assert <title>, <meta name="description">, curl /sitemap.xml, assert XML
    Expected Result: SEO basics
    Evidence: .sisyphus/evidence/task-17.5-seo.txt
  ```

  **Commit**: YES | `task(17.5): SEO optimization for landing page`

- [ ] 18.1. Error handling + logging (worker-wide)

  **What to do**: Add consistent error handling middleware to Hono app. Structured JSON logging (use console.log with JSON in Workers). Error response format: {error: {code, message, requestId}}. Add Sentry or similar if desired.

  **Must NOT do**: Do not use console.log for debug in production — structured only

  **Recommended Agent Profile**: `deep` | Wave 18 | Blocked By: Phase 4

  **References**: blueprint:2618

  **Acceptance Criteria**: [ ] All routes return consistent error format, [ ] Logs structured, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Error format
    Tool: Bash
    Steps: Hit non-existent endpoint, assert 404 with {error: {code, message}}
    Expected Result: Consistent errors
    Evidence: .sisyphus/evidence/task-18.1-error-format.txt
  ```

  **Commit**: YES | `task(18.1): error handling + structured logging (worker-wide)`

- [ ] 18.2. Performance optimization (caching, CDN)

  **What to do**: Add Cloudflare Cache API for GET endpoints (progress, reports, dashboard). Cache RAG search results for 5 min. Add ETag support.

  **Recommended Agent Profile**: `deep` | Wave 18 | Blocked By: Phase 4

  **References**: blueprint:2619

  **Acceptance Criteria**: [ ] Cache headers set, [ ] Repeated requests faster, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Cache hit
    Tool: Bash
    Steps: GET dashboard twice, assert second response faster (or from cache)
    Expected Result: Caching works
    Evidence: .sisyphus/evidence/task-18.2-cache.txt
  ```

  **Commit**: YES | `task(18.2): performance optimization - caching, CDN`

- [ ] 18.3. Mobile responsiveness (Flutter Web)

  **What to do**: Ensure all Flutter pages are responsive: test on mobile viewport widths, adjust layouts (single column on mobile, multi-column on desktop), touch-friendly buttons.

  **Recommended Agent Profile**: `visual-engineering` | Wave 18 | Blocked By: Phase 4

  **References**: blueprint:2620

  **Acceptance Criteria**: [ ] All pages work on 375px width, [ ] No horizontal scroll, [ ] Touch targets ≥ 44px

  **QA Scenarios**:
  ```
  Scenario: Mobile viewport
    Tool: Playwright
    Steps: Set viewport 375x667, navigate all pages, screenshot each
    Expected Result: Responsive on mobile
    Evidence: .sisyphus/evidence/task-18.3-mobile.png
  ```

  **Commit**: YES | `task(18.3): mobile responsiveness (Flutter Web)`

- [ ] 18.4. Analytics dashboard (admin React)

  **What to do**: Create `frontend-admin/src/pages/Analytics.tsx` — platform-wide analytics: total users, active teachers, students, revenue, commission paid, AI usage.

  **Recommended Agent Profile**: `visual-engineering` | Wave 18 | Blocked By: Phase 4

  **References**: blueprint:2621

  **Acceptance Criteria**: [ ] Analytics dashboard renders, [ ] Real data, [ ] Tests pass

  **QA Scenarios**:
  ```
  Scenario: Analytics
    Tool: Playwright
    Steps: Navigate to admin analytics, assert metrics visible
    Expected Result: Analytics dashboard
    Evidence: .sisyphus/evidence/task-18.4-analytics.png
  ```

  **Commit**: YES | `task(18.4): analytics dashboard (admin React)`

- [ ] 18.5. Deploy to production (Cloudflare Pages + Workers + custom domain)

  **What to do**:
  - Deploy worker: `cd worker && wrangler deploy`
  - Set all secrets via `wrangler secret put`
  - Build Flutter: `cd flutter && flutter build web --release`
  - Deploy frontend: `wrangler pages deploy flutter/build/web --project-name=osee-prep-hub`
  - Build admin: `cd frontend-admin && npm run build`
  - Deploy admin: `wrangler pages deploy frontend-admin/dist --project-name=osee-prep-hub-admin`
  - Configure custom domain: prep.osee.co.id → Cloudflare Pages, /api/* → Workers
  - Set DNS: CNAME prep → osee-prep-hub.pages.dev
  - Verify SSL

  **Recommended Agent Profile**: `deep` | Wave 18 | Blocks: F1-F4 | Blocked By: All tasks

  **References**: blueprint:2622, blueprint:2794-2849 (Section 15 Deployment)

  **Acceptance Criteria**:
  - [ ] wrangler deploy succeeds
  - [ ] prep.osee.co.id accessible
  - [ ] API at prep.osee.co.id/api/* works
  - [ ] SSL valid
  - [ ] All secrets set

  **QA Scenarios**:
  ```
  Scenario: Production live
    Tool: Bash
    Steps:
      1. curl https://prep.osee.co.id/api/health → 200 {"status":"ok"}
      2. curl https://prep.osee.co.id → HTML (landing page)
      3. curl -I https://prep.osee.co.id → assert 200, valid SSL
    Expected Result: Production deployed
    Evidence: .sisyphus/evidence/task-18.5-production.txt

  Scenario: All secrets set
    Tool: Bash
    Steps: wrangler secret list, assert all expected secrets present
    Expected Result: No missing secrets
    Evidence: .sisyphus/evidence/task-18.5-secrets.txt
  ```

  **Commit**: YES | `task(18.5): deploy to production - Cloudflare Pages + Workers + custom domain`
  - Pre-commit: full test suite passes
  - Post-commit: git tag `phase-5-complete`

> **PHASE 5 BOUNDARY**: Tasks 16.1-18.5 complete. Git tag `phase-5-complete`. Proceed to Final Verification Wave.

---

## Final Verification Wave (MANDATORY — after ALL implementation tasks)

> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in .sisyphus/evidence/. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `npx tsc --noEmit` (worker) + `flutter analyze` (Flutter) + `npx vitest run` (worker tests) + `flutter test` (widget tests). Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill)
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration. Test edge cases: empty state, invalid input, rapid actions. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built, nothing beyond spec was built. Check "Must NOT do" compliance. Detect cross-task contamination. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Every task**: Individual commit (blueprint mandate: "Commit after every task")
- **Format**: `task(N.M): brief description` (e.g. `task(1.3): implement auth routes - register, login, verify, refresh, logout`)
- **Pre-commit**: Run `npx vitest run` (worker) and `flutter test` (Flutter) for affected code
- **Phase boundaries**: Tag commit at end of each phase (e.g. `git tag phase-1-complete`)

---

## Success Criteria

### Verification Commands
```bash
# Worker
cd worker && npx tsc --noEmit          # Expected: no errors
cd worker && npx vitest run             # Expected: all tests pass
cd worker && wrangler dev               # Expected: local API running on localhost:8787

# Flutter
cd flutter && flutter analyze           # Expected: no issues
cd flutter && flutter test              # Expected: all widget tests pass
cd flutter && flutter build web         # Expected: build/web/ directory created

# Admin
cd frontend-admin && npm run build      # Expected: dist/ directory created

# Database
# Supabase: verify all tables from schema.sql exist
# psql query: SELECT tablename FROM pg_tables WHERE schemaname='public';

# Integration
curl http://localhost:8787/api/health   # Expected: {"status":"ok"}
curl -X POST http://localhost:8787/api/auth/register -d '...'  # Expected: 201 + JWT
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All vitest tests pass (worker)
- [ ] All flutter_test tests pass (portals)
- [ ] `wrangler deploy` succeeds
- [ ] `flutter build web` succeeds
- [ ] prep.osee.co.id accessible
- [ ] All 80+ tasks committed individually
- [ ] Phase tags created (phase-1-complete through phase-5-complete)
- [ ] Evidence files exist for all QA scenarios