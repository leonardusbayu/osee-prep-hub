# OSEE Prep Hub — The Wildest Dream

> **Quick Summary**: Turn OSEE Prep Hub from "AI teaching assistant for English teachers in Indonesia" into **Southeast Asia's English-fluency operating system** — a product that owns the entire journey from a teacher's first lesson plan to a student's first job interview in English, with OSEE monetizing every step.
>
> **Deliverables** (concrete, this plan):
> - 6 new product surfaces (OSEE Studio, OSEE Coach, OSEE Passport, OSEE Classroom Live, OSEE Insight, OSEE Marketplace)
> - 4 AI agents (Curator, Tutor, Examiner, Mentor) running on a shared agent runtime
> - 1 multi-sided marketplace with IDR micro-transactions
> - 1 viral growth loop that doesn't rely on paid ads
> - Magazine-editorial design language extended into a flagship consumer brand
>
> **Estimated Effort**: XL — 18-week build to v1.0 "Asia launch"
> **Parallel Execution**: YES — 6 waves, 7–9 tasks per wave
> **Critical Path**: Identity graph → Agent runtime → Coach MVP → Passport ledger → Marketplace escrow → Launch

---

## Context

### Where we are today (ground truth, magazine-ui branch)

**Built (working on prod)**:
- Auth (JWT cookie + cross-domain SSO via `.osee.co.id`)
- Teacher portal: dashboard, syllabus builder (voo_kanban + magazine design), material bank (27-package library), mind-map recipe page (112 KB Notion-style block editor), AI grader, AI material generator
- Student portal: dashboard with bottom nav, scrapbook lesson reader, practice page (2,916 real exam questions ingested), syllabus viewer (magazine column style), profile
- Worker: 19 route files, 38 services, full Supabase schema (29+ tables including RLS, pgvector for RAG, material bank, lesson boards, syllabus assignment, knowledge clusters)
- Cloudflare Pages + Workers deployed; Pages project `osee-prep-hub`, worker `osee-prep-hub-worker`
- Database: 2,916 exam questions (TOEIC + IELTS + TOEFL ITP + CAE) + 2,220 material questions across 28 packages — real content, not placeholders
- Commission system scaffolded, ambassador program scaffolded, video system scaffolded, live class scaffolded
- Knowledge cluster ingestion pipeline (URL/YouTube/PDF → RAG → vector embeddings)
- Magazine-editorial design language (Georgia/Helvetica, ink/paper/accent/gold palette, asymmetric layouts, drop caps, rotated index numbers, "PUBLISH" stamps)

**What's missing** (gaps this plan fills):
- No real-time collaboration (single-teacher edit only)
- No student-facing AI tutor (only teacher-side AI grader/generator)
- No verifiable credential / passport — students can't "prove" their score to employers
- No native mobile app (Flutter web only — no app store presence)
- No marketplace (teachers can't sell their own lesson plans to other teachers)
- No usage analytics for institutions (only basic dashboards)
- No live class experience (only Zoom link sharing)
- No growth loop product (referral exists but no viral surface)
- No offline mode (Indonesia's #1 mobile-market constraint)
- No Bahasa Indonesia localization (UI is English-only)

### The reframe: from "AI Teaching Assistant" to "English Fluency OS"

The current product is a tool — it helps teachers do their job faster. Tools get replaced. **Operating systems** get defended. The reframe:

> OSEE is the **Android of English fluency in Southeast Asia**.
>
- **Teachers** are the developers (they build experiences on top of OSEE)
- **Students** are the users (they live inside OSEE from day 1 of learning to day 1 of working)
- **Institutions** are the OEMs (they white-label OSEE for their school)
- **Employers** are the app store (they hire based on OSEE Passport scores)
- **OSEE** owns the platform, the agent runtime, the credential ledger, and the marketplace

This is the only defensible position. If we stay "a tool," a better-funded competitor (OpenAI, Duolingo, a local player) eats us. If we become the OS, we become **the protocol** that everyone in SEA's English-education ecosystem has to integrate with.

### Metis review (gaps this plan must address)

- **Q: "What stops OpenAI from launching a GPT-tutor in Bahasa and eating your student base?"** → A: We don't compete on AI quality. We compete on **workflow ownership** — the teacher-student relationship, the syllabus, the credential. OpenAI doesn't have teachers. We do.
- **Q: "Why would employers trust OSEE Passport over IELTS?"** → A: IELTS is a snapshot. Passport is a longitudinal verified work-history (every essay, every spoken response, every class attended — verifiable via on-chain attestation). Employers in SEA already complain IELTS doesn't predict job performance. We do.
- **Q: "Indonesia's ARPU is low — how does the math work?"** → A: Teacher commission loop is the engine. Students don't pay OSEE directly; they pay for official tests, premium EduBot, and marketplace lesson plans — OSEE takes 15-30% of each. **The student never sees an OSEE bill.**
- **Q: "Why Flutter and not native?"** → A: Flutter web is already shipped. Flutter mobile (iOS + Android) is one `flutter build` away. One codebase, three surfaces (web + iOS + Android), one team. The magazine design language translates to mobile with bottom-nav + scrapbook patterns we already built.
- **Q: "What about India, Vietnam, Philippines — same product?"** → A: Same product, different exam portfolios. v1 is Indonesia-only. v1.1 adds Philippines (TOEIC + IELTS focus). v1.2 adds Vietnam. The agent runtime + credential ledger + marketplace are country-agnostic.

---

## Work Objectives

### Core Objective

Ship OSEE Prep Hub **v1.0 "Asia Launch"** in 18 weeks: a real-time, multi-sided, AI-agent-powered English-fluency OS with 6 product surfaces, 4 AI agents, a credential passport, a teacher marketplace, native mobile apps, and a viral growth loop — all wrapped in the magazine-editorial design language we've already established.

### Concrete Deliverables

1. **OSEE Studio** — the teacher's authoring environment, evolved from the current syllabus builder into a real-time collaborative canvas with AI co-author
2. **OSEE Coach** — the student's AI tutor, available 24/7 in Bahasa + English, with voice + writing + reading modules
3. **OSEE Passport** — a verifiable, longitudinal English-fluency credential that employers can check
4. **OSEE Classroom Live** — a live class experience that's more than Zoom (whiteboard, polls, breakout rooms, recording with AI summary)
5. **OSEE Insight** — an analytics OS for institutions (cohort heatmaps, teacher effectiveness, ROI per student)
6. **OSEE Marketplace** — a two-sided marketplace where teachers sell lesson plans, mock tests, and live classes to other teachers + students
7. **OSEE Native** — Flutter mobile apps (iOS + Android) with offline mode, push notifications, and deep-linking to all practice platforms
8. **OSEE Agents** — a shared agent runtime (Curator, Tutor, Examiner, Mentor) that all product surfaces call into

### Definition of Done

- [ ] 10,000 paying teachers across Indonesia by month 18
- [ ] 100,000 active students (free + paid) by month 18
- [ ] 50 institutions on white-label OSEE Insight
- [ ] 1,000 lesson plans listed on OSEE Marketplace
- [ ] 5,000 OSEE Passports verified by 10 partner employers
- [ ] Native mobile apps in App Store + Play Store with 4.5+ rating
- [ ] USD 1M ARR by month 18 (commission + marketplace + subscriptions + institution licenses)
- [ ] Real-time collaboration live in OSEE Studio (multiple teachers on one syllabus)
- [ ] Agent runtime serving 100k requests/day with <2s p95 latency

### Must Have

- Real-time collaboration (Yjs + Supabase Realtime) in OSEE Studio
- OSEE Passport with cryptographically verifiable attestation (on-chain or Merkle-ledger)
- Native mobile apps (iOS + Android) with offline-first sync
- Agent runtime with 4 named agents, each with a system prompt + tool set + evals
- Marketplace with escrow + dispute resolution
- Bahasa Indonesia localization (full UI + agent responses)
- P95 agent response latency < 2 seconds
- Magazine-editorial design language maintained across all new surfaces
- Zero-downtime deploys (Cloudflare Pages + Workers gradual rollouts)

### Must NOT Have (Guardrails)

- **No building our own LLM** — we wrap OpenAI / Anthropic / Google. We compete on workflow, not weights.
- **No paid customer acquisition before month 12** — growth must be organic (teacher referrals + student virality) until product-market fit is proven at scale.
- **No charging students directly for OSEE** — students pay for tests, premium EduBot, and marketplace content; OSEE takes a cut. The moment we charge students for "OSEE Premium," we lose the viral loop.
- **No whitelabeling the marketplace** — institutions get OSEE Insight (analytics) and OSEE Classroom Live, but the marketplace stays centralized so supply (teachers) can sell to demand (all teachers everywhere).
- **No feature shipping without an eval** — every AI agent feature must have an automated eval (set of test inputs + scoring rubric) before it ships. No "vibes-based" AI features.
- **No breaking the magazine design language** — every new surface must pass a design review against the editorial principles (asymmetry, mixed typography, gold rules, drop caps, pull-quotes). No generic Material Design defaults.
- **No solo-founder bottleneck** — every system must be documented well enough that a new engineer can ship a feature in week 1.
- **No scope creep into non-English subjects** — we are the English OS. Math, science, etc. are out of scope until year 3.

---

## Verification Strategy (MANDATORY)

> **ZERO HUMAN INTERVENTION** — ALL verification is agent-executed. No exceptions.

### Test Decision
- **Infrastructure exists**: YES (vitest for worker, flutter test for app)
- **Automated tests**: YES (Tests-after — every task ships with tests for the new code paths; existing tests must still pass)
- **Framework**: vitest (worker) + flutter test (app) + playwright (web E2E)
- **Agent-Executed QA**: ALWAYS — every task includes a QA scenario that the executing agent runs against the live URL or the local dev server

### QA Policy
Every task MUST include agent-executed QA scenarios.
- **Frontend/UI**: Playwright — navigate, interact, assert DOM, screenshot, compare against design baseline
- **CLI/TUI**: Bash — run command, parse output, assert fields
- **API/Backend**: curl — send request, assert status + response fields + latency
- **Library/Module**: Bash (dart/node REPL) — import, call functions, compare output
- **AI Agent**: Eval harness — run agent against 20 test inputs, score against rubric, assert pass rate ≥ 85%
- **Mobile**: Detox (iOS sim) + Maestro (Android emu) — drive native UI, assert flows

Evidence saved to `.sisyphus/evidence/task-{N}-{scenario-slug}.{ext}`.

---

## Execution Strategy

### Parallel Execution Waves

> 7-9 tasks per wave. Fewer than 5 = under-splitting.

```
Wave 1 (Foundation — unblocks everything):
├── T1: Agent runtime core (types, registry, tool bus, eval harness) [deep]
├── T2: Identity graph + real-time presence (Yjs + Supabase Realtime) [deep]
├── T3: OSEE Passport ledger schema + crypto attestation [deep]
├── T4: i18n infrastructure (Bahasa + English, l10n ARB files) [quick]
├── T5: Native mobile shell + offline sync strategy [deep]
├── T6: Design system tokens (magazine language formalized) [visual-engineering]
├── T7: Observability (Sentry + Logflare + RUM + agent trace logging) [quick]
└── T8: CI/CD pipeline (GitHub Actions: test → build → deploy staging → prod) [quick]

Wave 2 (Product surfaces, MAX PARALLEL — depends on Wave 1):
├── T9: OSEE Studio real-time collab canvas (depends: T2, T6) [deep]
├── T10: OSEE Coach student AI tutor (depends: T1, T6) [deep]
├── T11: OSEE Passport UI + verification flow (depends: T3, T6) [unspecified-high]
├── T12: OSEE Classroom Live — whiteboard + polls + breakouts (depends: T2, T6) [deep]
├── T13: OSEE Insight analytics dashboards (depends: T6) [visual-engineering]
├── T14: OSEE Marketplace escrow + listings (depends: T3) [deep]
├── T15: Curator agent — syllabus co-author (depends: T1) [deep]
├── T16: Tutor agent — 24/7 student tutor (depends: T1) [deep]
└── T17: Examiner agent — auto-grading with rubric (depends: T1) [deep]

Wave 3 (Cross-surface integration):
├── T18: Mentor agent — longitudinal career coach (depends: T15-T17) [deep]
├── T19: Studio ↔ Coach handoff (syllabus → daily student plan) (depends: T9, T10) [deep]
├── T20: Passport ↔ Insight export (institution dashboard → verifiable cert) (depends: T11, T13) [unspecified-high]
├── T21: Marketplace ↔ Studio integration (buy lesson plan → opens in Studio) (depends: T9, T14) [unspecified-high]
├── T22: Classroom Live ↔ Coach co-teaching (AI tutor joins live class) (depends: T10, T12) [deep]
├── T23: Mobile push notifications + deep links (depends: T5) [unspecified-high]
├── T24: Offline mode for Coach + Studio (depends: T5) [deep]
└── T25: Viral growth loop surface (Passport share + referral engine) (depends: T11) [visual-engineering]

Wave 4 (Production hardening):
├── T26: Agent runtime prod hardening (rate limits, cost guards, failover) [deep]
├── T27: Passport ledger audit + employer verification API [deep]
├── T28: Marketplace dispute resolution + reputation system [deep]
├── T29: Real-time sync conflict resolution (CRDT merge tests) [deep]
├── T30: Mobile offline sync reconciliation [deep]
├── T31: Localization QA (Bahasa review + cultural sensitivity) [writing]
├── T32: Performance — agent p95 < 2s, app TTI < 3s, real-time < 200ms [deep]
└── T33: Security review (OWASP, RLS audit, agent prompt injection) [deep]

Wave 5 (Launch readiness):
├── T34: App Store + Play Store submission (assets, screenshots, ASO) [visual-engineering]
├── T35: Employer partner onboarding (10 partner employers for Passport) [writing]
├── T36: Institution pilot (5 schools on OSEE Insight) [writing]
├── T37: Ambassador program v2 (top teachers get equity options) [writing]
├── T38: Launch narrative + press kit (magazine-style brand story) [writing]
├── T39: Onboarding flow polish (teacher → first syllabus in <5 min) [visual-engineering]
└── T40: Viral loop instrumented (every share → tracked → optimized) [unspecified-high]

Wave FINAL (After ALL tasks — 4 parallel reviews, then user okay):
├── F1: Plan compliance audit (oracle)
├── F2: Code quality review (unspecified-high)
├── F3: Real manual QA across all 6 surfaces (unspecified-high + playwright)
└── F4: Scope fidelity check (deep)
-> Present results -> Get explicit user okay

Critical Path: T1 → T15 → T18 → T22 → T26 → T32 → F1-F4 → user okay
Parallel Speedup: ~70% faster than sequential
Max Concurrent: 9 (Wave 2)
```

### Dependency Matrix (abbreviated — full matrix in TODOs section)

| Task | Depends On | Blocks |
|---|---|---|
| T1-T8 | none | everything in Wave 2 |
| T9 | T2, T6 | T19, T21 |
| T10 | T1, T6 | T19, T22 |
| T11 | T3, T6 | T20, T25 |
| T12 | T2, T6 | T22 |
| T14 | T3 | T21 |
| T15-T17 | T1 | T18, T19, T22 |
| T18 | T15, T16, T17 | (final) |
| T25 | T11 | (final) |

### Agent Dispatch Summary

- **Wave 1**: 8 tasks — T1, T2, T3, T5 → `deep`; T4, T7, T8 → `quick`; T6 → `visual-engineering`
- **Wave 2**: 9 tasks — T9, T10, T12, T14, T15, T16, T17 → `deep`; T11, T13 → `unspecified-high` + `visual-engineering`
- **Wave 3**: 8 tasks — T18, T19, T22, T24 → `deep`; T20, T21, T23 → `unspecified-high`; T25 → `visual-engineering`; T31 → `writing`
- **Wave 4**: 8 tasks — T26, T27, T28, T29, T30, T32, T33 → `deep`; T31 → `writing`
- **Wave 5**: 7 tasks — T34, T39 → `visual-engineering`; T35, T36, T37, T38 → `writing`; T40 → `unspecified-high`
- **FINAL**: 4 tasks — F1 → `oracle`; F2, F3 → `unspecified-high`; F4 → `deep`

---

## TODOs

### Wave 1 — Foundation

- [ ] 1. **Agent runtime core** — `worker/src/agents/runtime.ts` with `AgentDefinition`, `AgentContext`, `AgentRunner`, `ToolBus`. Built-in tools: `rag_search`, `fetch_user_profile`, `fetch_syllabus`, `fetch_student_progress`. `POST /api/agents/:agentName/invoke` endpoint (rate-limited 20/min free, 200/min pro). `scripts/run-agent-evals.ts` harness. 4 stub agents: curator, tutor, examiner, mentor. [deep]

- [ ] 2. **Identity graph + real-time presence** — Yjs + Supabase Realtime. `worker/src/services/realtime.ts` (presence + broadcast + postgres_changes). `flutter/lib/core/realtime_client.dart` (Yjs provider for syllabus items sync). `syllabus_collaborators` table. Realtime enabled on `syllabus_items`. Two-browser sync <200ms. [deep]

- [ ] 3. **OSEE Passport ledger** — `passport_credentials` + `passport_evidence` + `passport_verifications` tables. Ed25519 signing (`@noble/ed25519`). `worker/src/services/passport.ts` (issue, verify, revoke). `POST /api/passport/issue`, `GET /api/passport/:id` (public), `POST /api/passport/:id/verify` (employer). Public key at `/.well-known/passport-public-key.pem`. [deep]

- [ ] 4. **i18n infrastructure** — `app_en.arb` + `app_id.arb` (Bahasa). `flutter gen-l10n`. Extract hardcoded strings from auth/dashboard/syllabus/student pages. Locale toggle in profile. Agent-side i18n (`worker/src/services/i18n.ts`). [quick]

- [ ] 5. **Native mobile shell + offline sync** — `flutter create --platforms=ios,android`. Isar local DB. `flutter/lib/core/offline_sync.dart` (pull + queue + flush + conflict resolution). `connectivity_plus` monitor. `OfflineBanner` widget. Deep links (`/r/:code`, `/s/:syllabusId`). [deep]

- [ ] 6. **Design system tokens** — `flutter/lib/design/` with `tokens.dart` (spacing, radius, duration, elevation), `typography.dart` (formal type scale), `components.dart` (MagazineMasthead, MagazineDropCap, MagazineStat, MagazineCard, MagazineSectionRule, MagazinePublishStamp, MagazineSidebar, MagazinePullQuote, MagazineNumberBadge). Refactor existing pages to use components. `/dev/design` showcase page. `docs/design_review.md`. [visual-engineering]

- [ ] 7. **Observability** — Sentry (worker + Flutter). `worker/src/services/logger.ts` (structured JSON logging to Logflare). `agent_traces` table. RUM via Sentry Flutter. No PII in logs. [quick]

- [ ] 8. **CI/CD pipeline** — `.github/workflows/ci.yml` (test + build on push to magazine-ui). `.github/workflows/deploy-prod.yml` (deploy on main merge). Staging worker env. `CLOUDFLARE_API_TOKEN` secret. Status badges in README. Failing test blocks deploy. [quick]

### Wave 2 — Product Surfaces (MAX PARALLEL)

- [ ] 9. **OSEE Studio** (depends: T2, T6) — Evolve syllabus builder into real-time collaborative canvas. Yjs sync, presence bar, multi-cursor, invite collaborator by email, share read-only link. Curator "Suggest" button (ghost cards). Magazine design: gold-rule presence bar, stamp-styled invite. [deep]

- [ ] 10. **OSEE Coach** (depends: T1, T6) — `coach_page.dart` chat UI with magazine styling. Tutor agent integration. Tools: rag_search, fetch_student_progress, fetch_syllabus, create_practice_question. `coach_sessions` table. Floating "Ask Coach" button on all student pages. Text-only (voice in T22). [deep]

- [ ] 11. **OSEE Passport UI + verification flow** (depends: T3, T6) — Student Passport page with magazine-styled "certificates" (Georgia title, gold seal, signature fingerprint). Employer verification portal `/verify/:credentialId` (public, no auth). QR code for physical sharing. [unspecified-high]

- [ ] 12. **OSEE Classroom Live** (depends: T2, T6) — Live video sessions: WebRTC via LiveKit (Flutter + Worker JWT room join), Yjs-synced whiteboard, real-time polls, breakout rooms. AI summary post-class (Examiner agent). Recording to R2. [deep]

- [ ] 13. **OSEE Insight** (depends: T6) — Institution analytics dashboards: cohort heatmaps, teacher effectiveness, ROI per student, PDF reports. Magazine-styled data viz (fl_chart in Flutter, recharts in admin). [visual-engineering]

- [ ] 14. **OSEE Marketplace** (depends: T3) — Two-sided marketplace: teachers list lesson plans/mock tests/live classes (IDR pricing). Escrow via TriPay. 15% OSEE commission. Reputation: star ratings + reviews. Magazine-styled listing cards. [deep]

- [ ] 15. **Curator agent** (depends: T1) — System prompt: syllabus co-author, suggests 3-5 items per turn, considers student level + target score. Tools: rag_search, fetch_syllabus, fetch_student_progress, search_catalog. Eval: 20 test cases. [deep]

- [ ] 16. **Tutor agent** (depends: T1) — System prompt: patient Socratic tutor, Bahasa when stuck, syllabus-aware, celebrates wins. Tools: rag_search, fetch_student_progress, fetch_syllabus, create_practice_question. Eval: 20 cases (Socratic + Bahasa + syllabus awareness). [deep]

- [ ] 17. **Examiner agent** (depends: T1) — System prompt: rigorous essay grader, IELTS/TOEFL rubrics, band score + 3 strengths + 3 weaknesses + 1 rewrite. Tools: rag_search, fetch_grading_history. Eval: 20 essays, ±0.5 band accuracy vs human grades. [deep]

### Wave 3 — Cross-Surface Integration

- [ ] 18. **Mentor agent** (depends: T15, T16, T17) — Career coach, thinks in years not weeks. Tools: all + fetch_passport, fetch_job_market. Eval: 10 longitudinal cases. [deep]

- [ ] 19. **Studio ↔ Coach handoff** (depends: T9, T10) — Teacher publishes syllabus → Coach auto-generates "day 1" plan for each student (which item, why, 2-min intro). [deep]

- [ ] 20. **Passport ↔ Insight export** (depends: T11, T13) — Export Passport credential as magazine-styled PDF certificate. Batch export for cohorts. [unspecified-high]

- [ ] 21. **Marketplace ↔ Studio** (depends: T9, T14) — Buy lesson plan → opens in Studio as new syllabus. One-click "Remix". [unspecified-high]

- [ ] 22. **Classroom Live ↔ Coach** (depends: T10, T12) — Coach joins live class as co-teacher: transcribes, suggests questions, monitors engagement, generates post-class summary. Voice mode for Coach enabled here. [deep]

- [ ] 23. **Mobile push + deep links** (depends: T5) — FCM (Android) + APNs (iOS). Notifications: new Coach msg, class starting, syllabus updated, Passport issued, Marketplace purchase. Deep links to relevant pages. [unspecified-high]

- [ ] 24. **Offline mode for Coach + Studio** (depends: T5) — Coach: cache last 50 msgs, read-only when offline. Studio: full offline edit via T5 sync engine, Yjs syncs when online. [deep]

- [ ] 25. **Viral growth loop** (depends: T11) — Passport share card (magazine-styled image with Georgia title, gold seal, QR code). One-tap share to WhatsApp/Instagram/LinkedIn. Referral: each share has unique code → signer gets 1 week Coach Premium. [visual-engineering]

### Wave 4 — Production Hardening

- [ ] 26. **Agent runtime prod hardening** — Per-user + per-agent rate limits, cost guards ($0.05/call max), failover (OpenAI → Anthropic), circuit breaker (5 failures in 10 min → auto-disable + alert). [deep]

- [ ] 27. **Passport audit + employer API** — Public `GET /api/passport/verify/:id` with `X-Employer-Key`. Employer self-serve registration portal. 1000 verifications/day free, paid tiers. Audit log. [deep]

- [ ] 28. **Marketplace disputes + reputation** — 7-day dispute window, OSEE mediation, refund or uphold. Reputation: weighted score (ratings + refund rate + response time). Badges: Top Rated (top 5%), Rising Star. [deep]

- [ ] 29. **Real-time sync conflict resolution** — Yjs CRDT merge tests: 10 scenarios (concurrent edits, offline, network partitions). 3-client simultaneous edit test. No data loss guarantee. [deep]

- [ ] 30. **Mobile offline sync reconciliation** — 7-day offline + 50 queued ops sync, conflict resolution (last-write-wins + notify), app killed mid-sync resume. [deep]

- [ ] 31. **Localization QA** — Native Bahasa speaker reviews `app_id.arb`. Formal "Anda" not "Kamu". Indonesian names + local contexts. No untranslated English idioms. [writing]

- [ ] 32. **Performance** — Agent p95 <2s (cache RAG 5-min TTL, cache syllabus 1-min TTL, SSE streaming). App TTI <3s (code-split, lazy-load, pre-cache). Real-time <200ms. Load test 100 concurrent agent requests. [deep]

- [ ] 33. **Security review** — OWASP Top 10. RLS audit (every table has RLS, no service-key leaks). Agent prompt injection test. Passport crypto pen test (try forging signature). [deep]

### Wave 5 — Launch Readiness

- [ ] 34. **App Store + Play Store submission** — Screenshots (magazine-styled), privacy labels, ASO keywords ("belajar bahasa Inggris", "TOEFL practice", "IELTS preparation"). [visual-engineering]

- [ ] 35. **Employer partner onboarding** — 10 Indonesian employers (Tokopedia, Gojek, Shopee, Traveloka, Bukalapak + 5 SMEs). Pitch: "verify English in 5 seconds, free API." Each gets portal + API key. [writing]

- [ ] 36. **Institution pilot** — 5 schools/universities on Insight. Training, weekly check-ins, feedback → fixes. [writing]

- [ ] 37. **Ambassador program v2** — Top 20 teachers: 2× commission, badge, Discord, equity options (0.01-0.05%, 2-year vest). Legal docs. [writing]

- [ ] 38. **Launch narrative + press kit** — "The magazine that teaches English." Press kit: bios, screenshots, 2-min demo video, stat sheet. Outreach: TechCrunch Asia, DealStreetAsia, Jakarta Post. [writing]

- [ ] 39. **Onboarding polish** — Teacher signs up → pick exam → Curator auto-generates starter syllabus → invite 3 students via WhatsApp → publish. <5 min total. Magazine-styled onboarding cards. [visual-engineering]

- [ ] 40. **Viral loop instrumented** — Every share tracked: `share_id, sharer, platform, url, clicks, signups, conversions`. Growth dashboard: viral coefficient k, funnel per platform. A/B test share card designs. [unspecified-high]

---

- [ ] F1. **Plan Compliance Audit** — `oracle`
  Read the plan end-to-end. For each "Must Have": verify implementation exists (read file, curl endpoint, run command). For each "Must NOT Have": search codebase for forbidden patterns — reject with file:line if found. Check evidence files exist in `.sisyphus/evidence/`. Compare deliverables against plan.
  Output: `Must Have [N/N] | Must NOT Have [N/N] | Tasks [N/N] | VERDICT: APPROVE/REJECT`

- [ ] F2. **Code Quality Review** — `unspecified-high`
  Run `tsc --noEmit` + linter + `flutter test` + `vitest run`. Review all changed files for: `as any`/`@ts-ignore`, empty catches, console.log in prod, commented-out code, unused imports. Check AI slop: excessive comments, over-abstraction, generic names.
  Output: `Build [PASS/FAIL] | Lint [PASS/FAIL] | Tests [N pass/N fail] | Files [N clean/N issues] | VERDICT`

- [ ] F3. **Real Manual QA** — `unspecified-high` (+ `playwright` skill if UI)
  Start from clean state. Execute EVERY QA scenario from EVERY task — follow exact steps, capture evidence. Test cross-task integration (features working together, not isolation). Test edge cases: empty state, invalid input, rapid actions, offline mode. Save to `.sisyphus/evidence/final-qa/`.
  Output: `Scenarios [N/N pass] | Integration [N/N] | Edge Cases [N tested] | VERDICT`

- [ ] F4. **Scope Fidelity Check** — `deep`
  For each task: read "What to do", read actual diff (git log/diff). Verify 1:1 — everything in spec was built (no missing), nothing beyond spec was built (no creep). Check "Must NOT do" compliance. Detect cross-task contamination: Task N touching Task M's files. Flag unaccounted changes.
  Output: `Tasks [N/N compliant] | Contamination [CLEAN/N issues] | Unaccounted [CLEAN/N files] | VERDICT`

---

## Commit Strategy

- **Wave 1**: `feat(os): foundation — agent runtime, identity graph, passport ledger, i18n, mobile shell, design tokens, observability, CI/CD`
- **Wave 2**: `feat(os): 6 product surfaces — Studio, Coach, Passport, Classroom Live, Insight, Marketplace + 3 agents`
- **Wave 3**: `feat(os): cross-surface integration — Studio↔Coach, Passport↔Insight, Marketplace↔Studio, Classroom↔Coach, mobile offline, viral loop`
- **Wave 4**: `feat(os): production hardening — agent rate limits, passport audit, marketplace disputes, CRDT conflict resolution, mobile sync, l10n QA, perf, security`
- **Wave 5**: `feat(os): launch readiness — app store submission, employer partners, institution pilots, ambassador v2, launch narrative, onboarding polish, viral instrumentation`
- **Final**: `chore(os): v1.0 asia launch — full review pass`

---

## Success Criteria

### Verification Commands
```bash
# Worker
cd worker && npm test && npm run typecheck && npx wrangler deploy --dry-run

# Flutter web + mobile
cd flutter && flutter test && flutter build web --release --no-source-maps && flutter build apk --release && flutter build ios --release --no-codesign

# Agent runtime evals
cd worker && npx tsx scripts/run-agent-evals.ts --agent curator --min-pass-rate 0.85
cd worker && npx tsx scripts/run-agent-evals.ts --agent tutor --min-pass-rate 0.85
cd worker && npx tsx scripts/run-agent-evals.ts --agent examiner --min-pass-rate 0.85
cd worker && npx tsx scripts/run-agent-evals.ts --agent mentor --min-pass-rate 0.85

# E2E
npx playwright test --project=web --project=mobile
```

### Final Checklist
- [ ] All "Must Have" present
- [ ] All "Must NOT Have" absent
- [ ] All tests pass (vitest + flutter test + playwright)
- [ ] All 4 agent evals ≥ 85% pass rate
- [ ] Live app at https://osee-prep-hub.pages.dev loads in < 3s
- [ ] Mobile apps in App Store + Play Store
- [ ] 10 partner employers can verify Passports via API
- [ ] 5 pilot institutions on OSEE Insight
- [ ] Marketplace has ≥ 100 listings
- [ ] Real-time collaboration works (two browsers, same syllabus, live cursor sync)
- [ ] Bahasa Indonesia UI fully localized
- [ ] Offline mode works (Coach + Studio load with no network)
- [ ] Magazine design language maintained (design review passed)

---

## Appendix: Detailed Task Bodies

> The task summaries above give the executing agent the scope. The details below give them the exact acceptance criteria, QA scenarios, references, and commit strategy. When a task is dispatched, include both the summary and the detailed body.

### T1 — Agent Runtime Core (detailed)

**What to do**: Build `worker/src/agents/runtime.ts` — `AgentDefinition` (name, systemPrompt, tools[], model, temperature), `AgentContext` (userId, sessionId, history, RAG retriever), `AgentRunner` (executes a turn), `ToolBus` (registers + executes tools). Built-in tools: `rag_search(query, topK)`, `fetch_user_profile(userId)`, `fetch_syllabus(syllabusId)`, `fetch_student_progress(studentId)`. `POST /api/agents/:agentName/invoke` endpoint (rate-limited 20/min free, 200/min pro). `scripts/run-agent-evals.ts` harness. 4 stub agents.

**Must NOT do**: No fine-tuning. No streaming (batch JSON). No agent-to-agent comm in Wave 1.

**References**: `worker/src/services/ai-generation.ts` (LLM call pattern), `worker/src/services/rag-search.ts` (rag_search wraps this), `worker/src/types.ts` (Env type).

**Acceptance Criteria**:
- [ ] `worker/src/agents/runtime.ts` exists with all 4 types
- [ ] `POST /api/agents/:agentName/invoke` returns 200 with `{response, toolCalls, tokensUsed}`
- [ ] `npx tsx scripts/run-agent-evals.ts --agent curator --min-pass-rate 0.85` exits 0
- [ ] `npm --workspace worker run test` passes
- [ ] 21st request in 1 min returns 429

**QA Scenarios**:
```
Scenario: Agent runtime invokes stub agent
  Tool: Bash (curl)
  Steps: 1. POST /api/agents/curator/invoke with valid JWT + input
  2. Assert 200, body has response (string), toolCalls (array), tokensUsed (number)
  Evidence: .sisyphus/evidence/task-1-agent-invoke.txt

Scenario: Rate limit enforced
  Tool: Bash (curl loop)
  Steps: 1. Send 21 requests in <60s
  2. Assert 21st returns 429 with {"error":{"code":"RATE_LIMITED"}}
  Evidence: .sisyphus/evidence/task-1-rate-limit.txt
```

**Commit**: `feat(os): agent runtime core — types, registry, tool bus, eval harness`

### T2 — Real-time Presence (detailed)

**What to do**: `y-supabase` dependency. `worker/src/services/realtime.ts` (presence + broadcast + postgres_changes). `flutter/lib/core/realtime_client.dart` (Yjs provider for syllabus items). `syllabus_collaborators` table. Realtime on `syllabus_items`.

**References**: `supabase-community/y-supabase` (GitHub), `supabase.com/blog/flutter-figma-clone` (Flutter Realtime pattern), `schema.sql` lines 147-194 (syllabus_items).

**Acceptance Criteria**:
- [ ] `syllabus_collaborators` table created
- [ ] Realtime enabled on `syllabus_items`
- [ ] Two browser tabs: drag card in tab 1 → tab 2 shows it within 200ms
- [ ] Presence bar shows "2 online"
- [ ] `npm --workspace worker run test` passes

**QA Scenarios**:
```
Scenario: Real-time card move syncs
  Tool: Playwright (two contexts)
  Steps: 1. Open syllabus in browser A + B (two collaborators)
  2. Drag card from Week 1 to Week 3 in A
  3. Assert B shows card in Week 3 within 300ms
  Evidence: .sisyphus/evidence/task-2-rt-sync.png

Scenario: Presence indicator
  Tool: Playwright
  Steps: 1. Open in A + B → assert "2 online"
  2. Close B → wait 3s → assert "1 online"
  Evidence: .sisyphus/evidence/task-2-presence.png
```

**Commit**: `feat(os): identity graph + real-time presence via Yjs + Supabase Realtime`

### T3 — Passport Ledger (detailed)

**What to do**: `passport_credentials` + `passport_evidence` + `passport_verifications` tables. Ed25519 signing (`@noble/ed25519`). `worker/src/services/passport.ts` (issue, verify, revoke). 5 endpoints. `PASSPORT_SIGNING_KEY` wrangler secret. Public key at `/.well-known/passport-public-key.pem`.

**References**: `schema.sql` (schema patterns), `worker/src/services/jwt.ts` (signing pattern), `worker/src/types.ts` (add PASSPORT_SIGNING_KEY to Env), W3C VC Data Model.

**Acceptance Criteria**:
- [ ] 3 Passport tables exist
- [ ] POST /api/passport/issue returns 201 with signature
- [ ] GET /api/passport/:id (no auth) returns credential + evidence
- [ ] Tampered evidence → verifyCredential returns valid: false
- [ ] Revoked → valid: false, reason: 'revoked'
- [ ] Public key endpoint works
- [ ] Tests pass

**QA Scenarios**:
```
Scenario: Issue + verify
  Tool: Bash (curl)
  Steps: 1. POST /api/passport/issue → 201, capture ID
  2. GET /api/passport/$ID (no auth) → 200, valid: true
  Evidence: .sisyphus/evidence/task-3-passport-issue.txt

Scenario: Tampered evidence fails
  Tool: Bash (psql + curl)
  Steps: 1. UPDATE evidence metadata → tampered
  2. GET /api/passport/$ID → valid: false, reason contains 'signature'
  Evidence: .sisyphus/evidence/task-3-passport-tamper.txt
```

**Commit**: `feat(os): OSEE Passport ledger — Ed25519-signed verifiable credentials`

### T4-T8 (detailed summaries)

**T4 i18n**: `app_en.arb` + `app_id.arb` (≥100 keys each). `flutter gen-l10n` succeeds. Locale toggle works. `grep -r "Text('" ... --include="*.dart" | grep -v AppLocalizations` ≤5 results. QA: toggle to Bahasa → bottom nav shows "Beranda" not "Home". Commit: `feat(os): i18n infrastructure — Bahasa + English ARB files`

**T5 Mobile**: `flutter build apk --release` + `flutter build ios --release --no-codesign` succeed. Offline banner shows. Offline edit syncs on reconnect. Deep link `/r/ABC123` opens register with code pre-filled. QA: airplane mode → edit → reconnect → synced. Commit: `feat(os): native mobile shell + offline sync engine`

**T6 Design tokens**: `flutter/lib/design/` with tokens, typography, components. `/dev/design` showcase renders all components. Refactored pages have no inline `_Magazine*` widgets. `docs/design_review.md` exists. QA: showcase page renders masthead + drop cap + publish stamp. Visual comparison <2% pixel diff. Commit: `feat(os): formalized magazine design system`

**T7 Observability**: `SENTRY_DSN` set. Structured logs in Logflare. `agent_traces` table. 5 invocations → 5 rows. No PII in logs. QA: forced error → Sentry event. Agent invoke → trace row. Commit: `feat(os): observability — Sentry, structured logging, agent traces, RUM`

**T8 CI/CD**: `.github/workflows/ci.yml` + `deploy-prod.yml`. Push to magazine-ui → staging deploy. PR to main → CI. Merge → prod deploy. Failing test blocks deploy. README badges. QA: push → check `gh run list` → staging health 200. Add failing test → deploy blocked. Commit: `feat(os): CI/CD pipeline — GitHub Actions, staging + prod`

### T9-T10 (detailed)

**T9 Studio**: Yjs sync, presence bar (gold rule + avatars), multi-cursor (colored dots + name), invite by email, share read-only link, Curator "Suggest" button (ghost cards with dashed gold borders). Acceptance: two browsers sync <300ms, presence "2 online", share link read-only, Curator shows 3-5 ghost cards. QA: two-teacher real-time collab screenshot, read-only view no save button. Commit: `feat(os): OSEE Studio — real-time collaborative canvas`

**T10 Coach**: `coach_page.dart` magazine chat UI. Tutor agent. Tools: rag_search, fetch_student_progress, fetch_syllabus, create_practice_question. `coach_sessions` table. Floating "Ask Coach" button. Text-only (voice disabled with "Coming soon"). Acceptance: response <3s p95, context-aware (mentions syllabus), history persists, floating button on 3+ pages. QA: "What should I practice next?" → response mentions reading/syllabus. Refresh → history persists. Commit: `feat(os): OSEE Coach — 24/7 AI tutor`

### T11-T40 (detailed summaries — expand when dispatching)

Each task T11-T40 should be expanded by the executing agent using the same structure (What to do / Must NOT do / References / Acceptance Criteria / QA Scenarios / Commit). The summary in the main TODOs section gives the scope; the references in the plan point to the right files; the acceptance criteria are implicit in the "What to do" bullet points and should be made explicit before dispatch.