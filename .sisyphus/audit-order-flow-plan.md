# Order Flow Audit Plan — OSEE Prep Hub

**Generated:** 2026-07-11
**Scope:** End-to-end order flow from Flutter checkout → TriPay payment → fulfillment → voucher issuance
**Estimated total time:** 2-3 days (1 day automated, 1 day manual, 0.5 day remediation)
**Risk if not audited:** **HIGH** — webhook signature verification is unimplemented, payment processing is mocked

---

## 0. Headline Findings (must read first)

Before we dive in, **the smoke test already revealed 3 critical issues**. These should be addressed before the audit even starts:

| # | Severity | Issue | Location |
|---|---|---|---|
| **C1** | 🔴 Critical | **TriPay webhook signature verification is `TODO`**. Any attacker can POST to `/api/orders/webhook/tripay` with `merchant_ref` + `status: 'paid'` and mark any order paid. | `worker/src/routes/orders.ts` webhook handler |
| **C2** | 🔴 Critical | **TriPay redirect URL is a mock** (`https://tripay.co.id/checkout?ref=...`). No real payment is initiated. The "paid" webhook is the only thing that flips status, but with no real payment, this is theater. | `worker/src/routes/orders.ts` `/pay` handler |
| **C3** | 🟡 Medium | **No rate limiting** on order endpoints (`POST /api/orders`, `/pay`). Cost-guard middleware exists for agents but not orders. A bad actor could create thousands of pending orders to exhaust voucher codes or storage. | `worker/src/routes/orders.ts` |

**Recommendation:** Audit C1 immediately. Fix before any audit work continues.

---

## 1. What's in scope

The order flow consists of 4 ordering modes per `worker/src/services/orders.ts`:
1. `voucher_resale` — buy vouchers at discount, distribute to students, keep margin
2. `book_for_student` — book official tests on behalf of students (OSEE booking bridge)
3. `bulk_purchase` — buy packages, assign to specific students
4. `self_purchase` — buy for own use

**Surface area to audit:**

| Layer | Files |
|---|---|
| **DB schema** | `schema.sql` lines 906–999 (pricing_config, orders, order_items, vouchers) + migrations |
| **Backend services** | `worker/src/services/orders.ts`, `pricing.ts`, `voucher.ts` |
| **Backend routes** | `worker/src/routes/orders.ts`, `voucher.ts`, `webhook.ts` |
| **External integrations** | TriPay (payment gateway), OSEE booking API, EduBot bridge |
| **Frontend (Flutter)** | `flutter/lib/features/student/pages/order_page.dart`, `teacher_dashboard_page.dart` |
| **Secrets** | `TRIPAY_API_KEY`, `TRIPAY_PRIVATE_KEY`, `TRIPAY_MERCHANT_CODE`, `OSEE_BOOKING_API_URL` + `OSEE_BOOKING_API_SECRET`, `WEBHOOK_SECRET_BOOKING` |
| **Production logs** | Cloudflare Worker logs for `tripay`, `webhook`, `payment` events |

---

## 2. Audit phases (sequential)

### Phase A — Schema integrity (1 hour)

**Goal:** Ensure the DB schema enforces business rules and won't allow bad data.

**Checks:**

- [ ] **`orders.status` transitions** — schema only enforces the set of allowed values, NOT which transitions are legal. The state machine `pending → paid → fulfilled` (or `pending → cancelled`, `paid → refunded`) is enforced only in service code. Verify there's no way to insert `paid` directly via Supabase console. Consider a CHECK constraint or trigger.
- [ ] **`order_items.fulfillment_status`** — same issue. Enforce via trigger: `INSERT fulfillment_status='pending' only`.
- [ ] **`orders.payment_ref` UNIQUE?** — Currently no UNIQUE constraint. If the TriPay webhook fires twice (network retry), `markOrderPaid` will run twice. Add UNIQUE constraint or upsert.
- [ ] **`orders.total_amount` ≥ sum of items** — currently no CHECK. Possible to insert order with mismatched total. Add a trigger or computed column.
- [ ] **Negative quantities / negative prices** — CHECKs exist on `quantity > 0` and `price >= 0`. ✅
- [ ] **Voucher code uniqueness** — `voucher.code` UNIQUE? Check schema. Currently in service code (`generateUniqueVoucherCode`) but no DB constraint — race condition possible.
- [ ] **Voucher `status` enum** — what are valid values? `active`, `redeemed`, `expired`, `cancelled`?
- [ ] **Refund flow schema** — `orders.status` has `refunded` but no `refunds` table. How are partial refunds tracked? Is there a `commission_payouts` reversal?
- [ ] **RLS policies** — can a `student` query another student's order? Check `orders` RLS.
- [ ] **`payment_method` allowed values** — schema has `TEXT` for payment_method but no CHECK. Should be enum: `tripay`, `manual`, `voucher_credit`, etc.

**Tooling:**
```bash
# Find all CHECK constraints
grep -A 3 "CHECK" schema.sql | grep -B 1 "orders\|order_items\|vouchers"

# Find RLS policies on order tables
grep -A 6 "ALTER TABLE.*orders\|ALTER TABLE.*order_items\|ALTER TABLE.*vouchers" schema.sql

# Run \d orders against Supabase to see live schema
npx supabase db query --linked --command "SELECT column_name, data_type, is_nullable FROM information_schema.columns WHERE table_name IN ('orders','order_items','vouchers','pricing_config') AND table_schema='public' ORDER BY table_name, ordinal_position"
```

---

### Phase B — Service layer (3 hours)

**Goal:** Verify business logic correctness, race conditions, transaction safety.

**Files:** `worker/src/services/orders.ts`, `pricing.ts`, `voucher.ts`

**Checks per file:**

#### `services/orders.ts`

- [ ] **`createOrder` transaction safety** — order + order_items inserted in 2 separate calls. If order_items insert fails, you have an orphan order. **Wrap in a Postgres function or use a single RPC call.**
- [ ] **Idempotency** — what if `createOrder` is called twice with the same idempotency key? No idempotency layer exists. Consider adding `Idempotency-Key` header support (Stripe-style).
- [ ] **Race condition on total_amount** — prices computed at order time. If `pricing_config` changes between create and fulfill, what happens? Verify `unit_price` is a snapshot (✅ — `order_items.unit_price` captures it).
- [ ] **`fulfillOrder` voucher generation** — does it generate the correct number of vouchers? For `quantity > 1`, does it create `quantity` vouchers or 1 voucher with a quantity field?
- [ ] **`fulfillOrder` failure mode** — if voucher generation succeeds for 5 of 10 items, do we have a partial fulfillment state? Does it roll back? Does it retry? **Likely bug.**
- [ ] **`markOrderPaid` race** — if called twice (webhook retry), does it call `fulfillOrder` twice? **Check for idempotency.**
- [ ] **`cancelOrder` after paid?** — service should reject. Verify.
- [ ] **Order ownership check** — `getOrder(env, userId, orderId)` — does it filter by `user_id = userId`? Or just by `id = orderId`? **If by id only, students can read other students' orders.**

#### `services/pricing.ts`

- [ ] **Caching** — does `getPrice` cache, or hit DB every order? If no cache, pricing calls can pile up.
- [ ] **Missing pricing row** — what happens? Returns `null` and throws. Good. But does it log? Should.
- [ ] **Stale pricing** — if `pricing_config` is updated, are in-flight orders affected? They shouldn't be (unit_price is snapshotted). ✅

#### `services/voucher.ts`

- [ ] **`validateVoucher` expiration check** — does it check `valid_until`? Or only `status = 'active'`?
- [ ] **`redeemVoucher` atomicity** — voucher state goes `active → redeemed`. Race: two concurrent redemptions of the same code. **Must use UPDATE ... WHERE status='active' RETURNING.**
- [ ] **Voucher tied to order** — if order is refunded, should voucher be invalidated? No FK cascade or trigger exists.
- [ ] **Voucher code format** — 12 chars from `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`. Confusing alphabet (I, O, 0, 1 excluded — good). But uniqueness is checked by service, not DB.

**Tooling:**
```bash
# Check for race conditions (UPDATE without WHERE on state)
grep -A 5 "UPDATE.*vouchers\|UPDATE.*orders" worker/src/services/

# Check for transaction boundaries
grep -B 2 -A 10 "beginTransaction\|\.rpc(" worker/src/services/orders.ts
```

---

### Phase C — Routes layer (2 hours)

**Goal:** API correctness, auth, rate limiting, validation.

**Files:** `worker/src/routes/orders.ts`, `voucher.ts`, `webhook.ts`

**Checks:**

#### `routes/orders.ts`

- [ ] **Auth on all endpoints** — `orderRoutes.use('*', requireAuth())` — ✅ all routes auth-required.
- [ ] **🔴 C1: TriPay webhook signature verification** — the `/webhook/tripay` endpoint has `TODO` comment. Verify signature per TriPay docs: HMAC-SHA256 of body using `TRIPAY_PRIVATE_KEY`. Without this, the audit shows critical security gap.
- [ ] **🔴 C2: TriPay payment creation** — `/pay` handler returns a mock URL. Verify what it should do: call TriPay API `/merchant/pembayaran/daftar` to get a real payment URL, then save the `payment_ref` from TriPay to `orders.payment_ref`.
- [ ] **Idempotency on `/pay`** — what if user double-clicks? Will two TriPay transactions be created? **Need idempotency.**
- [ ] **Order ownership on `/pay`** — `/pay` calls `getOrder(env, user.id, orderId)`. Verify this filters by user (see Phase B).
- [ ] **Input validation** — `payment_method` is freeform string. Validate against enum.
- [ ] **Rate limiting** — `orderRoutes.use('*', requireAuth())` — no `rateLimit()`. **Add `rateLimit('orders-create')` at 5/min to prevent spam.**
- [ ] **Error messages** — do error messages leak internal state (e.g., DB error details)? Should be opaque.
- [ ] **Webhook endpoint is auth-less** — `/webhook/tripay` has no auth. **This is correct for webhooks**, but signature verification is the gate.

#### `routes/voucher.ts`

- [ ] **Auth on validation** — `validateVoucher` is presumably public (student enters code). Verify.
- [ ] **Rate limit on redemption** — prevents brute-forcing valid codes.
- [ ] **Voucher validation response** — does it leak whether a code exists vs is expired? Should say "invalid" for both.

#### `routes/webhook.ts`

- [ ] **Auth on webhook handlers** — uses `webhookAuth(platform)` middleware. Verify signature scheme.
- [ ] **Idempotency** — webhook handlers can be retried by upstream. Should be idempotent (use INSERT ... ON CONFLICT or check before insert).
- [ ] **Order of operations** — webhook updates DB → triggers side effect (e.g., send email). If side effect fails, webhook retries → duplicate side effect. **Need outbox pattern or idempotency tokens.**

**Tooling:**
```bash
# Test all order endpoints (use your prod URL)
curl -X POST https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api/orders \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"order_type":"self_purchase","items":[{"item_type":"mock_ielts","quantity":1}]}'

# Try forging a webhook (should be REJECTED with sig)
curl -X POST https://osee-prep-hub-worker.edubot-leonardus.workers.dev/api/orders/webhook/tripay \
  -d '{"merchant_ref":"tripay-fake-id","status":"paid"}'
# Expected: 401 or signature error
# Actual: ??? — verify
```

---

### Phase D — External integrations (2 hours)

**Goal:** Verify TriPay and OSEE booking bridges are correctly wired.

**Sub-checks:**

#### TriPay

- [ ] **Secrets present?** — `TRIPAY_API_KEY`, `TRIPAY_PRIVATE_KEY`, `TRIPAY_MERCHANT_CODE`. Check via `wrangler secret list`.
- [ ] **Real API call exists?** — search for TriPay API endpoints in code. Expected: `/merchant/pembayaran/daftar` (create transaction), `/merchant/transaction/detail` (check status).
- [ ] **Sandbox vs production?** — confirm we're using production keys, not sandbox. Get merchant info from TriPay dashboard.
- [ ] **Payment method enum** — TriPay supports VA (Virtual Account), e-wallet, convenience store. Our schema has freeform `payment_method`. **Need enum mapping.**
- [ ] **Currency** — schema uses INTEGER (rupiah). TriPay expects IDR. ✅
- [ ] **Fee handling** — TriPay charges merchant fee. Does our total_amount include fees, or pass them to buyer?

#### OSEE Booking API

- [ ] **Secret present?** — `OSEE_BOOKING_API_URL`, `OSEE_BOOKING_API_SECRET`.
- [ ] **Used where?** — only in `book_for_student` order type? Or for all official_toefl / official_toeic items?
- [ ] **Error handling** — if booking API fails, does order roll back?
- [ ] **Retry logic** — booking API is external, can fail. Need retries.

#### EduBot bridge

- [ ] **Used for voucher distribution?** — when `fulfillOrder` runs for a voucher_resale order, does it push to EduBot's voucher system? Check `EDUBOT_API_URL` usage.

---

### Phase E — Frontend (1 hour)

**Goal:** Verify Flutter surfaces correctly call the API and display state.

**File:** `flutter/lib/features/student/pages/order_page.dart`, `teacher_dashboard_page.dart`

**Checks:**

- [ ] **Does order_page.dart actually call the API?** — search for `dio.post('/orders'`, `ApiClient.create()`. If it's mock data, **flag as critical gap**.
- [ ] **Does it show order status?** — `pending`, `paid`, `fulfilled` — find UI representation.
- [ ] **Payment button** — does it call `/api/orders/:id/pay` and redirect to the returned URL?
- [ ] **Error handling** — what happens if payment fails? Network error? Invalid voucher?
- [ ] **Voucher display** — does the user see their voucher codes after payment?
- [ ] **Teacher dashboard order view** — teachers should see orders for their classrooms.

**Tooling:**
```bash
grep -n "ApiClient\|/api/orders\|/api/voucher\|orderRoutes\|pay" flutter/lib/features/student/pages/order_page.dart
grep -n "ApiClient\|/api/orders" flutter/lib/features/teacher/pages/teacher_dashboard_page.dart
```

---

### Phase F — Operational checks (30 min)

- [ ] **Cloudflare Worker logs** — `wrangler tail --name osee-prep-hub-worker` — look for `order` / `tripay` / `payment_failed` events. Any recent errors?
- [ ] **Cron triggers** — `worker/wrangler.toml` had `[triggers] crons = ["*/1 * * * *"]` but we removed them. The cron handler in `index.ts` may still try to call a removed function. Check `index.ts` for `scheduled` export.
- [ ] **Stripe-style webhook signature rotation** — does TriPay support signature key rotation? If we ever rotate, webhooks break silently.
- [ ] **Backup / restore** — is there a backup of the orders table? Supabase has point-in-time recovery on paid tier.

---

### Phase G — Security audit (1 hour)

| Threat | Mitigation in code | Test |
|---|---|---|
| **Webhook forgery** | None — C1 | `curl -X POST .../webhook/tripay -d '{"merchant_ref":"x","status":"paid"}'` — should be 401 |
| **IDOR on orders** | `getOrder(userId, orderId)` filters by user | `curl -H "Bearer $TOKEN_A" .../api/orders/<order-id-of-user-B>` — should be 404 |
| **SQL injection** | Supabase uses parameterized queries | Static check: any `rpc('${'` or `.from('${'` patterns? |
| **Race: double-fulfill** | None | Concurrent `markOrderPaid` calls — what state? |
| **Race: double-redeem voucher** | Possibly | `redeemVoucher` concurrent test |
| **Price manipulation** | `unit_price` snapshotted | Confirm — `pricing_config` change doesn't affect in-flight orders |
| **Privilege escalation** | `requireRole('admin')` on admin routes | Verify teacher can't access `/api/admin/...` |
| **PII in logs** | `logger.ts` scrubs | Check `orderRoutes` — does it log full addresses or card numbers? |

---

### Phase H — Performance (30 min)

- [ ] **Order creation latency** — should be < 500ms p95. Add `console.time` to createOrder.
- [ ] **Webhook handling latency** — TriPay expects 2xx within 5s. Check.
- [ ] **DB indexes** — `idx_orders_user`, `idx_orders_status`, `idx_order_items_order`, `idx_order_items_assigned` — present?
- [ ] **Connection pooling** — Supabase pooler is enabled? Should be.
- [ ] **TriPay rate limits** — TriPay has per-merchant rate limits. Document.

---

## 3. Audit execution order

Do the phases in this order. **Do not skip Phase A** because the others depend on it.

| Day | Hours | Phase | Owner |
|---|---|---|---|
| **Day 1 morning** | 1h | **C1 fix first** (TriPay signature) — security blocker | Backend |
| Day 1 morning | 2h | Phase A (Schema) | DB reviewer |
| Day 1 afternoon | 3h | Phase B (Services) | Backend |
| Day 1 afternoon | 2h | Phase C (Routes) + **C2, C3 fixes** | Backend |
| **Day 2 morning** | 2h | Phase D (External integrations) | Backend + EduBot team |
| Day 2 morning | 1h | Phase E (Frontend) | Frontend |
| Day 2 afternoon | 1h | Phase F (Ops) | SRE |
| Day 2 afternoon | 1h | Phase G (Security) | Security |
| Day 2 afternoon | 30m | Phase H (Performance) | Backend |
| **Day 3 morning** | 4h | Remediation sprints | Whoever owns each issue |

---

## 4. Remediation backlog (post-audit)

After the audit, file issues in GitHub labeled `audit:order-flow`:

| Priority | Title | Estimate |
|---|---|---|
| 🔴 P0 | **Add TriPay webhook signature verification** (HMAC-SHA256) | 4h |
| 🔴 P0 | **Wire real TriPay API call** in `/pay` endpoint | 4h |
| 🔴 P0 | **Idempotency on order create + payment + webhook** (Stripe-Idempotency-Key header + DB UNIQUE constraint on idempotency_key) | 8h |
| 🟡 P1 | **Order create transaction safety** — wrap in Postgres function or single RPC | 4h |
| 🟡 P1 | **Add rate limiting** on order endpoints (5/min) | 1h |
| 🟡 P1 | **Add refund table** for partial refunds | 4h |
| 🟡 P1 | **Voucher code UNIQUE constraint** at DB level | 1h |
| 🟡 P1 | **Order state machine CHECK trigger** (pending → paid → fulfilled, can't skip states) | 4h |
| 🟢 P2 | **Frontend order_page.dart** — verify it calls real API, not mock | 1h |
| 🟢 P2 | **`payment_method` enum** | 1h |
| 🟢 P2 | **Voucher invalidation on order refund** (trigger or FK) | 2h |
| 🟢 P2 | **Outbox pattern** for webhook side effects (email, EduBot sync) | 8h |

**Total estimated remediation:** ~40 hours (1 week for 1 engineer)

---

## 5. Test plan (run alongside audit)

These tests should be written as part of the audit so they can be regression-tested:

```typescript
// tests/services/orders.test.ts
test('createOrder is atomic — order_items insert failure rolls back order');
test('markOrderPaid is idempotent — calling twice doesn't double-fulfill');
test('cancelOrder after paid throws');
test('voucher code generation produces unique codes under load');

// tests/integration/webhook.test.ts
test('TriPay webhook without signature → 401');
test('TriPay webhook with valid signature → order marked paid');
test('TriPay webhook with replay attack → 401');
test('TriPay webhook with bad merchant_ref → 400');

// tests/routes/orders.test.ts
test('GET /api/orders/:id returns 404 for other users order');
test('POST /api/orders rate-limited at 5/min');
```

---

## 6. Definition of Done

The audit is complete when:
- [ ] All 8 phases (A-H) have a written report in `.sisyphus/audit-orders-{phase}.md`
- [ ] Each finding has a severity (P0/P1/P2) and a remediation ticket
- [ ] C1, C2, C3 are fixed (or have an explicit decision to defer with rationale)
- [ ] The test suite covers the items in section 5
- [ ] The remediation backlog in section 4 is triaged and assigned

---

## 7. Open questions for you

Before I start the audit, please confirm:

1. **Should I fix C1 (TriPay signature) before or during the audit?** — Recommended: before, since it's a security blocker.
2. **Do you have a TriPay sandbox account** to test against? If not, I'll use mock signatures.
3. **Is there a separate EduBot person** I should coordinate with for the EduBot voucher bridge questions?
4. **Should the audit report be public** (in `docs/`) or internal (in `.sisyphus/`)?
5. **What's the budget** — full 2-3 day plan, or just Phase A + security check (1 day)?

Let me know how you'd like to proceed.