# Testing — OSEE Prep Hub Worker

## Framework

- **vitest** — matches EduBot's worker (`D:\claude telegram bot\worker\vitest.config.ts`)
- **Version**: ^4.1.4 (same as EduBot)
- **Environment**: `node` (not jsdom — we test pure functions, not DOM)
- **Include pattern**: `src/**/*.test.ts`
- **Timeout**: 10 seconds

## Commands

```bash
cd worker
npm test              # vitest run (one-shot)
npm run test:watch    # vitest watch mode
npm run typecheck     # tsc --noEmit (separate from tests)
```

## Patterns (from EduBot audit)

EduBot's test patterns observed in:
- `D:\claude telegram bot\worker\src\services\user-roles.test.ts` — pure function testing
- `D:\claude telegram bot\worker\src\services\referral-commission.test.ts` — financial logic with idempotency
- `D:\claude telegram bot\worker\src\routes\tests.test.ts` — route testing

### Pattern: Pure function tests

```typescript
import { describe, it, expect } from 'vitest';
import { myFunction } from './my-module';

describe('myFunction', () => {
  it('does X when Y', () => {
    expect(myFunction(input)).toBe(expectedOutput);
  });

  it('handles edge case Z', () => {
    expect(myFunction(edgeCase)).toBe(expectedEdgeResult);
  });
});
```

### Pattern: Mocking D1 / external bindings

EduBot's tests mock D1 inline (no Vitest pool workers needed for pure functions). For tests that need bindings:

```typescript
// Inline mock — no pool-workers config needed
const mockEnv = {
  DB: {
    prepare: (sql: string) => ({
      bind: (...args) => ({ run: async () => ({ success: true }) }),
      all: async () => ({ results: [] }),
      first: async () => null,
    }),
  },
};
```

For full request-path tests (Hono app with `app.request()`), use Vitest's built-in fetch mocking or `miniflare` (added later if needed).

## What to Test Per Task

Every worker task must include:
1. **Happy path** — normal input, expected output
2. **Edge cases** — empty input, null, boundary values
3. **Error cases** — invalid input, missing fields, unauthorized
4. **Idempotency** (for financial/recurring operations) — calling twice doesn't double-apply

## Test File Naming

- `src/services/foo.ts` → `src/services/foo.test.ts`
- `src/routes/bar.ts` → `src/routes/bar.test.ts`
- Place test file next to source file, same directory.

## Coverage

No coverage thresholds enforced. Focus on critical paths:
- Auth (security)
- Commission (financial)
- Orders (financial)
- Vouchers (access control)
- Quota (revenue limits)