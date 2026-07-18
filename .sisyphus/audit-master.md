# High-Standard Audit — OSEE Prep Hub

**Date:** 2026-07-18 · **Branch:** magazine-ui · **Method:** direct code + filesystem analysis (every finding has file:line evidence)
**Companion reports:** [`audit-design.md`](./audit-design.md) (theme architecture) · worker/flutter sweeps below

---

## What's genuinely good (keep, don't touch)

- **Information architecture** — 54 routes, 3 role shells, role guards, **zero orphaned pages**. Strongest part of the app.
- **Worker test coverage** — 286/286 passing, typecheck clean, zero empty `catch{}` blocks found.
- **React admin code** — single Tailwind theme, reusable component classes (`.card`, `.btn-primary`, `.stat-card`), small files (max 237 lines). Best-structured of the three frontends.
- **Feature breadth** — real payments (TriPay), Ed25519 Passport, 4 AI agents, marketplace + escrow, viral loop, disputes.

**The product works. The problem is cohesion — it looks like five different products stitched together.**

---

## P0 — Ship-blocking (fix first)

### P0-1. Six visual identities, zero brand cohesion
Branch is `magazine-ui` but the magazine theme is the *least* used. Full inventory:

| Theme | Color | Files | Identity |
|---|---|---|---|
| OseeTheme | Navy `#1A1A2E` | 27 | Editorial SaaS |
| StudentTheme | Purple `#925FE2` | ~8 | Purple consumer |
| TeacherTheme | Blue `#0177FB` | ~6 | Blue professional |
| MagazineColors | Gold `#B89B5F` | 6 | Actual magazine |
| React admin | Indigo `#4f46E5` | 15 | Indigo admin |

Same role, different hex — gold `#C9A96E` vs `#B89B5F`, cream `#F7F5F0` vs `#FAF6EE`, ink `#1A1A2E` vs `#1A1A1A`. A user crossing pages sees five products.

**The one-sentence fix:** *OSEE uses exactly ONE base theme; role themes only override the accent.*
- **Action:** Pick the base (recommend OseeTheme — already 27 files). Convert `design/tokens.dart` + `design/components.dart` to re-export it (shim for the 6 files, then delete). Reduce `StudentTheme`/`TeacherTheme` to `{accent, accentDeep, accentSurface}` only — strip their independent text/surface/background tokens. Port the React admin `osee` Tailwind scale to match the base accent.
- **Owner:** design + frontend. **Effort:** 2-3 days. Full plan in `audit-design.md`.

### P0-2. WCAG failures in the 2 magazine-accent pages
- `MagazineColors.mastheadGold #B89B5F` on `paperCream #FAF6EE` = **~3.1:1 contrast** — fails AA (needs 4.5:1) for body text. Used for body labels in `coach_page.dart:115`, `insight_page.dart:191`.
- **~15+ font sizes below 11pt** (unreadable): `scrapbook_lesson.dart` 9pt ×4, `insight_page.dart` 10pt ×2, `coach_page.dart` 10pt, `live_classes_page.dart` 10pt, `landing_page.dart` 10pt.
- **Action:** darken gold text to `#8A6B35` (passes AA), raise floor to 11pt body / 10pt labels, remove every `fontSize: <11` in feature files.

---

## P1 — High-impact quality

### P1-1. Logging bypasses the PII scrubber (privacy risk)
I built `worker/src/services/logger.ts` (T7) specifically to scrub email/phone/display_name/password from logs. **But ~11 call sites bypass it with raw `console.log`/`console.error`:**
- `index.ts:181, 212, 215, 223, 226, 235, 239` — error handler + cron handlers
- `agents.ts:107`, `ai.ts:39`, `cache.ts:97`, `webhook-auth.ts:23`, `tracing.ts:71`

`ai.ts:39` logs `rag-search user=${user.id}` — user IDs flow unfiltered to Cloudflare logs. Cron handlers log outcomes unscrubbed.
- **Action:** route all 11 through `logger.{info,warn,error}`. 30 min. **Also:** the cron handlers (index.ts:210-239) reference handlers whose trigger I removed from `wrangler.toml` during the deploy fix — decide: re-add the trigger via dashboard or delete the dead cron code.

### P1-2. God-routes + god-widgets
Worker routes by size: `teacher.ts` 728, `boards.ts` 690, `admin.ts` 588, `ai.ts` 577, `auth.ts` 484 lines. Flutter widgets: `mind_map_recipe_page.dart` 2121, `syllabus_builder_page.dart` 1948 (being rewritten), `auth_widgets.dart` 997, `scrapbook_lesson.dart` 980.
- **Action:** split routes by domain (`teacher/dashboard.ts`, `teacher/classrooms.ts`, `teacher/syllabi.ts`). Split Flutter pages into sub-widgets. Target ≤300 lines/file. Not urgent — works today — but every edit to these files is high-risk.

### P1-3. Dead/orphaned code from the deploy
- Cron handlers in `index.ts:210-239` (trigger removed).
- `.dev.vars.example` + `.dev.vars` drift — the 8 new secrets I set (PASSPORT, LIVEKIT, SENTRY, VALUATION) may not be in the example file, so the next dev to clone breaks locally.
- **Action:** reconcile `.dev.vars.example` with the 28 actual secrets. Delete or re-enable the cron code.

---

## P2 — Polish (acceptable now, worth scheduling)

- **`as any` in prod code:** 5 instances (viral-metrics.ts:2, disputes.ts:1, handoffs.ts:1, push.ts:1) — all supabase join narrowing. Acceptable pragmatic workaround; replace with typed interfaces when convenient. Tests have 13 more (fine).
- **Syllabus builder** (1948 lines): rebuild to vertical timeline already in flight (`bg_7b507bc3`, visual-engineering). Don't audit the current file — it's being replaced.
- **Component reuse:** only 6 files use the 9 magazine components; 27 rebuild cards/mastheads inline → 5+ card variants. Fold into the P0-1 base-theme migration.

---

## Remediation backlog (ranked by impact ÷ effort)

| # | Fix | Impact | Effort | Owner |
|---|---|---|---|---|
| 1 | P0-1 unify to ONE base theme + role-accent-only | 🔴 brand | 2-3 d | design + FE |
| 2 | P0-2 fix WCAG (darken gold, 11pt floor) | 🔴 accessibility | 4 h | FE |
| 3 | P1-1 route all logs through logger.ts | 🟡 privacy | 30 m | BE |
| 4 | P1-3 reconcile `.dev.vars.example` + dead cron | 🟡 dev-onboarding | 1 h | BE |
| 5 | P1-2 split god-routes/widgets | 🟡 maintainability | 2 d | BE + FE |
| 6 | P2 typed interfaces for the 5 `as any` | 🟢 type-safety | 1 h | BE |

**Total:** ~1 week for the P0+P1 items that materially change user trust (brand) and compliance (accessibility/privacy).

---

## Synthesis

The app is **functionally excellent, visually incoherent, and has three small but real compliance gaps** (WCAG contrast, PII-in-logs, dead cron code). None of these need a redesign sprint. They need:
1. **One theme decision** (P0-1) — the single highest-leverage call.
2. **~5 hours of targeted fixes** (P0-2, P1-1, P1-3) that can ship this week.
3. **Refactor scheduling** (P1-2) for maintainability, not correctness.

**Recommended first action:** decide the base theme (P0-1). Everything else is downstream. Tell me which base you want and I'll start the migration + the 5-hour compliance fixes immediately.
