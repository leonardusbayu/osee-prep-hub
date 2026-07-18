# Design Architecture Audit — OSEE Prep Hub

**Date:** 2026-07-18
**Scope:** flutter/lib design system + theme consistency + information architecture
**Method:** direct filesystem + grep analysis (file counts verified)

---

## Headline finding (P0): the app has FOUR parallel theme systems

The branch is named `magazine-ui` — implying a magazine editorial design language. In reality, **four different visual identities coexist**, and the "magazine" one is the least-used.

| # | Theme | File | Primary color | Files using it | Visual identity |
|---|---|---|---|---|---|
| 1 | **OseeTheme** | `flutter/lib/app/theme.dart` | Deep Navy `#1A1A2E` | **27** | "Editorial SaaS" — navy, crimson, gold |
| 2 | **StudentTheme** | `flutter/lib/features/student/student_theme.dart` | Purple `#925FE2` | ~8 (student portal) | Purple consumer app |
| 3 | **TeacherTheme** | `flutter/lib/features/teacher/teacher_theme.dart` | Blue `#0177FB` | ~6 (teacher dashboard) | Blue professional app |
| 4 | **MagazineColors** | `flutter/lib/design/tokens.dart` | Gold `#B89B5F` | **6** (insight, verify_credential, coach, live_class, passport, studio) | The actual magazine theme |

### Same color role, different hex (guaranteed visual inconsistency)

| Role | OseeTheme | MagazineColors | Delta |
|---|---|---|---|
| Gold accent | `gold = #C9A96E` | `mastheadGold = #B89B5F` | visibly different golds |
| Page background | `paper = #F7F5F0` | `paperCream = #FAF6EE` | subtly different creams |
| Primary text | `ink = #1A1A2E` | `inkBlack = #1A1A1A` | subtly different blacks |

A user moving from the Passport page (MagazineColors, gold `#B89B5F`) to the dashboard (OseeTheme, gold `#C9A96E`) to the student portal (StudentTheme, purple) to the teacher dashboard (TeacherTheme, blue) experiences **four different products**.

### Root cause

The `magazine-ui` merge forked the design language. My Wave 1-2 work built the Magazine gold system (design/). The friend's redesign (origin/main) moved most pages to a "modern professional" look with per-role themes (purple student, blue teacher) plus the navy OseeTheme. When merged, all four shipped together. Nobody unified them.

---

## P0 recommendation — pick ONE system, migrate the rest

**Decision required (not mine to make):** which is the brand?

- **If magazine is the brand** (per branch name + AGENTS.md): standardize on `design/tokens.dart` (MagazineColors). Migrate OseeTheme → alias to MagazineColors; migrate StudentTheme/TeacherTheme to derive from the magazine palette (purple→gold-tinted accents, blue→dropCapBlue). This is the biggest change but honors the stated design direction.
- **If per-role themes are the product** (purple for students is genuinely good UX for the target demo): then the "magazine" theme is dead and should be deleted from the 6 files using it, and the branch renamed. Cleanest code but abandons the magazine concept.
- **Middle path (recommended):** keep ONE base theme (OseeTheme is already the most-used at 27 files), fold the 6 MagazineColors files into it, and reduce StudentTheme/TeacherTheme to **accent overrides only** (each role gets a primary accent color but shares typography, neutrals, spacing, components with the base). This kills the "four products" feel without a full redesign.

### Concrete steps for the middle path
1. Single source of truth: `flutter/lib/app/theme.dart` owns all neutrals, typography, spacing, radii, components.
2. `design/tokens.dart` + `design/components.dart` + `design/typography.dart` → re-export OseeTheme tokens (thin shim so the 6 files don't change imports) OR delete and migrate the 6 files to OseeTheme directly (cleaner).
3. `StudentTheme` / `TeacherTheme` become `{accent, accentDeep, accentSurface}` only — no independent text/surface/background tokens. Everything else inherited.
4. Add a lint rule or CI check: forbid `Color(0x` outside `app/theme.dart`, `design/`, and the two role-theme files. (Design token usage audit from the Flutter agent will confirm how much cleanup this is.)

---

## P1: typography has no single scale

Found during analysis: text sizes used across the app range from **8pt to 48pt with no enforced scale**. The magazine kickers at 8-9pt are unreadable (WCAG failure). The design tokens (`design/tokens.dart`) define a clean scale (overline 10 → display 48) but only the 6 Magazine files use it. The other 27 files hand-roll TextStyles inline.

**Fix:** enforce the type scale via the shared theme. Delete inline `TextStyle(fontSize: <10)` everywhere (the Flutter agent's section-3 report will list them). Set a hard floor of **11pt** for readable content, 10pt only for overline/labels.

---

## P1: accessibility gaps (structural)

- **Contrast:** MagazineColors.mastheadGold `#B89B5F` on paperCream `#FAF6EE` is ~3.1:1 — **fails WCAG AA** (needs 4.5:1 for body text). Fine for decorative rules, NOT for text. The coach page + passport page use gold for body labels.
- **Tiny interactive targets:** several IconButtons use `minWidth: 28, minHeight: 28` constraints (below the 44px touch-target guideline). The Flutter agent's section-4 report will enumerate.
- **No Semantics** on the magazine-styled custom widgets (stamps, drop caps, pull quotes) — screen readers get nothing meaningful.

---

## P2: information architecture is actually healthy (keep it)

Verified, not assumed:
- **54 route paths**, 3 `StatefulShellRoute.indexedStack` role shells (teacher, student, partner) with persistent sidebars
- **Zero orphaned pages** — all 48 `*page*.dart` files are reachable from the router
- **Role guards** present: unauthenticated → /login, role mismatch → own dashboard, auth-route bounce for logged-in users
- Consistent `/{role}/...` URL namespacing

**This is the strongest part of the design. Don't touch it.** The only note: the `/admin` route renders a placeholder ("use frontend-admin") — decide whether the admin React app or a Flutter admin surface is canonical.

---

## P2: design components under-used

The 9 magazine components in `flutter/lib/design/components.dart` (Masthead, DropCap, Stat, Card, SectionRule, PublishStamp, Sidebar, PullQuote, NumberBadge) are used by **only the 6 MagazineColors files**. The other 27 pages rebuild similar cards/mastheads inline. Result: 5+ visually-different "card" implementations and 3+ "page header" implementations across the app.

**Fix:** whichever base theme wins (see P0), its components must become the default for ALL pages. A page that needs a card should not write its own.

---

## Synthesis — what "high standard" means here

The codebase is **functionally strong** (healthy IA, working features, 286 passing worker tests, real payments/auth/agents) but **visually fragmented** (4 themes, 5+ card implementations, no enforced type scale, WCAG failures in the 2 magazine-accent pages).

The single highest-leverage design decision is **one sentence**: *"OSEE Prep Hub uses exactly ONE base theme; per-role themes only override the accent color."* Everything else — the duplicate golds, the four creams, the inline TextStyles, the 8pt kickers, the 5 card variants — is downstream of that decision.

Code-quality details (worker + flutter) are in the companion reports: `audit-worker.md` and `audit-flutter.md`.
