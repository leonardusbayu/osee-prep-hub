# Ambassador Program — OSEE Prep Hub

## Overview

20 founding teachers recruited manually. Enhanced commission + unlimited AI + free Pro tier for life + featured status.

## Benefits (Appendix B)

- ✓ Unlimited AI grading + generation (no quota — `quota.ts` checks `is_ambassador`)
- ✓ 2x commission rate (Rp 20k per first test, Rp 100k per booking, Rp 30k/month premium)
- ✓ "OSEE Certified Educator" badge on profile + reports
- ✓ Featured on OSEE social media + website
- ✓ Early access to new features
- ✓ Free Pro tier for life (auto-set `tier='pro'`, `tier_expires_at=NULL`)

## Obligations

- Use platform with their students (real usage)
- Post about it on Instagram/TikTok at least 1x/month
- Recruit 5 other teachers in first 3 months
- Provide weekly feedback

## Recruitment target

English teachers with 100+ students, active on social media.
Channels: Instagram (#gurubahasainggris, #lestofl, #persiapanielts), Facebook groups, TikTok, EduBot channel.

## API

- `GET /api/ambassador/dashboard` — stats: is_ambassador, recruited_teachers, total_bonus_earned, this_month_bonus
- `GET /api/ambassador/proposal` — printable HTML teacher proposal document (Appendix C template)
- `GET /api/admin/ambassadors` — list ambassadors with recruited_count (admin)
- `POST /api/admin/ambassadors/promote` — promote teacher to ambassador (auto-set Pro for life)

## Schema

```sql
-- teacher_profiles fields
is_ambassador BOOLEAN DEFAULT FALSE,
ambassador_recruited_at TIMESTAMPTZ,
ambassador_recruited_by UUID REFERENCES unified_profiles(id),

-- commission_rates seeds
('ambassador_first_test', 20000, ...),
('ambassador_booking', 100000, ...),
('ambassador_premium_monthly', 30000, ...);
```

## Flutter pages

- `/ambassador` — ambassador dashboard (stats + generate proposal button)
- `/ambassador/join` — public recruitment page (no auth required)

## Teacher Proposal Document

Generated via `services/ambassador.ts:generateProposalHtml()` — renders Appendix C template as printable HTML with ambassador's referral code personalized. Open in browser → File → Print → Save as PDF.