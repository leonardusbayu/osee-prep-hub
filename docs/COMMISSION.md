# Commission System — OSEE Prep Hub

## Overview

Teachers earn commission when their referred students take real actions on OSEE platforms.

## Commission rates (default, configurable via `/admin/commission-rates`)

| Action | Rate (IDR) | Trigger |
|---|---|---|
| `first_test` | 10,000 | Student completes first practice test |
| `official_booking` | 50,000 | Student books official test at osee.co.id |
| `premium_monthly` | 15,000 | Student subscribes to EduBot premium (recurring monthly) |
| `practice_package` | 25,000 | Student purchases practice package |

## Ambassador 2x rates

| Action | Rate (IDR) |
|---|---|
| `ambassador_first_test` | 20,000 |
| `ambassador_booking` | 100,000 |
| `ambassador_premium_monthly` | 30,000 |

Ambassadors also get unlimited AI quota + free Pro tier for life (auto-set via `/admin/ambassadors/promote`).

## Flow

```
Student completes test on ibt.osee.co.id
  → ibt sends webhook: POST /api/webhook/ibt
  → Hub stores in webhook_events
  → Cron (scheduled handler) processes batch:
    1. Update student_progress_unified
    2. Find referred_by teacher in unified_profiles
    3. Record commission in commission_ledger (idempotent via SELECT existing)
    4. Award quota bonus to teacher (+5 generation credits)
    5. Notify EduBot of progress
    6. Check readiness → if ready, Telegram DM student
```

## Schema

```sql
CREATE TABLE commission_ledger (
  id UUID PRIMARY KEY,
  teacher_id UUID,         -- who earns
  student_id UUID,         -- whose action triggered
  action TEXT,              -- 'first_test' | 'official_booking' | 'premium_monthly' | 'practice_package'
  amount_idr DECIMAL,      -- amount in IDR
  status TEXT,             -- 'pending' | 'confirmed' | 'paid' | 'clawback'
  reference_id TEXT,       -- platform / booking reference
  notes TEXT,
  created_at, confirmed_at, paid_at
);

CREATE TABLE commission_payouts (
  id UUID PRIMARY KEY,
  teacher_id UUID,
  amount DECIMAL,
  method TEXT,             -- 'bank_transfer' | 'gopay' | 'ovo' | 'dana'
  status TEXT,             -- 'pending' | 'processing' | 'paid' | 'rejected' | 'cancelled'
  requested_at, processed_at, paid_at
);
```

## API

- `GET /api/teacher/commission/dashboard` — total_earned, this_month, pending, paid, by_type, recent_entries
- `GET /api/teacher/commission/payouts` — payout history
- `POST /api/teacher/commission/payout` — request payout (body: amount, method)
- `GET /api/admin/commission` — cross-teacher summary (admin)
- `GET/POST /api/admin/commission-rates` — list/update rates (admin)

## Quota bonus (Task 12.4)

Teachers earn extra AI generation credits when their students take actions:

| Event | Bonus |
|---|---|
| `student_registered` | +5 generation credits |
| `test_completed` | +5 generation credits |
| `official_booking` | +10 generation credits |
| `premium_subscribed` | +10 generation credits |

Example: 20 students who all register + complete a test = 10 (base) + 20×5 + 20×5 = 210 generation credits/month.