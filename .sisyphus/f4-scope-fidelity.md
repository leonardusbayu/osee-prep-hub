# F4 — Scope Fidelity Check

**Date:** 2026-07-10
**Scope:** Compare `.sisyphus/plans/osee-wildest-dream.md` (40 tasks across 5 waves) against 7 commits.

## Scope creep (features added beyond plan)

**None found.** All 7 commits add exactly what was promised in the plan. No bonus endpoints, no unrequested features.

## Scope gaps (plan features not delivered)

| Plan Task | Status | Reason |
|---|---|---|
| T9 OSEE Studio | ⚠️ Skeleton only | Real-time Yjs sync + multi-cursor + ghost cards not implemented. Flutter page renders presence bar + item cards + Curator Suggest button (no-op). |
| T12 OSEE Classroom Live | ⚠️ Skeleton only | LiveKit credentials not wired. Worker returns mock JWT. Flutter page is UI-only. |
| T13 OSEE Insight | ⚠️ Partial | Worker service queries real Supabase data. Flutter page uses mock data (not yet fetching). |
| T23 Push notifications | ⚠️ Stub delivery | Token registration + topic subscription + log work. Actual delivery via FCM/OneSignal not wired. |
| T26 Agent runtime prod hardening | ⚠️ Partial | Cost guards + retry/failover done. p95 latency targets unverified. |
| T27 Passport audit + employer API | ⏭️ Deferred | Employer verification exists (T3) but no audit trail. |
| T29 Real-time sync conflict resolution | ⏭️ Deferred | Blocked by T9 skeleton — no real CRDT to merge. |
| T30 Mobile offline sync reconciliation | ⚠️ Partial | flutter OfflineSyncEngine covers pull/queue/flush. Server-side reconciliation via server-wins is in place. |
| T31 Localization QA | ⏭️ Deferred | No native-speaker review of Bahasa ARB. |
| T32 Performance | ⏭️ Deferred | No load testing. SLA targets unverified. |
| T34 App Store submission | ⏭️ Deferred | Design/writing task. |
| T35 Employer partner onboarding | ⏭️ Deferred | Writing task. |
| T36 Institution pilot | ⏭️ Deferred | Writing task. |
| T39 Onboarding polish | ⏭️ Deferred | Design task. |

## Spec mismatches (delivered but different from plan)

### T37 Ambassador v2 — minor

- **Plan said:** "Top 20 teachers: 2x commission, badge, Discord, equity options (0.01-0.05%, 2-year vest)"
- **Delivered:** 4-tier system (partner 1x / ambassador 1.25x / top_ambassador 1.5x + 5M IDR / elite 2x + 25M IDR)
- **Difference:** 4 tiers instead of just "top 20". Equity denominated in IDR (5M / 25M) instead of company %. Discord integration not delivered.
- **Severity:** Low. The 4-tier design is more flexible than the "top 20" model. IDR-denomination is defensible until company valuation is set. Discord is a real omission but not a blocker.

### T9 OSEE Studio — significant

- **Plan said:** "Yjs sync, presence bar, multi-cursor, invite collaborator by email, share read-only link, Curator Suggest button (ghost cards). Magazine design: gold-rule presence bar, stamp-styled invite."
- **Delivered:** Flutter StudioPage with magazine styling + presence bar (hardcoded mock collaborators). Worker studio routes for snapshot persistence + share token generation. **Yjs sync, multi-cursor, real collaborator invite, ghost cards all NOT delivered.**
- **Severity:** HIGH. The plan calls out the magazine's headline feature — "Real-time collaborative canvas" — and only the chrome is built.

### T12 Classroom Live — significant

- **Plan said:** "WebRTC via LiveKit (Flutter + Worker JWT room join), Yjs-synced whiteboard, real-time polls, breakout rooms. AI summary post-class (Examiner agent). Recording to R2."
- **Delivered:** Flutter LiveClassPage with "JOIN LIVE" button (no handler). Worker live-classes routes with mock JWT. **No LiveKit SDK, no whiteboard, no polls, no breakout rooms, no recording.**
- **Severity:** HIGH. The feature can't be used at all without LiveKit credentials + Flutter livekit_client package.

### T23 Push notifications — minor

- **Plan said:** "Mobile push notifications + deep links"
- **Delivered:** Server-side queue + log works. Tokens registered. **FCM/OneSignal SDK not wired — push won't actually deliver to devices.**
- **Severity:** MEDIUM. Server infrastructure is ready; only the delivery provider integration is missing.

### T15-T17 Agent eval coverage — matches plan

- Plan said: "20 test cases each"
- Delivered: 20 each ✓

### T30 Mobile offline sync — matches plan

- Plan said: "Mobile offline sync reconciliation"
- Delivered: OfflineSyncEngine (pull/queue/flush) + server-side server-wins conflict resolution ✓ (with caveat that conflicts are logged, not surfaced in UI)

### T40 Viral loop — matches plan

- Plan said: "Viral growth loop surface (Passport share + referral engine)"
- Delivered: Referral codes + share event tracking + click conversion tracking ✓ (UI surfaces not built — would be in Flutter passport share sheet + Coach recommend button)

## Summary

| Category | Count |
|---|---|
| Plan features delivered as-spec | 26 of 40 |
| Plan features delivered with minor differences | 1 (T37) |
| Plan features delivered as skeletons | 4 (T9, T12, T13, T23) |
| Plan features deferred (writing/perf/design) | 9 (T27, T29, T31, T32, T34-T36, T39) |

The 4 skeleton tasks (T9, T12, T13, T23) and the 9 deferred tasks are known, documented in commit messages, and not silently missing. They represent the gap between "code is committable" and "feature is user-shippable".

**Recommendation:** Before claiming production-launch ready, prioritize:
1. T9 Yjs sync (real-time is the headline)
2. T12 LiveKit credentials (live class can't work without)
3. T23 FCM/OneSignal wiring (push won't deliver)
4. T32 performance verification (SLA claim)

Items 4-9 in the deferred list are non-engineering and don't block the code from being merged to main.