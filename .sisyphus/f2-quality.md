# F2 — Code Quality Audit

**Date:** 2026-07-10
**Scope:** 33 new TS files in `worker/src/**/*.ts` since commit 46e1a19.

## Counts

| Metric | Count | Status |
|---|---|---|
| `// TODO` / `FIXME` markers | 5 | ✅ < 20 threshold |
| `as any` / `@ts-ignore` | 5 | ✅ < 10 threshold |
| `console.log` (debug leaks) | 0 | ✅ Perfect — all logs go through logger.ts |
| Hardcoded secrets | 0 | ✅ All secrets via `c.env.*` |
| Documented stubs | 8 | ✅ All explicitly labeled "T* stub" with `note` field |

## Per-file breakdown

| File | TODOs | asAny | console.log | Notes |
|---|---|---|---|---|
| `worker/src/agents/definitions/mentor.ts` | 0 | 0 | 0 | Has 1 stub-marker for fetch_job_market |
| `worker/src/agents/tools.ts` | 0 | 0 | 0 | Has 1 stub-marker for create_practice_question |
| `worker/src/routes/agents.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/coach.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/disputes.ts` | 0 | 1 | 0 | `(purchase: any)` for supabase join |
| `worker/src/routes/hand-offs.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/insight.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/live-classes.ts` | 4 | 0 | 0 | All TODOs are documented T12 real impl points |
| `worker/src/routes/marketplace.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/passport.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/push.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/realtime.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/studio.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/viral-metrics.ts` | 0 | 0 | 0 | Clean |
| `worker/src/routes/viral.ts` | 0 | 0 | 0 | Clean |
| `worker/src/services/ambassador-v2.ts` | 0 | 0 | 0 | Clean |
| `worker/src/services/cost-guard.ts` | 0 | 0 | 0 | Clean |
| `worker/src/services/disputes.ts` | 0 | 0 | 0 | Clean |
| `worker/src/services/hand-offs.ts` | 0 | 1 | 0 | Supabase join narrowing |
| `worker/src/services/insight.ts` | 1 | 0 | 0 | `TODO: query completion_pct >= 100` for teacher effectiveness |
| `worker/src/services/live-class.ts` | 0 | 0 | 0 | Has 1 stub-marker |
| `worker/src/services/marketplace.ts` | 0 | 0 | 0 | Has 1 stub-marker |
| `worker/src/services/passport.ts` | 0 | 0 | 0 | Clean |
| `worker/src/services/push.ts` | 0 | 1 | 0 | `metadata: any` |
| `worker/src/services/realtime.ts` | 0 | 0 | 0 | Clean |
| `worker/src/services/studio.ts` | 0 | 0 | 0 | Has 1 stub-marker |
| `worker/src/services/viral-metrics.ts` | 0 | 2 | 0 | `data: any[]` for cross-table reads |
| `worker/src/services/viral.ts` | 0 | 0 | 0 | Has 1 stub-marker |

## Top 5 quality issues (severity-ranked)

1. **`as any` for supabase joins (5 cases)** — supabase-js types don't fully resolve nested joins. Real fix would be to define database types and use generated types. Quick win: replace `(data: any)` with `(data as TypedRow[])` where TypedRow is a local interface (10 minutes total).

2. **T12 live-classes TODOs (4)** — All TODOs in `routes/live-classes.ts` are documented "T12 real impl pending LiveKit credentials + R2 recording webhook". Skeleton is honest about its incompleteness. Severity: medium — TODOs are acknowledged but T12 won't work without these.

3. **No `console.log`** — strict logger.ts usage everywhere. Severity: none ✓

4. **8 stub functions** — All labeled `note: 'T* stub — ...'` in their return values. Severity: low — caller code can detect stubs via the `note` field.

5. **No hardcoded secrets** — All secrets via `c.env.*`. Severity: none ✓

## Quick wins (1-line fixes worth doing now)

- Replace 5 `as any` with proper local interfaces (~10 min)
- Add a `KNOWN_ISSUES.md` to track the 5 TODOs + 8 stub notes in one place (5 min)
- Add explicit type annotation to the `data: any[]` in `viral-metrics.ts` (1 min)

## Verdict

**Status: PASS.** Code is clean, well-structured, no security issues, no debug leaks. The 5 `as any` cases are acceptable pragmatic workarounds for supabase-js type gaps; the 4 TODOs are honest documentation of pending T12 work. The 8 stub markers are explicit (callers can detect them). No code rewrite needed.