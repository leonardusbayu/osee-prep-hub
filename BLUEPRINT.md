# OSEE Education Hub — Complete Build Blueprint
## prep.osee.co.id — AI Teaching Assistant for English Teachers in Indonesia

> **For OpenCode / Claude Code:** Implement this plan phase-by-phase. Each phase is independently deployable. Do not skip phases. Commit after every task.

---

## TABLE OF CONTENTS

1. [Executive Summary](#1-executive-summary)
2. [Existing Assets](#2-existing-assets)
3. [System Architecture](#3-system-architecture)
4. [Database Schema](#4-database-schema)
5. [API Specification](#5-api-specification)
6. [Frontend Architecture](#6-frontend-architecture)
7. [RAG Knowledge Base](#7-rag-knowledge-base)
8. [AI Engine Specification](#8-ai-engine-specification)
9. [Commission System](#9-commission-system)
10. [Video Content System](#10-video-content-system)
11. [Live Class Integration](#11-live-class-integration)
12. [Build Phases](#12-build-phases)
13. [Folder Structure](#13-folder-structure)
14. [Environment Variables](#14-environment-variables)
15. [Deployment](#15-deployment)

---

## 1. EXECUTIVE SUMMARY

### What we're building

A unified education platform (`prep.osee.co.id`) that connects all existing OSEE assets into one ecosystem. The platform serves as an **AI Teaching Assistant** for English teachers in Indonesia — free for teachers, with commission on student actions.

### The viral loop

```
Teacher signs up (free)
  → Gets AI tools (writing grader, material generator, reports)
  → Invites students via referral code
  → Students register → see OSEE branding → discover practice platforms
  → Students practice on ibt/test/ielts/toeic.osee.co.id
  → Students book official tests at osee.co.id
  → Teacher earns commission
  → Teacher invites MORE students
  → Loop repeats
```

### Revenue model

```
Teacher subscription:
  Free: 50 AI grading credits/month, 10 generation credits/month
  Pro (Rp 50k/month): Unlimited grading + generation + classroom reports
  Institution (Rp 200k-500k/month): White-label + multi-teacher + admin dashboard

Student subscription (via EduBot):
  Free: 10 questions/day
  Premium (Rp 30-99k/month): Unlimited practice + AI speaking/writing + video courses

Commission (the real revenue driver):
  Rp 10k per student who completes first practice test
  Rp 50k per student who books official test at osee.co.id
  Rp 15k/month per student on EduBot premium (recurring)

OSEE test booking revenue:
  Every official test booked through the platform → OSEE earns full test fee
```

### Tech stack

```
Frontend:  Flutter Web (existing spec) OR React/Vite (aligns with EduBot)
Backend:   Cloudflare Workers + Hono (TypeScript) — extends EduBot
Database:  Cloudflare D1 (existing EduBot) + Supabase PostgreSQL (new hub tables)
AI:        OpenAI GPT-4o-mini + Whisper + TTS (existing EduBot)
Storage:   Cloudflare R2 (audio + video + documents)
Auth:      JWT (shared across *.osee.co.id via cookie)
Hosting:   Cloudflare Pages (frontend) + Cloudflare Workers (API)
```

### Why Cloudflare + Supabase dual backend

```
EduBot (existing): Cloudflare Workers + D1 (SQLite at edge)
  → Keep as-is. Already running. 103 tables. 149 commits.

Hub (new): Cloudflare Workers + Supabase PostgreSQL
  → Supabase for: RLS (Row-Level Security), real-time subscriptions,
    PostgreSQL views, JSONB columns, full-text search
  → Cloudflare Workers for: API layer, AI calls, webhooks, cross-platform orchestration

Bridge: Hub Workers call EduBot Workers via internal API
        Practice platforms send webhooks to Hub Workers
```

---

## 2. EXISTING ASSETS

### What's already built and running

| Asset | URL | Stack | Status |
|---|---|---|---|
| OSEE main site | osee.co.id | WordPress/custom | Live since 2014, ETS-certified test center |
| TOEFL iBT practice | ibt.osee.co.id | Custom web app | Live, Rp 250k/session |
| TOEFL ITP practice | test.osee.co.id | Custom web app | Live, 120+ simulation packages |
| IELTS practice | ielts.osee.co.id | Custom web app | Live, all 4 sections, AI scoring |
| TOEIC practice | toeic.osee.co.id | Custom web app | Live, 200 questions, analytics |
| EduBot (Telegram AI tutor) | github.com/leonardusbayu/osee-edubot | Cloudflare Workers + React/Vite + D1 | 149 commits, 103 tables, active |

### EduBot existing services to reuse

```
ALREADY BUILT (do not rebuild):
  ✓ AI writing evaluation (routes/writing.ts)
  ✓ AI speaking evaluation with Whisper (routes/speaking.ts)
  ✓ AI content generation (routes/ai-generate.ts, services/contentGenerator.ts)
  ✓ Content validation (services/content-validator.ts, content-auditor.ts)
  ✓ Student reports (services/student-report.ts)
  ✓ Diagnostic tests (services/diagnostic.ts)
  ✓ Study plans (services/studyplan.ts)
  ✓ Syllabus content (services/syllabus.ts)
  ✓ Video lessons (services/video-lessons.ts)
  ✓ Gamification (services/gamification.ts, coins.ts, leagues.ts)
  ✓ Spaced repetition FSRS (services/fsrs-engine.ts)
  ✓ Weakness analysis (services/weakness-analysis.ts)
  ✓ Referral commission (services/referral-commission.ts)
  ✓ Classroom management (services/classroom.ts, routes/classes.ts)
  ✓ Payment (routes/payment.ts, services/tripay.ts)
  ✓ Reseller dashboard (frontend/src/pages/ResellerDashboard.tsx)
  ✓ Teacher dashboard (frontend/src/pages/TeacherDashboard.tsx)
  ✓ Student report generator (frontend/src/pages/StudentReportGenerator.tsx)
  ✓ Weakness dashboard (frontend/src/pages/WeaknessDashboard.tsx)
  ✓ Admin panel (frontend/src/pages/AdminPanel.tsx)
  ✓ Score predictor (services/score-predictor.ts)
  ✓ Band lookup (services/band-lookup.ts)
  ✓ Indonesian analogies (services/indonesian-analogies.ts)
  ✓ Pronunciation/prosody (services/prosody.ts)
  ✓ Chat analysis (services/chat-analysis.ts)
  ✓ Companion AI (services/companion.ts, companion-nudge.ts)
  ✓ Mental model (services/mental-model.ts)
  ✓ Socratic engine (services/socratic-engine.ts)
  ✓ Scholarship track (services/scholarship-track.ts)
  ✓ Boss battles (services/boss-battles.ts)
  ✓ Study buddies (services/study-buddies.ts)
  ✓ Squads (services/squads.ts)
  ✓ Seasonal events (services/seasonal-events.ts)
```

### What's NOT built (this blueprint covers these)

```
NEW (build in this order):
  1. Hub API + database (Supabase PostgreSQL)
  2. Unified SSO across all *.osee.co.id platforms
  3. Teacher portal (registration, classroom, referral codes)
  4. RAG knowledge base (vector embeddings of English teaching materials)
  5. AI writing grader (extends EduBot's existing writing evaluation)
  6. AI material generator (extends EduBot's contentGenerator with RAG)
  7. Student report system (extends EduBot's student-report for teacher view)
  8. Classroom report system (NEW — aggregates student data for teachers)
  9. Commission tracking (extends EduBot's referral-commission)
  10. Syllabus builder (drag-and-drop, extends EduBot's syllabus service)
  11. Student portal (assignments, progress, deep links to practice platforms)
  12. Live class integration (Zoom link sharing via Tutor Bot)
  13. Video content system (extends EduBot's video-lessons)
  14. Webhook receivers (from all practice platforms)
  15. White-label system (custom branding for Pro/Institution tier)
```

---

## 3. SYSTEM ARCHITECTURE

### High-level diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                     OSEE EDUCATION ECOSYSTEM                       │
│                                                                    │
│  ┌─────────────────────────────────────────────────────────────┐  │
│  │  CONTENT LAYER                                                 │  │
│  │                                                                  │  │
│  │  OSEE Video Library          Live Zoom Classes                  │  │
│  │  (AI-assisted,               (osee.co.id schedule)               │  │
│  │   reusable assets)                  │                            │  │
│  │       │                              │                            │  │
│  │       ▼                              ▼                            │  │
│  │  ┌─────────────────────────────────────────┐                   │  │
│  │  │  EDUBOT (Telegram AI Tutor)               │                   │  │
│  │  │  Cloudflare Workers + Hono + D1           │                   │  │
│  │  │  • AI chat tutor (GPT-4o-mini)            │                   │  │
│  │  │  • Speaking eval (Whisper + GPT)          │                   │  │
│  │  │  • Writing eval (GPT + rubrics)           │                   │  │
│  │  │  • Content generation + validation         │                   │  │
│  │  │  • Gamification (XP, coins, leagues)       │                   │  │
│  │  │  • FSRS spaced repetition                  │                   │  │
│  │  │  • Diagnostic + study plans                │                   │  │
│  │  │  • Weakness analysis                       │                   │  │
│  │  │  • Video lessons + comprehension           │                   │  │
│  │  │  • Classroom + challenges                  │                   │  │
│  │  │  • Referral commission engine              │                   │  │
│  │  │  • Payment (TriPay)                        │                   │  │
│  │  │  • Companion AI + mental model             │                   │  │
│  │  │  • Channel content + cron                   │                   │  │
│  │  └──────────────────┬──────────────────────────┘                   │  │
│  └─────────────────────────┼─────────────────────────────────────────┘  │
│                              │                                          │
│  ┌──────────────────────────▼─────────────────────────────────────────┐  │
│  │  HUB API (NEW — prep.osee.co.id)                                     │  │
│  │  Cloudflare Workers + Hono + Supabase                                │  │
│  │                                                                       │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────────┐  │  │
│  │  │ Auth/SSO   │ │ Teacher    │ │ Student    │ │ Webhook         │  │  │
│  │  │ (JWT +     │ │ API        │ │ API        │ │ Receivers       │  │  │
│  │  │  cookies)  │ │            │ │            │ │                 │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └─────────────────┘  │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────────┐  │  │
│  │  │ RAG        │ │ AI Grading │ │ AI Gen     │ │ Commission      │  │  │
│  │  │ Knowledge  │ │ API        │ │ API        │ │ Engine          │  │  │
│  │  │ Base       │ │            │ │            │ │                 │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └─────────────────┘  │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌─────────────────┐  │  │
│  │  │ Report     │ │ Video      │ │ Live Class │ │ White-Label     │  │  │
│  │  │ Generator  │ │ Content    │ │ Scheduler  │ │ System          │  │  │
│  │  └────────────┘ └────────────┘ └────────────┘ └─────────────────┘  │  │
│  └──────────────────────────┬─────────────────────────────────────────┘  │
│                              │                                          │
│  ┌──────────────────────────▼─────────────────────────────────────────┐  │
│  │  DATABASE LAYER                                                       │  │
│  │  ┌──────────────────┐  ┌───────────────────────────────────────┐   │  │
│  │  │ EduBot D1 (SQLite)│  │ Hub Supabase (PostgreSQL)             │   │  │
│  │  │ 103 tables         │  │ New tables for:                       │   │  │
│  │  │ (existing —        │  │ • unified_profiles                     │   │  │
│  │  │  read-only bridge) │  │ • teacher_profiles                     │   │  │
│  │  │                    │  │ • classrooms                           │   │  │
│  │  │                    │  │ • syllabi + syllabus_items             │   │  │
│  │  │                    │  │ • teacher_referrals                    │   │  │
│  │  │                    │  │ • commission_ledger                    │   │  │
│  │  │                    │  │ • ai_grading_queue                     │   │  │
│  │  │                    │  │ • ai_generation_queue                  │   │  │
│  │  │                    │  │ • knowledge_base_documents             │   │  │
│  │  │                    │  │ • knowledge_base_embeddings            │   │  │
│  │  │                    │  │ • video_courses + video_lessons        │   │  │
│  │  │                    │  │ • live_classes                         │   │  │
│  │  │                    │  │ • student_progress_unified             │   │  │
│  │  │                    │  │ • cross_exam_score_map                 │   │  │
│  │  │                    │  │ • webhook_events                       │   │  │
│  │  │                    │  │ • teacher_subscriptions                │   │  │
│  │  │                    │  │ • branding_configs                     │   │  │
│  │  │                    │  │ • ai_quota_usage                       │   │  │
│  │  │                    │  │ • platform_links                       │   │  │
│  │  │                    │  └───────────────────────────────────────┘   │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  PRACTICE PLATFORMS (existing — send webhooks to Hub)                │  │
│  │  • ibt.osee.co.id    → POST prep.osee.co.id/api/webhook/ibt          │  │
│  │  • test.osee.co.id   → POST prep.osee.co.id/api/webhook/itp          │  │
│  │  • ielts.osee.co.id  → POST prep.osee.co.id/api/webhook/ielts        │  │
│  │  • toeic.osee.co.id  → POST prep.osee.co.id/api/webhook/toeic        │  │
│  │  • osee.co.id        → POST prep.osee.co.id/api/webhook/booking      │  │
│  │  • EduBot            → POST prep.osee.co.id/api/webhook/edubot       │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  BOOKING LAYER                                                        │  │
│  │  osee.co.id (Official ETS test booking)                               │  │
│  │  Commission flows: practice platform → Hub → teacher wallet           │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
```

### Auth flow (SSO across all subdomains)

```
1. User logs in at prep.osee.co.id
   → Hub validates credentials against Supabase auth
   → Hub issues JWT: { user_id, email, role, exp }
   → Hub sets HttpOnly cookie: osee_token=<JWT>
     Domain: .osee.co.id (shared across all subdomains)
     Secure: true, HttpOnly: true, SameSite: Lax

2. User visits ibt.osee.co.id
   → Browser sends osee_token cookie automatically
   → ibt.osee.co.id validates JWT via:
     Option A: Shared JWT secret (fastest — all platforms same secret)
     Option B: Call prep.osee.co.id/api/auth/verify (centralized)
   → User is authenticated, no second login

3. User visits EduBot (Telegram)
   → Telegram initData → EduBot auth (existing)
   → EduBot calls Hub: POST /api/auth/link-telegram
     { telegram_id, osee_token }
   → Hub links telegram_id to unified_profile
   → EduBot can now read student's progress from Hub API
```

### Webhook flow (practice platforms → Hub)

```
Student completes test on ibt.osee.co.id
  → ibt.osee.co.id sends webhook:
    POST prep.osee.co.id/api/webhook/ibt
    Headers: X-Webhook-Secret: <shared_secret>
    Body: {
      "event": "test_completed",
      "user_email": "ahmad@gmail.com",
      "platform": "ibt",
      "exam_type": "TOEFL_IBT",
      "score": 87,
      "section_scores": {
        "reading": 22,
        "listening": 23,
        "speaking": 20,
        "writing": 22
      },
      "material_id": "set_42",
      "duration_minutes": 120,
      "timestamp": "2026-07-05T12:00:00Z"
    }

  → Hub processes webhook:
    1. Find unified_profile by email
    2. Store event in webhook_events table
    3. Update student_progress_unified
    4. Check: does this student have a teacher referral?
    5. If yes + first test completed → credit Rp 10k commission
    6. Notify EduBot: student progress updated (for AI tutor context)
    7. If score >= target → trigger "ready to book" notification
```

---

## 4. DATABASE SCHEMA

### Supabase PostgreSQL — Hub Database

```sql
-- ============================================================
-- OSEE EDUCATION HUB — DATABASE SCHEMA
-- Platform: Supabase PostgreSQL
-- ============================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector"; -- for pgvector embeddings
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for fuzzy text search

-- ============================================================
-- 1. UNIFIED PROFILES (links all platforms)
-- ============================================================

CREATE TABLE unified_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin', 'institution')),
  avatar_url TEXT,

  -- Cross-platform linking
  telegram_id TEXT,          -- links to EduBot
  edubot_user_id INTEGER,    -- EduBot D1 user.id
  osee_customer_id TEXT,     -- osee.co.id customer ID (if exists)

  -- Student-specific
  target_exam TEXT CHECK (target_exam IN ('TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL')),
  target_score JSONB,        -- {"overall": 100} or {"overall": 6.5, "reading": 7, ...}
  current_level TEXT,        -- CEFR level: A1, A2, B1, B2, C1, C2
  diagnostic_completed_at TIMESTAMPTZ,

  -- Teacher-specific
  teacher_bio TEXT,
  teacher_institution TEXT,
  teacher_subjects TEXT[],   -- ['TOEFL_IBT', 'IELTS', 'general_english']
  teacher_verified BOOLEAN DEFAULT FALSE,

  -- Metadata
  preferred_language TEXT DEFAULT 'id', -- 'id' = Indonesian, 'en' = English
  timezone TEXT DEFAULT 'Asia/Jakarta',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

CREATE INDEX idx_profiles_email ON unified_profiles(email);
CREATE INDEX idx_profiles_telegram ON unified_profiles(telegram_id);
CREATE INDEX idx_profiles_role ON unified_profiles(role);

-- ============================================================
-- 2. TEACHER PROFILES (extends unified_profiles)
-- ============================================================

CREATE TABLE teacher_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  referral_code TEXT UNIQUE NOT NULL,  -- e.g., 'MRSARI240'
  referral_code_active BOOLEAN DEFAULT TRUE,

  -- Subscription tier
  tier TEXT DEFAULT 'free' CHECK (tier IN ('free', 'pro', 'institution')),
  tier_expires_at TIMESTAMPTZ,

  -- Branding (white-label)
  branding_config JSONB DEFAULT '{}',
  -- {
  --   "logo_url": null,           -- null = use OSEE branding
  --   "primary_color": "#CCFF00",
  --   "custom_subdomain": null,    -- e.g., "englishprep.sma1jakarta.sch.id"
  --   "hide_osee_branding": false
  -- }

  -- Stats (denormalized for dashboard performance)
  total_students INTEGER DEFAULT 0,
  total_classrooms INTEGER DEFAULT 0,
  total_earnings_idr DECIMAL DEFAULT 0,
  monthly_recurring_idr DECIMAL DEFAULT 0,

  -- Ambassador program
  is_ambassador BOOLEAN DEFAULT FALSE,
  ambassador_recruited_at TIMESTAMPTZ,
  ambassador_recruited_by UUID REFERENCES unified_profiles(id),

  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_teacher_code ON teacher_profiles(referral_code);
CREATE INDEX idx_teacher_user ON teacher_profiles(user_id);

-- ============================================================
-- 3. CLASSROOMS
-- ============================================================

CREATE TABLE classrooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  target_exam TEXT CHECK (target_exam IN ('TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL')),
  join_code TEXT UNIQUE NOT NULL,  -- students use this to join
  join_code_active BOOLEAN DEFAULT TRUE,
  is_active BOOLEAN DEFAULT TRUE,
  max_students INTEGER DEFAULT 50,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE classroom_enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  classroom_id UUID NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ DEFAULT NOW(),
  enrolled_via TEXT,  -- 'referral_code', 'join_code', 'invite_link'
  referral_code_used TEXT,  -- teacher's referral code
  is_active BOOLEAN DEFAULT TRUE,
  UNIQUE(classroom_id, student_id)
);

CREATE INDEX idx_enrollment_class ON classroom_enrollments(classroom_id);
CREATE INDEX idx_enrollment_student ON classroom_enrollments(student_id);

-- ============================================================
-- 4. SYLLABI + SYLLABUS ITEMS
-- ============================================================

CREATE TABLE syllabi (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  classroom_id UUID REFERENCES classrooms(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  description TEXT,
  target_exam TEXT CHECK (target_exam IN ('TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL')),
  target_score JSONB,
  is_template BOOLEAN DEFAULT FALSE,        -- templates can be shared/cloned
  is_published BOOLEAN DEFAULT FALSE,
  diagnostic_based BOOLEAN DEFAULT FALSE,   -- auto-generated from diagnostic?
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE syllabus_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_id UUID NOT NULL REFERENCES syllabi(id) ON DELETE CASCADE,
  sort_order INTEGER NOT NULL,

  -- Source: where does this item come from?
  source_type TEXT NOT NULL CHECK (source_type IN (
    'platform_ibt',      -- from ibt.osee.co.id
    'platform_itp',      -- from test.osee.co.id
    'platform_ielts',    -- from ielts.osee.co.id
    'platform_toeic',    -- from toeic.osee.co.id
    'edubot',            -- from EduBot (AI tutor exercises)
    'teacher_custom',    -- teacher's own uploaded material
    'ai_generated',      -- AI-generated material (RAG-powered)
    'video_lesson',      -- from OSEE video library
    'live_class'         -- scheduled live class
  )),
  source_material_id TEXT,    -- ID in source platform
  source_platform_url TEXT,   -- deep link to the material on the source platform

  -- Item metadata
  title TEXT NOT NULL,
  description TEXT,
  item_type TEXT CHECK (item_type IN (
    'reading', 'listening', 'speaking', 'writing',
    'grammar', 'vocabulary', 'mock_test', 'diagnostic',
    'video', 'live_class', 'assignment', 'review'
  )),
  section TEXT,             -- 'reading', 'listening', etc.
  difficulty TEXT,          -- 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'
  estimated_minutes INTEGER,

  -- Flavor profile (from brainstorm — cognitive pacing)
  flavor_tag TEXT CHECK (flavor_tag IN ('bitter', 'sweet', 'umami', 'spicy', 'cooling')),
  temperature_tag TEXT CHECK (temperature_tag IN ('hot', 'cold')),

  -- Unlock logic
  unlocked_at TIMESTAMPTZ,   -- null = locked
  prerequisite_item_id UUID REFERENCES syllabus_items(id),

  -- AI-generated content (if source_type = 'ai_generated')
  ai_generated_content JSONB,  -- full generated material stored here

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_syllabus_items_syllabus ON syllabus_items(syllabus_id);
CREATE INDEX idx_syllabus_items_order ON syllabus_items(syllabus_id, sort_order);

-- ============================================================
-- 5. REFERRAL + COMMISSION SYSTEM
-- ============================================================

CREATE TABLE teacher_referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  referral_code TEXT NOT NULL,
  classroom_id UUID REFERENCES classrooms(id),

  registered_at TIMESTAMPTZ DEFAULT NOW(),
  enrollment_source TEXT,  -- 'referral_link', 'join_code', 'manual'

  -- Commission triggers (only on real actions, not just registration)
  first_test_completed_at TIMESTAMPTZ,
  first_test_commission DECIMAL DEFAULT 0,

  official_test_booked_at TIMESTAMPTZ,
  booking_commission DECIMAL DEFAULT 0,
  booking_test_type TEXT,
  booking_amount_idr DECIMAL,

  premium_subscribed_at TIMESTAMPTZ,
  premium_commission_monthly DECIMAL DEFAULT 0,
  premium_commission_total DECIMAL DEFAULT 0,
  premium_active BOOLEAN DEFAULT FALSE,

  practice_package_purchased_at TIMESTAMPTZ,
  package_commission DECIMAL DEFAULT 0,

  total_earned DECIMAL DEFAULT 0,
  total_paid_out DECIMAL DEFAULT 0,
  last_payout_at TIMESTAMPTZ,

  UNIQUE(teacher_id, student_id)
);

CREATE INDEX idx_referral_teacher ON teacher_referrals(teacher_id);
CREATE INDEX idx_referral_student ON teacher_referrals(student_id);

-- Commission rates (configurable by admin)
CREATE TABLE commission_rates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  action TEXT NOT NULL UNIQUE CHECK (action IN (
    'first_test',
    'official_booking',
    'premium_monthly',
    'practice_package',
    'ambassador_first_test',
    'ambassador_booking',
    'ambassador_premium_monthly'
  )),
  rate_idr DECIMAL NOT NULL,
  description TEXT,
  active BOOLEAN DEFAULT TRUE,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default rates
INSERT INTO commission_rates (action, rate_idr, description) VALUES
  ('first_test', 10000, 'Student completes first practice test'),
  ('official_booking', 50000, 'Student books official test at osee.co.id'),
  ('premium_monthly', 15000, 'Student pays EduBot premium (recurring monthly)'),
  ('practice_package', 25000, 'Student purchases practice package'),
  ('ambassador_first_test', 20000, 'Ambassador: 2x rate for first test'),
  ('ambassador_booking', 100000, 'Ambassador: 2x rate for official booking'),
  ('ambassador_premium_monthly', 30000, 'Ambassador: 2x rate for premium');

-- Commission ledger (every transaction logged)
CREATE TABLE commission_ledger (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id),
  student_id UUID REFERENCES unified_profiles(id),
  action TEXT NOT NULL,
  amount_idr DECIMAL NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'paid', 'clawback')),
  reference_id TEXT,  -- payment/booking reference
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  confirmed_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ
);

CREATE INDEX idx_commission_teacher ON commission_ledger(teacher_id);
CREATE INDEX idx_commission_status ON commission_ledger(status);

-- ============================================================
-- 6. AI QUOTA SYSTEM
-- ============================================================

CREATE TABLE ai_quota_usage (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  quota_type TEXT NOT NULL CHECK (quota_type IN ('grading', 'generation', 'report')),
  used_count INTEGER DEFAULT 0,
  max_count INTEGER NOT NULL,  -- resets monthly
  period_start TIMESTAMPTZ DEFAULT NOW(),
  period_end TIMESTAMPTZ,
  earned_bonus INTEGER DEFAULT 0,  -- earned from student referrals
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Default quotas by tier
CREATE TABLE ai_quota_limits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tier TEXT NOT NULL CHECK (tier IN ('free', 'pro', 'institution')),
  quota_type TEXT NOT NULL CHECK (quota_type IN ('grading', 'generation', 'report')),
  monthly_limit INTEGER NOT NULL,
  UNIQUE(tier, quota_type)
);

INSERT INTO ai_quota_limits (tier, quota_type, monthly_limit) VALUES
  ('free', 'grading', 50),
  ('free', 'generation', 10),
  ('free', 'report', 10),
  ('pro', 'grading', 1000000),    -- effectively unlimited
  ('pro', 'generation', 1000000),
  ('pro', 'report', 1000000),
  ('institution', 'grading', 1000000),
  ('institution', 'generation', 1000000),
  ('institution', 'report', 1000000);

-- ============================================================
-- 7. KNOWLEDGE BASE (RAG)
-- ============================================================

CREATE TABLE knowledge_base_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  source TEXT NOT NULL,  -- 'grammar_reference', 'vocabulary_list', 'rubric',
                         -- 'question_template', 'error_pattern', 'cultural_context',
                         -- 'teacher_upload', 'video_transcript'
  source_author TEXT,
  source_publisher TEXT,
  source_url TEXT,
  source_license TEXT,   -- license info for legal compliance

  category TEXT NOT NULL,  -- 'grammar', 'vocabulary', 'pronunciation', 'rubrics',
                           -- 'question_templates', 'error_patterns', 'cultural', 'general'
  subcategory TEXT,
  cefr_level TEXT,         -- 'A1', 'A2', 'B1', 'B2', 'C1', 'C2', or null

  content TEXT NOT NULL,      -- full text content
  content_chunk_count INTEGER DEFAULT 0,  -- how many chunks were embedded

  metadata JSONB DEFAULT '{}',
  -- {
  --   "exam_types": ["TOEFL_IBT", "IELTS"],
  --   "topics": ["conditionals", "inference"],
  --   "indonesian_context": true,
  --   "is_public_domain": true
  -- }

  uploaded_by UUID REFERENCES unified_profiles(id),  -- null = admin uploaded
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_kb_category ON knowledge_base_documents(category);
CREATE INDEX idx_kb_cefr ON knowledge_base_documents(cefr_level);

-- Vector embeddings (pgvector)
CREATE TABLE knowledge_base_embeddings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  document_id UUID NOT NULL REFERENCES knowledge_base_documents(id) ON DELETE CASCADE,
  chunk_index INTEGER NOT NULL,
  chunk_text TEXT NOT NULL,
  embedding VECTOR(1536),  -- OpenAI text-embedding-3-small dimension
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_kb_embedding_vector ON knowledge_base_embeddings
  USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- ============================================================
-- 8. AI GRADING QUEUE
-- ============================================================

CREATE TABLE ai_grading_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id),
  student_id UUID REFERENCES unified_profiles(id),
  classroom_id UUID REFERENCES classrooms(id),
  syllabus_item_id UUID REFERENCES syllabus_items(id),

  submission_type TEXT NOT NULL CHECK (submission_type IN ('writing', 'speaking')),
  exam_type TEXT NOT NULL,
  rubric_type TEXT NOT NULL,  -- 'IELTS_WRITING_TASK2', 'TOEFL_IBT_WRITING', 'CUSTOM'
  rubric_config JSONB,        -- custom rubric if rubric_type = 'CUSTOM'

  student_response TEXT,       -- essay text (for writing)
  audio_url TEXT,              -- R2 URL (for speaking)

  -- AI evaluation result
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
  ai_score DECIMAL,
  ai_band DECIMAL,
  ai_feedback JSONB,
  -- {
  --   "overall": 6.0,
  --   "task_achievement": 6.0,
  --   "coherence_cohesion": 5.5,
  --   "lexical_resource": 6.0,
  --   "grammatical_range": 6.5,
  --   "strengths": ["Good paragraph structure", "Clear thesis"],
  --   "weaknesses": ["Limited vocabulary range", "Some article errors"],
  --   "specific_feedback": [
  --     {"paragraph": 2, "issue": "Run-on sentence", "suggestion": "Split into two sentences"},
  --     ...
  --   ]
  -- }

  -- RAG context used (for audit)
  rag_documents_used UUID[],

  processing_started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_grading_status ON ai_grading_queue(status);
CREATE INDEX idx_grading_teacher ON ai_grading_queue(teacher_id);

-- ============================================================
-- 9. AI GENERATION QUEUE
-- ============================================================

CREATE TABLE ai_generation_queue (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id),
  classroom_id UUID REFERENCES classrooms(id),
  syllabus_id UUID REFERENCES syllabi(id),

  generation_type TEXT NOT NULL CHECK (generation_type IN (
    'reading_passage', 'listening_script', 'writing_prompt',
    'speaking_prompt', 'grammar_drill', 'vocabulary_set',
    'mock_test', 'worksheet', 'quiz'
  )),
  exam_type TEXT NOT NULL,
  cefr_level TEXT,
  topic TEXT,
  indonesian_context BOOLEAN DEFAULT FALSE,

  -- Generation parameters
  params JSONB,
  -- {
  --   "num_questions": 10,
  --   "question_types": ["multiple_choice", "true_false", "fill_blank"],
  --   "include_explanations": true,
  --   "include_answer_key": true,
  --   "difficulty": "B2",
  --   "passage_topic": "environment",
  --   "word_count_range": [600, 800]
  -- }

  -- Result
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'validated')),
  generated_content JSONB,
  -- {
  --   "passage": "The rapid urbanization of Jakarta has...",
  --   "questions": [
  --     {"id": 1, "type": "multiple_choice", "question": "...", "options": ["A","B","C","D"], "answer": "B", "explanation": "..."},
  --     ...
  --   ],
  --   "answer_key": {...},
  --   "metadata": {"word_count": 720, "cefr_level": "B2", "estimated_time_min": 20}
  -- }

  -- RAG context used
  rag_documents_used UUID[],

  -- Validation (content quality check)
  validation_status TEXT CHECK (validation_status IN ('pending', 'passed', 'failed', 'needs_review')),
  validation_notes TEXT,
  validated_at TIMESTAMPTZ,

  processing_started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  error_message TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_gen_status ON ai_generation_queue(status);
CREATE INDEX idx_gen_teacher ON ai_generation_queue(teacher_id);

-- ============================================================
-- 10. UNIFIED STUDENT PROGRESS
-- ============================================================

CREATE TABLE student_progress_unified (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,

  -- Latest scores from each platform
  ibt_latest_score DECIMAL,
  ibt_latest_section_scores JSONB,
  ibt_last_test_at TIMESTAMPTZ,

  itp_latest_score DECIMAL,
  itp_latest_section_scores JSONB,
  itp_last_test_at TIMESTAMPTZ,

  ielts_latest_band DECIMAL,
  ielts_latest_section_scores JSONB,
  ielts_last_test_at TIMESTAMPTZ,

  toeic_latest_score DECIMAL,
  toeic_latest_section_scores JSONB,
  toeic_last_test_at TIMESTAMPTZ,

  -- EduBot progress
  edubot_xp INTEGER DEFAULT 0,
  edubot_streak_days INTEGER DEFAULT 0,
  edubot_questions_answered INTEGER DEFAULT 0,
  edubot_accuracy_rate DECIMAL,
  edubot_last_active TIMESTAMPTZ,

  -- AI grading results
  writing_latest_band DECIMAL,
  writing_last_graded_at TIMESTAMPTZ,
  speaking_latest_band DECIMAL,
  speaking_last_graded_at TIMESTAMPTZ,

  -- Syllabus progress
  syllabus_id UUID REFERENCES syllabi(id),
  syllabus_completion_pct DECIMAL DEFAULT 0,
  syllabus_items_completed INTEGER DEFAULT 0,
  syllabus_items_total INTEGER DEFAULT 0,

  -- Readiness gauge
  readiness_status TEXT DEFAULT 'preparing' CHECK (readiness_status IN ('preparing', 'almost_ready', 'ready', 'tested')),
  readiness_pct DECIMAL DEFAULT 0,
  predicted_score DECIMAL,
  weeks_to_target INTEGER,

  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_progress_student ON student_progress_unified(student_id);

-- ============================================================
-- 11. CROSS-EXAM SCORE MAP
-- ============================================================

CREATE TABLE cross_exam_score_map (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_exam TEXT NOT NULL,
  source_score DECIMAL NOT NULL,
  target_exam TEXT NOT NULL,
  target_score DECIMAL NOT NULL,
  confidence DECIMAL DEFAULT 0.9,
  notes TEXT
);

-- Seed data: approximate equivalencies
INSERT INTO cross_exam_score_map (source_exam, source_score, target_exam, target_score, notes) VALUES
  ('IELTS', 5.0, 'TOEFL_IBT', 35, 'ETS concordance table'),
  ('IELTS', 5.5, 'TOEFL_IBT', 46, 'ETS concordance table'),
  ('IELTS', 6.0, 'TOEFL_IBT', 60, 'ETS concordance table'),
  ('IELTS', 6.5, 'TOEFL_IBT', 79, 'ETS concordance table'),
  ('IELTS', 7.0, 'TOEFL_IBT', 94, 'ETS concordance table'),
  ('IELTS', 7.5, 'TOEFL_IBT', 102, 'ETS concordance table'),
  ('IELTS', 8.0, 'TOEFL_IBT', 110, 'ETS concordance table'),
  ('IELTS', 5.0, 'TOEFL_ITP', 460, 'approximate'),
  ('IELTS', 5.5, 'TOEFL_ITP', 513, 'approximate'),
  ('IELTS', 6.0, 'TOEFL_ITP', 543, 'approximate'),
  ('IELTS', 6.5, 'TOEFL_ITP', 577, 'approximate'),
  ('IELTS', 7.0, 'TOEFL_ITP', 610, 'approximate'),
  ('IELTS', 5.0, 'TOEIC', 400, 'approximate'),
  ('IELTS', 6.0, 'TOEIC', 650, 'approximate'),
  ('IELTS', 7.0, 'TOEIC', 850, 'approximate'),
  ('TOEFL_IBT', 60, 'IELTS', 6.0, 'ETS concordance'),
  ('TOEFL_IBT', 79, 'IELTS', 6.5, 'ETS concordance'),
  ('TOEFL_IBT', 94, 'IELTS', 7.0, 'ETS concordance'),
  ('TOEFL_IBT', 35, 'TOEFL_ITP', 460, 'approximate'),
  ('TOEFL_IBT', 60, 'TOEFL_ITP', 543, 'approximate'),
  ('TOEFL_IBT', 79, 'TOEFL_ITP', 577, 'approximate');

-- ============================================================
-- 12. VIDEO CONTENT SYSTEM
-- ============================================================

CREATE TABLE video_courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  exam_type TEXT NOT NULL CHECK (exam_type IN ('TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL')),
  total_lessons INTEGER DEFAULT 0,
  difficulty TEXT,
  is_published BOOLEAN DEFAULT FALSE,
  is_free_preview BOOLEAN DEFAULT FALSE,  -- first N lessons free on YouTube
  free_preview_lessons INTEGER DEFAULT 5,
  price_idr DECIMAL DEFAULT 0,  -- 0 = included in premium, >0 = standalone purchase
  thumbnail_url TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE video_lessons (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  course_id UUID NOT NULL REFERENCES video_courses(id) ON DELETE CASCADE,
  lesson_number INTEGER NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  section TEXT,           -- 'reading', 'listening', 'speaking', 'writing', 'grammar', 'vocabulary'
  cefr_level TEXT,
  duration_seconds INTEGER,

  -- Video URLs
  video_url_r2 TEXT,      -- Cloudflare R2 URL (premium access)
  youtube_id TEXT,        -- YouTube ID (free preview / marketing)

  -- Interactive elements
  comprehension_questions JSONB DEFAULT '[]',
  -- [{"q": "What is the main strategy for inference questions?",
  --   "options": ["A","B","C","D"], "answer_idx": 2,
  --   "explanation": "...", "timestamp": "02:30"}]

  key_vocabulary JSONB DEFAULT '[]',
  -- [{"word": "inference", "definition": "...", "ipa": "/ˈɪnfərəns/"}]

  practice_links JSONB DEFAULT '[]',
  -- [{"platform": "ibt", "url": "https://ibt.osee.co.id/test/inference-set-1",
  --   "label": "Practice inference questions"}]

  -- Metadata
  is_published BOOLEAN DEFAULT FALSE,
  is_free_preview BOOLEAN DEFAULT FALSE,
  views_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_video_course ON video_lessons(course_id);
CREATE INDEX idx_video_lesson_num ON video_lessons(course_id, lesson_number);

-- ============================================================
-- 13. LIVE CLASSES
-- ============================================================

CREATE TABLE live_classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  teacher_name TEXT NOT NULL,
  exam_type TEXT,
  section TEXT,
  cefr_level TEXT,

  -- Schedule
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER DEFAULT 90,
  timezone TEXT DEFAULT 'Asia/Jakarta',

  -- Zoom
  zoom_link TEXT NOT NULL,
  zoom_meeting_id TEXT,
  zoom_password TEXT,

  -- Recording (post-class)
  recording_url TEXT,
  recording_available BOOLEAN DEFAULT FALSE,

  -- Access
  is_free BOOLEAN DEFAULT TRUE,
  is_premium_only BOOLEAN DEFAULT FALSE,
  max_participants INTEGER,

  -- Status
  status TEXT DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'completed', 'cancelled')),

  -- Tutor Bot integration
  bot_notified BOOLEAN DEFAULT FALSE,
  bot_reminder_sent BOOLEAN DEFAULT FALSE,
  bot_recurrence_sent BOOLEAN DEFAULT FALSE,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_live_class_schedule ON live_classes(scheduled_at);
CREATE INDEX idx_live_class_status ON live_classes(status);

-- ============================================================
-- 14. WEBHOOK EVENTS
-- ============================================================

CREATE TABLE webhook_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform TEXT NOT NULL,  -- 'ibt', 'itp', 'ielts', 'toeic', 'osee', 'edubot'
  event_type TEXT NOT NULL,
  user_email TEXT,
  user_id UUID REFERENCES unified_profiles(id),
  payload JSONB NOT NULL,
  processed BOOLEAN DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_webhook_processed ON webhook_events(processed);
CREATE INDEX idx_webhook_platform ON webhook_events(platform);

-- ============================================================
-- 15. TEACHER SUBSCRIPTIONS
-- ============================================================

CREATE TABLE teacher_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'pro', 'institution')),
  monthly_fee_idr DECIMAL DEFAULT 0,
  started_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  auto_renew BOOLEAN DEFAULT FALSE,
  payment_method TEXT,
  payment_reference TEXT,
  is_active BOOLEAN DEFAULT TRUE
);

CREATE INDEX idx_sub_teacher ON teacher_subscriptions(teacher_id);

-- ============================================================
-- 16. BRANDING CONFIGS (white-label)
-- ============================================================

CREATE TABLE branding_configs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  logo_url TEXT,
  primary_color TEXT DEFAULT '#CCFF00',
  secondary_color TEXT DEFAULT '#000000',
  custom_subdomain TEXT,
  hide_osee_branding BOOLEAN DEFAULT FALSE,
  custom_copyright TEXT,
  active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 17. ROW-LEVEL SECURITY (RLS) POLICIES
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE unified_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classrooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE classroom_enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabi ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_grading_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_generation_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_progress_unified ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE branding_configs ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_quota_usage ENABLE ROW LEVEL SECURITY;

-- Profiles: users can only see/update their own profile
CREATE POLICY profiles_self_select ON unified_profiles
  FOR SELECT USING (auth.uid() = id OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY profiles_self_update ON unified_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Classrooms: teachers see their own, students see enrolled
CREATE POLICY classrooms_teacher_select ON classrooms
  FOR SELECT USING (teacher_id = auth.uid() OR EXISTS (
    SELECT 1 FROM classroom_enrollments
    WHERE classroom_id = classrooms.id AND student_id = auth.uid() AND is_active = TRUE
  ) OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
CREATE POLICY classrooms_teacher_insert ON classrooms
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY classrooms_teacher_update ON classrooms
  FOR UPDATE USING (teacher_id = auth.uid());
CREATE POLICY classrooms_teacher_delete ON classrooms
  FOR DELETE USING (teacher_id = auth.uid());

-- Syllabi: teachers manage their own, students see assigned
CREATE POLICY syllabi_teacher_select ON syllabi
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classroom_enrollments ce
      JOIN syllabi s ON s.classroom_id = ce.classroom_id
      WHERE ce.student_id = auth.uid() AND s.id = syllabi.id AND ce.is_active = TRUE
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
CREATE POLICY syllabi_teacher_insert ON syllabi
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY syllabi_teacher_update ON syllabi
  FOR UPDATE USING (teacher_id = auth.uid());

-- Commission: teachers see their own commission
CREATE POLICY commission_teacher_select ON commission_ledger
  FOR SELECT USING (teacher_id = auth.uid() OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- AI grading: teachers see their own queue, students see their results
CREATE POLICY grading_teacher_select ON ai_grading_queue
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR student_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- Student progress: students see own, teachers see enrolled students
CREATE POLICY progress_student_select ON student_progress_unified
  FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classroom_enrollments ce
      WHERE ce.student_id = student_progress_unified.student_id
      AND ce.teacher_id = auth.uid()
      AND ce.is_active = TRUE
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- Video lessons: public courses visible to all, premium gated by app logic
CREATE POLICY video_select ON video_lessons
  FOR SELECT USING (is_published = TRUE OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- Live classes: all scheduled classes visible to all authenticated users
CREATE POLICY live_class_select ON live_classes
  FOR SELECT USING (status IN ('scheduled', 'live', 'completed') OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- Knowledge base: teachers can read, only admin can write
CREATE POLICY kb_select ON knowledge_base_documents
  FOR SELECT USING (is_active = TRUE);
CREATE POLICY kb_embeddings_select ON knowledge_base_embeddings
  FOR SELECT USING (TRUE);

-- ============================================================
-- 18. USEFUL VIEWS
-- ============================================================

-- Teacher earnings dashboard view
CREATE VIEW teacher_earnings_summary AS
SELECT
  t.id as teacher_id,
  t.display_name,
  tp.referral_code,
  tp.tier,
  COUNT(DISTINCT r.student_id) as total_students,
  COUNT(DISTINCT CASE WHEN r.first_test_completed_at IS NOT NULL THEN r.student_id END) as students_tested,
  COUNT(DISTINCT CASE WHEN r.official_test_booked_at IS NOT NULL THEN r.student_id END) as students_booked,
  COUNT(DISTINCT CASE WHEN r.premium_active = TRUE THEN r.student_id END) as students_premium,
  COALESCE(SUM(r.first_test_commission), 0) as total_test_commission,
  COALESCE(SUM(r.booking_commission), 0) as total_booking_commission,
  COALESCE(SUM(r.premium_commission_total), 0) as total_premium_commission,
  COALESCE(SUM(r.package_commission), 0) as total_package_commission,
  COALESCE(SUM(r.total_earned), 0) as lifetime_earnings,
  COALESCE(SUM(CASE WHEN r.premium_active = TRUE THEN r.premium_commission_monthly ELSE 0 END), 0) as monthly_recurring
FROM unified_profiles t
JOIN teacher_profiles tp ON tp.user_id = t.id
LEFT JOIN teacher_referrals r ON r.teacher_id = t.id
GROUP BY t.id, t.display_name, tp.referral_code, tp.tier;

-- Classroom summary view
CREATE VIEW classroom_summary AS
SELECT
  c.id as classroom_id,
  c.name as classroom_name,
  c.target_exam,
  c.teacher_id,
  COUNT(ce.id) as enrolled_students,
  COUNT(CASE WHEN ce.is_active = TRUE THEN 1 END) as active_students,
  (SELECT COUNT(*) FROM syllabi s WHERE s.classroom_id = c.id AND s.is_published = TRUE) as published_syllabi
FROM classrooms c
LEFT JOIN classroom_enrollments ce ON ce.classroom_id = c.id
GROUP BY c.id, c.name, c.target_exam, c.teacher_id;

-- Readiness gauge view
CREATE VIEW student_readiness AS
SELECT
  p.student_id,
  u.display_name,
  u.target_exam,
  u.target_score->>'overall' as target_overall,
  p.readiness_status,
  p.readiness_pct,
  p.predicted_score,
  p.weeks_to_target,
  p.ibt_latest_score,
  p.itp_latest_score,
  p.ielts_latest_band,
  p.toeic_latest_score,
  p.writing_latest_band,
  p.speaking_latest_band,
  p.edubot_streak_days,
  p.updated_at
FROM student_progress_unified p
JOIN unified_profiles u ON u.id = p.student_id;
```

---

## 5. API SPECIFICATION

### Hub API — Cloudflare Workers + Hono

```typescript
// ============================================================
// ROUTE STRUCTURE
// ============================================================

// /api/auth/*           — Authentication & SSO
// /api/teacher/*        — Teacher portal API
// /api/student/*        — Student portal API
// /api/ai/*             — AI grading + generation + RAG
// /api/commission/*     — Commission tracking + payouts
// /api/webhook/*        — Webhook receivers from practice platforms
// /api/video/*          — Video content management
// /api/classes/*        — Live class management
// /api/syllabus/*       — Syllabus builder API
// /api/reports/*        — Report generation
// /api/admin/*          — Admin API
// /api/platform/*       — Cross-platform bridge (links to practice sites)

// ============================================================
// AUTH ENDPOINTS
// ============================================================

POST   /api/auth/register
  Body: { email, password, name, role: 'teacher'|'student', phone?, referral_code? }
  Returns: { jwt, user }
  - If referral_code provided → link student to teacher
  - Sets HttpOnly cookie: osee_token=<jwt> (domain: .osee.co.id)

POST   /api/auth/login
  Body: { email, password }
  Returns: { jwt, user }

POST   /api/auth/verify
  Headers: Cookie: osee_token=<jwt>
  Returns: { valid: true, user }
  - Used by other *.osee.co.id platforms to verify SSO

POST   /api/auth/link-telegram
  Body: { telegram_id, osee_token }
  - Links Telegram account to unified_profile

POST   /api/auth/refresh
  Returns: { jwt }

POST   /api/auth/logout
  - Clears cookie

// ============================================================
// TEACHER PORTAL ENDPOINTS
// ============================================================

GET    /api/teacher/dashboard
  Returns: { classrooms[], earnings, ai_quota, recent_activity }

POST   /api/teacher/classroom
  Body: { name, target_exam, description? }
  Returns: { classroom, join_code }

GET    /api/teacher/classrooms
  Returns: { classrooms[] with student_count, syllabi }

POST   /api/teacher/classroom/:id/students
  Body: { student_emails[] } or { join_code }
  - Adds students to classroom

GET    /api/teacher/classroom/:id/students
  Returns: { students[] with progress }

GET    /api/teacher/referral-code
  Returns: { code, total_uses, earnings }

POST   /api/teacher/syllabus
  Body: { name, classroom_id, target_exam, description? }
  Returns: { syllabus }

GET    /api/teacher/syllabus/:id
  Returns: { syllabus with items[] }

PUT    /api/teacher/syllabus/:id/items
  Body: { items: [{ source_type, source_material_id, title, sort_order, ... }] }
  - Batch update syllabus items (drag-and-drop save)

POST   /api/teacher/syllabus/:id/items
  Body: { item: { source_type, source_material_id, title, ... } }
  - Add single item to syllabus

DELETE /api/teacher/syllabus/:id/items/:itemId
  - Remove item from syllabus

GET    /api/teacher/earnings
  Returns: { total, monthly_recurring, breakdown, history[] }

GET    /api/teacher/ai-quota
  Returns: { grading: { used, max, bonus }, generation: { used, max, bonus } }

// ============================================================
// AI ENDPOINTS
// ============================================================

POST   /api/ai/grade-writing
  Body: { student_id, classroom_id?, syllabus_item_id?, exam_type, rubric_type, essay_text }
  - Checks quota
  - Queues grading job
  - Calls EduBot's writing evaluation (or processes in Hub)
  - Uses RAG to ground feedback in rubric + error patterns
  Returns: { job_id, status: 'pending' }

POST   /api/ai/grade-speaking
  Body: { student_id, classroom_id?, syllabus_item_id?, exam_type, audio_url }
  - Checks quota
  - Queues speaking evaluation
  - Calls EduBot's speaking route (Whisper + GPT)
  Returns: { job_id, status: 'pending' }

GET    /api/ai/grading/:job_id
  Returns: { status, score, band, feedback }

POST   /api/ai/generate-material
  Body: {
    generation_type: 'reading_passage'|'listening_script'|'writing_prompt'|...
    exam_type,
    cefr_level,
    topic?,
    indonesian_context: boolean,
    params: { num_questions, include_explanations, ... }
  }
  - Checks quota
  - Retrieves RAG context from knowledge base
  - Generates content via GPT-4o-mini
  - Validates via content validator
  Returns: { job_id, status: 'pending' }

GET    /api/ai/generation/:job_id
  Returns: { status, generated_content, validation_status }

POST   /api/ai/rag/search
  Body: { query, category?, cefr_level?, limit? }
  - Vector similarity search on knowledge_base_embeddings
  Returns: { documents[] }

POST   /api/ai/rag/upload
  Body: { title, source, category, content, metadata }
  - Teacher uploads custom material to knowledge base
  - Chunks + embeds via OpenAI text-embedding-3-small
  Returns: { document_id }

// ============================================================
// REPORT ENDPOINTS
// ============================================================

POST   /api/reports/student/:student_id
  Body: { format: 'json'|'pdf', include_recommendations: boolean }
  - Aggregates: progress, scores, weakness analysis, AI recommendations
  - Generates PDF with teacher branding + OSEE footer
  Returns: { report_url } or { report_data }

POST   /api/reports/classroom/:classroom_id
  Body: { format: 'json'|'pdf' }
  - Aggregates: class average, weakness heatmap, teacher effectiveness
  - Generates PDF with teacher branding + OSEE footer
  Returns: { report_url } or { report_data }

// ============================================================
// COMMISSION ENDPOINTS
// ============================================================

GET    /api/commission/earnings
  Returns: { total, monthly_recurring, breakdown, history[] }

POST   /api/commission/payout
  Body: { amount, method: 'bank_transfer'|'gopay'|'ovo' }
  - Teacher requests payout
  Returns: { payout_id, status }

GET    /api/commission/payouts
  Returns: { payouts[] }

// ============================================================
// WEBHOOK RECEIVERS
// ============================================================

POST   /api/webhook/ibt
  Headers: X-Webhook-Secret: <secret>
  Body: { event, user_email, score, section_scores, ... }
  - Processes TOEFL iBT practice events
  - Updates student_progress_unified
  - Triggers commission if applicable

POST   /api/webhook/itp
  Headers: X-Webhook-Secret: <secret>
  Body: { event, user_email, score, ... }

POST   /api/webhook/ielts
  Headers: X-Webhook-Secret: <secret>
  Body: { event, user_email, band_score, ... }

POST   /api/webhook/toeic
  Headers: X-Webhook-Secret: <secret>
  Body: { event, user_email, score, ... }

POST   /api/webhook/booking
  Headers: X-Webhook-Secret: <secret>
  Body: { event, user_email, test_type, booking_amount, ... }
  - osee.co.id sends when student books official test
  - Triggers Rp 50k commission to teacher

POST   /api/webhook/edubot
  Headers: X-Webhook-Secret: <secret>
  Body: { event, telegram_id, ... }
  - EduBot sends progress updates, premium subscriptions

// ============================================================
// VIDEO CONTENT ENDPOINTS
// ============================================================

GET    /api/video/courses
  Returns: { courses[] with lesson_count, progress if student }

GET    /api/video/courses/:id
  Returns: { course with lessons[] }

GET    /api/video/lessons/:id
  Returns: { lesson with comprehension_questions, vocabulary, practice_links }
  - If premium lesson → checks subscription

POST   /api/video/lessons/:id/complete
  Body: { quiz_answers, time_spent }
  - Records completion + quiz score
  - Updates progress
  - Notifies teacher if student in classroom

// ============================================================
// LIVE CLASS ENDPOINTS
// ============================================================

GET    /api/classes/upcoming
  Returns: { classes[] with zoom_link, scheduled_at }

GET    /api/classes/:id
  Returns: { class with zoom_link }

POST   /api/classes/:id/register
  - Student registers interest (for notification)

// ============================================================
// STUDENT PORTAL ENDPOINTS
// ============================================================

GET    /api/student/dashboard
  Returns: { syllabus, progress, readiness, upcoming_classes, recommendations }

GET    /api/student/syllabus
  Returns: { syllabus with items[], completion_pct }

POST   /api/student/syllabus/:itemId/start
  - Marks item as started
  - Returns deep link to source platform

POST   /api/student/syllabus/:itemId/complete
  Body: { score?, answers? }
  - Marks item as completed
  - Updates progress

GET    /api/student/readiness
  Returns: { readiness_pct, predicted_score, weeks_to_target, recommendations }

GET    /api/student/cross-exam-map
  Returns: { equivalent_scores across all 5 exams }

GET    /api/student/book-test
  Returns: { available_dates[], osee_booking_url }
  - Contextual: only shows if readiness > 80%

// ============================================================
// PLATFORM BRIDGE ENDPOINTS
// ============================================================

GET    /api/platform/materials?type=reading&exam=IELTS&level=B2
  - Queries all practice platforms for available materials
  - Returns unified list with deep links

GET    /api/platform/scores
  Returns: { ibt, itp, ielts, toeic, edubot } — latest scores from all platforms

// ============================================================
// ADMIN ENDPOINTS
// ============================================================

GET    /api/admin/teachers
  Returns: { teachers[] with stats }

GET    /api/admin/students
  Returns: { students[] with stats }

GET    /api/admin/commission
  Returns: { total_paid, total_pending, by_teacher[] }

POST   /api/admin/commission-rates
  Body: { action, rate_idr }
  - Update commission rates

GET    /api/admin/analytics
  Returns: { total_teachers, total_students, total_bookings, revenue }

POST   /api/admin/knowledge-base/upload
  Body: { title, source, category, content, metadata }
  - Admin uploads to RAG knowledge base

GET    /api/admin/ambassadors
  Returns: { ambassadors[] with recruited_count }
```

---

## 6. FRONTEND ARCHITECTURE

### Option A: React/Vite (recommended — aligns with EduBot)

```
frontend/
├── src/
│   ├── App.tsx                    # Root + router + auth guard
│   ├── main.tsx                   # Entry point
│   ├── index.css                  # Tailwind + global styles
│   │
│   ├── api/                       # API client layer
│   │   ├── client.ts              # Base fetch with auth + error handling
│   │   ├── auth.ts                # Auth API calls
│   │   ├── teacher.ts             # Teacher API calls
│   │   ├── student.ts             # Student API calls
│   │   ├── ai.ts                  # AI API calls (grading, generation)
│   │   ├── commission.ts          # Commission API calls
│   │   ├── video.ts               # Video API calls
│   │   ├── classes.ts             # Live class API calls
│   │   └── reports.ts             # Report API calls
│   │
│   ├── stores/                    # Zustand state management
│   │   ├── authStore.ts           # User, JWT, role
│   │   ├── teacherStore.ts        # Teacher dashboard state
│   │   ├── studentStore.ts        # Student dashboard state
│   │   ├── syllabusStore.ts       # Syllabus builder state
│   │   └── aiStore.ts             # AI grading/generation state
│   │
│   ├── components/                # Reusable UI components
│   │   ├── OSEEBranding.tsx       # OSEE branding widget (always visible)
│   │   ├── TutorBotLink.tsx       # Floating Tutor Bot CTA
│   │   ├── BookTestBanner.tsx     # Contextual "book official test" CTA
│   │   ├── Sidebar.tsx            # Navigation sidebar
│   │   ├── Header.tsx             # Top header with user menu
│   │   ├── ProgressBar.tsx        # Readiness/progress gauge
│   │   ├── ScoreCard.tsx          # Score display card
│   │   ├── DragDropList.tsx       # Reorderable list (syllabus builder)
│   │   ├── MaterialCard.tsx       # Material item card
│   │   ├── StudentTable.tsx       # Student list with progress
│   │   ├── CommissionWidget.tsx   # Earnings display
│   │   ├── AIQuotaBar.tsx         # AI usage quota bar
│   │   ├── VideoPlayer.tsx        # Video player with quiz overlay
│   │   ├── ClassSchedule.tsx      # Live class schedule widget
│   │   ├── ReportViewer.tsx       # Report PDF viewer
│   │   └── CrossExamMap.tsx       # Cross-exam score equivalency
│   │
│   ├── pages/                     # Route-level pages
│   │   ├── Landing.tsx            # Marketing landing page
│   │   ├── Login.tsx              # Login page
│   │   ├── Register.tsx           # Registration (teacher/student)
│   │   ├── RegisterViaReferral.tsx # Student registration via teacher code
│   │   │
│   │   ├── teacher/               # Teacher portal pages
│   │   │   ├── Dashboard.tsx      # Teacher dashboard
│   │   │   ├── Classrooms.tsx     # Classroom list + management
│   │   │   ├── ClassroomDetail.tsx # Single classroom with students
│   │   │   ├── SyllabusBuilder.tsx # Drag-and-drop syllabus builder
│   │   │   ├── AIGenerator.tsx    # AI material generator
│   │   │   ├── AIGrader.tsx       # AI writing/speaking grader
│   │   │   ├── StudentReports.tsx # Student report list + PDF
│   │   │   ├── ClassroomReport.tsx # Classroom report + PDF
│   │   │   ├── Earnings.tsx       # Commission + earnings dashboard
│   │   │   ├── Settings.tsx       # Teacher settings + branding
│   │   │   └── Upgrade.tsx        # Pro/Institution upgrade page
│   │   │
│   │   ├── student/               # Student portal pages
│   │   │   ├── Dashboard.tsx      # Student dashboard
│   │   │   ├── Syllabus.tsx       # View assigned syllabus
│   │   │   ├── Progress.tsx       # Progress dashboard
│   │   │   ├── Readiness.tsx      # Readiness gauge + book test
│   │   │   ├── VideoLessons.tsx   # Video course library
│   │   │   ├── LiveClasses.tsx    # Upcoming live classes
│   │   │   └── CrossExam.tsx      # Cross-exam score map
│   │   │
│   │   └── admin/                 # Admin pages
│   │       ├── Dashboard.tsx      # Platform analytics
│   │       ├── Teachers.tsx       # Teacher management
│   │       ├── Students.tsx       # Student management
│   │       ├── Commission.tsx     # Commission rates + payouts
│   │       ├── KnowledgeBase.tsx  # RAG knowledge base manager
│   │       └── Ambassadors.tsx    # Ambassador program
│   │
│   ├── hooks/                     # Custom React hooks
│   │   ├── useAuth.ts             # Auth state + guards
│   │   ├── useQuota.ts            # AI quota checking
│   │   ├── useWebhook.ts          # Real-time webhook status
│   │   └── useDragDrop.ts         # Drag-and-drop logic
│   │
│   ├── types/                     # TypeScript types
│   │   ├── api.ts                 # API response types
│   │   ├── models.ts              # Domain models
│   │   └── enums.ts               # Enums (exam types, roles, etc.)
│   │
│   └── utils/                     # Utilities
│       ├── format.ts              # Date/currency/score formatting
│       ├── pdf.ts                 # PDF generation (jsPDF)
│       └── validation.ts          # Form validation
│
├── public/
│   ├── osee-logo.svg
│   └── favicon.ico
│
├── index.html
├── vite.config.ts
├── tailwind.config.js
├── tsconfig.json
└── package.json
```

### Key frontend components

#### OSEE Branding Widget (always visible on free tier)

```typescript
// components/OSEEBranding.tsx
export function OSEEBranding({ teacherBranding }: { teacherBranding?: BrandingConfig }) {
  const hideOSEE = teacherBranding?.hide_osee_branding && teacherBranding?.tier !== 'free';

  if (hideOSEE) {
    return <TeacherBranding config={teacherBranding} />;
  }

  return (
    <div className="osee-branding-widget">
      <div className="osee-branding-card">
        <p className="text-xs text-gray-500">Powered by</p>
        <img src="/osee-logo.svg" alt="OSEE.co.id" className="h-6" />
        <p className="text-xs">Official ETS Test Center since 2014</p>
        <div className="flex gap-2 mt-2">
          <a href="https://osee.co.id" target="_blank"
             className="btn btn-primary btn-sm">
            Book Official Test
          </a>
          <a href="https://t.me/osee_edubot" target="_blank"
             className="btn btn-secondary btn-sm">
            🤖 Tutor Bot
          </a>
        </div>
      </div>
    </div>
  );
}
```

#### Syllabus Builder (drag-and-drop)

```typescript
// pages/teacher/SyllabusBuilder.tsx
import { DndContext, useDraggable, useDroppable } from '@dnd-kit/core';

export function SyllabusBuilder() {
  const [availableMaterials, setAvailableMaterials] = useState([]);
  const [syllabusItems, setSyllabusItems] = useState([]);

  // Left column: material library (from all platforms + AI generated)
  // Right column: syllabus timeline (reorderable)
  // Drag from left → right to add to syllabus
  // Drag within right to reorder
  // "Save" button batch-updates syllabus_items via PUT /api/teacher/syllabus/:id/items

  return (
    <DndContext onDragEnd={handleDragEnd}>
      <div className="grid grid-cols-2 gap-4">
        {/* Left: Material Library */}
        <MaterialLibrary
          materials={availableMaterials}
          categories={['TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'AI_GENERATED']}
          onGenerate={() => navigate('/teacher/ai-generator')}
        />

        {/* Right: Syllabus Timeline */}
        <SyllabusTimeline
          items={syllabusItems}
          onSave={handleSave}
        />
      </div>

      {/* AI Co-Pilot suggestion bar */}
      <AICoPilotBar
        suggestion="Based on your class's IELTS writing scores (avg Band 5.2),
                    I recommend adding 2 writing modules."
        onAccept={() => addSuggestedItems()}
      />
    </DndContext>
  );
}
```

---

## 7. RAG KNOWLEDGE BASE

### Architecture

```
┌───────────────────────────────────────────────────────┐
│              RAG KNOWLEDGE BASE                          │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  DOCUMENT INGESTION                                 │  │
│  │                                                     │  │
│  │  Source documents (text, PDF, JSON)                 │  │
│  │    → Chunk into 500-1000 token segments             │  │
│  │    → Embed each chunk via OpenAI text-embedding-3   │  │
│  │    → Store in knowledge_base_embeddings (pgvector)  │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  RETRIEVAL (at generation/grading time)             │  │
│  │                                                     │  │
│  │  Teacher request: "Generate B2 reading about env"  │  │
│  │    → Embed query                                    │  │
│  │    → Vector search: find most similar chunks        │  │
│  │    → Retrieve top 5-10 relevant documents           │  │
│  │    → Pass as context to GPT-4o-mini                 │  │
│  │    → Generate grounded content                      │  │
│  └───────────────────────────────────────────────────┘  │
│                                                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  DOCUMENT CATEGORIES                                │  │
│  │                                                     │  │
│  │  grammar:                                            │  │
│  │    • English Grammar in Use patterns                 │  │
│  │    • Practical English Usage rules                   │  │
│  │    • Kurikulum Merdeka grammar scope                 │  │
│  │    • CEFR grammatical competence descriptors         │  │
│  │                                                     │  │
│  │  vocabulary:                                         │  │
│  │    • Academic Word List (570 families)               │  │
│  │    • General Service List (2,000 words)              │  │
│  │    • CEFR vocabulary bands A1-C2                     │  │
│  │    • Exam-specific vocabulary lists                  │  │
│  │    • Indonesian-English false friends                │  │
│  │                                                     │  │
│  │  pronunciation:                                      │  │
│  │    • IPA chart                                      │  │
│  │    • Common Indonesian pronunciation errors           │  │
│  │    • Minimal pairs (/θ/-/t/, /ʃ/-/s/, /v/-/f/)       │  │
│  │    • Stress patterns English vs Indonesian            │  │
│  │                                                     │  │
│  │  rubrics:                                            │  │
│  │    • IELTS writing band descriptors (public)         │  │
│  │    • IELTS speaking band descriptors (public)        │  │
│  │    • TOEFL iBT speaking/writing rubrics (public)     │  │
│  │    • TOEIC writing rubrics                           │  │
│  │    • CEFR can-do statements                          │  │
│  │                                                     │  │
│  │  question_templates:                                 │  │
│  │    • TOEFL iBT question format specs                 │  │
│  │    • IELTS question type specifications              │  │
│  │    • TOEIC question formats                          │  │
│  │    • TOEFL ITP structure/written expression          │  │
│  │                                                     │  │
│  │  error_patterns:                                     │  │
│  │    • Indonesian L1 interference patterns              │  │
│  │    • Common Indonesian-English grammar errors         │  │
│  │    • EduBot's existing error pattern data             │  │
│  │    • Frequency-ranked error types by CEFR level       │  │
│  │                                                     │  │
│  │  cultural_context:                                  │  │
│  │    • Indonesian education system context              │  │
│  │    • Local topics for reading passages               │  │
│  │    • Culturally relevant scenarios                   │  │
│  │                                                     │  │
│  │  teacher_uploads:                                   │  │
│  │    • Materials teachers upload (flywheel)             │  │
│  │    • Custom rubrics                                  │  │
│  │    • School-specific curriculum                      │  │
│  │                                                     │  │
│  │  video_transcripts:                                 │  │
│  │    • Transcripts of OSEE video lessons               │  │
│  │    • Timestamped key points                          │  │
│  └───────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────┘
```

### Ingestion script

```typescript
// scripts/ingest-knowledge-base.ts
import OpenAI from 'openai';

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

async function ingestDocument(
  supabase: SupabaseClient,
  doc: {
    title: string;
    source: string;
    category: string;
    content: string;
    cefr_level?: string;
    metadata?: any;
  }
) {
  // 1. Insert document record
  const { data: document } = await supabase
    .from('knowledge_base_documents')
    .insert({
      title: doc.title,
      source: doc.source,
      category: doc.category,
      content: doc.content,
      cefr_level: doc.cefr_level,
      metadata: doc.metadata || {},
    })
    .select()
    .single();

  // 2. Chunk content (500 tokens, 50 overlap)
  const chunks = chunkText(doc.content, 500, 50);

  // 3. Embed each chunk
  for (let i = 0; i < chunks.length; i++) {
    const embedding = await openai.embeddings.create({
      model: 'text-embedding-3-small',
      input: chunks[i],
    });

    await supabase.from('knowledge_base_embeddings').insert({
      document_id: document.id,
      chunk_index: i,
      chunk_text: chunks[i],
      embedding: embedding.data[0].embedding,
    });
  }

  // 4. Update chunk count
  await supabase
    .from('knowledge_base_documents')
    .update({ content_chunk_count: chunks.length })
    .eq('id', document.id);
}

function chunkText(text: string, maxTokens: number, overlap: number): string[] {
  // Split by paragraphs, accumulate until token limit, overlap by N tokens
  const paragraphs = text.split('\n\n');
  const chunks: string[] = [];
  let current = '';

  for (const para of paragraphs) {
    if (estimateTokens(current + para) > maxTokens) {
      if (current) chunks.push(current);
      // Start new chunk with overlap from previous
      const overlapText = current.split(' ').slice(-overlap).join(' ');
      current = overlapText + '\n\n' + para;
    } else {
      current = current ? current + '\n\n' + para : para;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

function estimateTokens(text: string): number {
  return Math.ceil(text.length / 4); // rough estimate
}
```

### RAG retrieval at generation time

```typescript
// worker/src/services/rag-search.ts
import OpenAI from 'openai';

export async function ragSearch(
  supabase: SupabaseClient,
  openai: OpenAI,
  query: string,
  options: { category?: string; cefr_level?: string; limit?: number } = {}
): Promise<{ chunk_text: string; document_title: string; similarity: number }[]> {
  // 1. Embed the query
  const embedding = await openai.embeddings.create({
    model: 'text-embedding-3-small',
    input: query,
  });

  // 2. Vector similarity search in pgvector
  const { data } = await supabase.rpc('match_documents', {
    query_embedding: embedding.data[0].embedding,
    filter_category: options.category || null,
    filter_cefr: options.cefr_level || null,
    match_count: options.limit || 5,
  });

  return data || [];
}

// Supabase function for vector search
/*
CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(1536),
  filter_category TEXT,
  filter_cefr TEXT,
  match_count INTEGER DEFAULT 5
)
RETURNS TABLE (
  chunk_text TEXT,
  document_title TEXT,
  similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kbe.chunk_text,
    kbd.title,
    1 - (kbe.embedding <=> query_embedding) as similarity
  FROM knowledge_base_embeddings kbe
  JOIN knowledge_base_documents kbd ON kbd.id = kbe.document_id
  WHERE kbd.is_active = TRUE
    AND (filter_category IS NULL OR kbd.category = filter_category)
    AND (filter_cefr IS NULL OR kbd.cefr_level = filter_cefr)
  ORDER BY kbe.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
*/
```

### RAG-grounded material generation

```typescript
// worker/src/services/ai-generation.ts
import OpenAI from 'openai';
import { ragSearch } from './rag-search';

export async function generateMaterial(
  supabase: SupabaseClient,
  openai: OpenAI,
  params: {
    generation_type: string;
    exam_type: string;
    cefr_level: string;
    topic?: string;
    indonesian_context: boolean;
    num_questions: number;
  }
): Promise<any> {
  // 1. Build RAG query
  const ragQuery = `${params.generation_type} ${params.exam_type} ${params.cefr_level} ${params.topic || ''}`;
  const ragCategory = params.generation_type.includes('reading') ? 'question_templates'
    : params.generation_type.includes('grammar') ? 'grammar'
    : params.generation_type.includes('vocabulary') ? 'vocabulary'
    : 'question_templates';

  // 2. Retrieve relevant knowledge
  const ragResults = await ragSearch(supabase, openai, ragQuery, {
    category: ragCategory,
    cefr_level: params.cefr_level,
    limit: 5,
  });

  // 3. Build prompt with RAG context
  const ragContext = ragResults.map(r => r.chunk_text).join('\n\n---\n\n');

  const prompt = `You are an expert English exam content creator for Indonesian students.

Use the following reference materials to ensure accuracy:
---REFERENCE---
${ragContext}
---END REFERENCE---

Generate a ${params.cefr_level} level ${params.generation_type} for ${params.exam_type} exam preparation.
${params.topic ? `Topic: ${params.topic}` : ''}
${params.indonesian_context ? 'Include Indonesian cultural context where appropriate.' : ''}

Requirements:
- ${params.num_questions} questions
- Include detailed explanations for each answer
- Include answer key
- Match the official ${params.exam_type} question format exactly
- Difficulty: ${params.cefr_level}

Return as JSON:
{
  "passage": "..." (if reading),
  "audio_script": "..." (if listening),
  "questions": [
    {
      "id": 1,
      "type": "multiple_choice",
      "question": "...",
      "options": ["A", "B", "C", "D"],
      "answer": "B",
      "explanation": "..."
    }
  ],
  "answer_key": {...},
  "metadata": {
    "word_count": N,
    "cefr_level": "${params.cefr_level}",
    "estimated_time_min": N
  }
}`;

  // 4. Generate
  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' },
  });

  const generated = JSON.parse(response.choices[0].message.content);

  // 5. Validate (reuse EduBot's contentValidator pattern)
  const validation = await validateContent(generated, params.exam_type);

  return {
    generated_content: generated,
    rag_documents_used: ragResults.map(r => r.document_title),
    validation_status: validation.status,
    validation_notes: validation.notes,
  };
}
```

---

## 8. AI ENGINE SPECIFICATION

### Writing Grader

```typescript
// worker/src/services/ai-grading.ts

export async function gradeWriting(
  supabase: SupabaseClient,
  openai: OpenAI,
  params: {
    essay_text: string;
    exam_type: string;  // 'IELTS', 'TOEFL_IBT', 'TOEIC'
    rubric_type: string; // 'IELTS_WRITING_TASK2', 'TOEFL_IBT_INDEPENDENT', 'CUSTOM'
    rubric_config?: any;
    student_id: string;
  }
): Promise<GradingResult> {
  // 1. Retrieve rubric from RAG
  const rubricDocs = await ragSearch(supabase, openai,
    `${params.rubric_type} grading criteria rubric`,
    { category: 'rubrics', limit: 3 }
  );

  // 2. Retrieve Indonesian error patterns
  const errorDocs = await ragSearch(supabase, openai,
    'Indonesian English writing common errors grammar',
    { category: 'error_patterns', limit: 3 }
  );

  // 3. Build grading prompt
  const prompt = `You are an expert ${params.exam_type} writing examiner.

Use these official rubrics:
---RUBRIC---
${rubricDocs.map(d => d.chunk_text).join('\n\n')}
---END RUBRIC---

Common Indonesian learner errors to watch for:
---ERROR PATTERNS---
${errorDocs.map(d => d.chunk_text).join('\n\n')}
---END ERROR PATTERNS---

Grade the following student essay:

---ESSAY---
${params.essay_text}
---END ESSAY---

Return as JSON:
{
  "overall_band": 6.0,
  "scores": {
    "task_achievement": 6.0,
    "coherence_cohesion": 5.5,
    "lexical_resource": 6.0,
    "grammatical_range_accuracy": 6.5
  },
  "strengths": ["...", "..."],
  "weaknesses": ["...", "..."],
  "specific_feedback": [
    {
      "paragraph": 1,
      "issue": "Run-on sentence",
      "original": "...",
      "suggestion": "...",
      "category": "grammar"
    }
  ],
  "overall_feedback": "..."
}`;

  // 4. Grade
  const response = await openai.chat.completions.create({
    model: 'gpt-4o-mini',
    messages: [{ role: 'user', content: prompt }],
    response_format: { type: 'json_object' },
  });

  return JSON.parse(response.choices[0].message.content);
}
```

### Speaking Evaluator (bridges to EduBot)

```typescript
// worker/src/services/speaking-bridge.ts

export async function evaluateSpeaking(
  params: { audio_url: string; exam_type: string; task_type: string }
): Promise<SpeakingResult> {
  // Bridge to EduBot's existing speaking evaluation
  // EduBot already has: Whisper transcription + GPT-4 scoring + prosody analysis

  const edubotResponse = await fetch(`${EDUBOT_API_URL}/api/speaking/evaluate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Internal-Secret': EDUBOT_INTERNAL_SECRET,
    },
    body: JSON.stringify({
      audio_url: params.audio_url,
      test_type: params.exam_type,
      task_type: params.task_type,
    }),
  });

  const result = await edubotResponse.json();
  // Result includes: transcription, pronunciation_score, fluency_score,
  // lexical_resource_score, coherence_score, band_score, feedback

  return result;
}
```

---

## 9. COMMISSION SYSTEM

### Commission flow

```typescript
// worker/src/services/commission-engine.ts

export async function processWebhookCommission(
  supabase: SupabaseClient,
  event: {
    platform: string;
    event_type: string;
    user_email: string;
    score?: number;
    booking_amount?: number;
  }
) {
  // 1. Find student by email
  const { data: student } = await supabase
    .from('unified_profiles')
    .select('id')
    .eq('email', event.user_email)
    .single();

  if (!student) return; // student not in hub yet

  // 2. Find teacher referral
  const { data: referral } = await supabase
    .from('teacher_referrals')
    .select('*, teacher_profiles!inner(*)')
    .eq('student_id', student.id)
    .single();

  if (!referral) return; // no teacher referral — no commission

  // 3. Determine commission action
  const isAmbassador = referral.teacher_profiles.is_ambassador;

  switch (event.event_type) {
    case 'test_completed':
      if (!referral.first_test_completed_at) {
        const action = isAmbassador ? 'ambassador_first_test' : 'first_test';
        const rate = await getCommissionRate(supabase, action);
        await creditCommission(supabase, {
          teacher_id: referral.teacher_id,
          student_id: student.id,
          action,
          amount: rate,
        });
        await supabase
          .from('teacher_referrals')
          .update({ first_test_completed_at: new Date().toISOString(), first_test_commission: rate })
          .eq('id', referral.id);
      }
      break;

    case 'official_booking':
      const action = isAmbassador ? 'ambassador_booking' : 'official_booking';
      const rate = await getCommissionRate(supabase, action);
      await creditCommission(supabase, {
        teacher_id: referral.teacher_id,
        student_id: student.id,
        action,
        amount: rate,
        reference: event.booking_reference,
      });
      await supabase
        .from('teacher_referrals')
        .update({ official_test_booked_at: new Date().toISOString(), booking_commission: rate })
        .eq('id', referral.id);
      break;

    case 'premium_subscribed':
      const premAction = isAmbassador ? 'ambassador_premium_monthly' : 'premium_monthly';
      const premRate = await getCommissionRate(supabase, premAction);
      await creditCommission(supabase, {
        teacher_id: referral.teacher_id,
        student_id: student.id,
        action: premAction,
        amount: premRate,
      });
      await supabase
        .from('teacher_referrals')
        .update({
          premium_subscribed_at: new Date().toISOString(),
          premium_commission_monthly: premRate,
          premium_active: true,
        })
        .eq('id', referral.id);
      break;
  }

  // 4. Update teacher's total earnings
  await updateTeacherEarnings(supabase, referral.teacher_id);

  // 5. Award AI quota bonus to teacher
  await awardQuotaBonus(supabase, referral.teacher_id, event.event_type);
}
```

### AI quota bonus system

```typescript
export async function awardQuotaBonus(
  supabase: SupabaseClient,
  teacherId: string,
  eventType: string
) {
  const bonusMap: Record<string, { type: string; amount: number }> = {
    'student_registered': { type: 'generation', amount: 5 },
    'test_completed': { type: 'generation', amount: 5 },
    'official_booking': { type: 'generation', amount: 10 },
    'premium_subscribed': { type: 'generation', amount: 10 },
  };

  const bonus = bonusMap[eventType];
  if (!bonus) return;

  // Add to teacher's earned_bonus in ai_quota_usage
  await supabase.rpc('add_quota_bonus', {
    p_teacher_id: teacherId,
    p_quota_type: bonus.type,
    p_bonus: bonus.amount,
  });
}
```

---

## 10. VIDEO CONTENT SYSTEM

### Video production workflow

```
1. SCRIPT (30 min)
   → Teacher/creator decides topic
   → AI generates structured script outline
   → Creator refines with personal examples + Indonesian context
   → AI generates 5 comprehension questions for the video

2. RECORD (30 min)
   → Creator teaches on camera (phone/laptop)
   → Screen share for examples/slides
   → "Pause and try" interactive moments

3. EDIT (30 min)
   → AI auto-generates captions (Whisper)
   → Add title card, end screen, quiz overlay
   → Tools: CapCut (free) or DaVinci Resolve

4. PUBLISH (30 min)
   → Upload to R2 (premium access)
   → Upload teaser to YouTube (free preview / SEO)
   → Tutor Bot sends notification
   → Teacher portal: video available for assignment
```

### Video lesson data structure

```typescript
interface VideoLesson {
  id: string;
  course_id: string;
  lesson_number: number;
  title: string;
  section: string;           // 'reading', 'listening', etc.
  cefr_level: string;
  duration_seconds: number;

  video_url_r2: string;      // Cloudflare R2 URL (premium)
  youtube_id: string;        // YouTube (free preview)

  comprehension_questions: {
    q: string;
    options: string[];
    answer_idx: number;
    explanation: string;
    timestamp: string;       // "02:30" — when in video this applies
  }[];

  key_vocabulary: {
    word: string;
    definition: string;
    ipa: string;
  }[];

  practice_links: {
    platform: string;        // 'ibt', 'ielts', etc.
    url: string;             // deep link to practice
    label: string;
  }[];

  is_free_preview: boolean;
  is_published: boolean;
}
```

### Video production schedule (first 6 months)

```
MONTH 1-2: TOEFL ITP Course (20 lessons — highest priority)
  Week 1-2: Listening (5 lessons)
  Week 3-4: Structure (5 lessons)
  Week 5-6: Reading (5 lessons)
  Week 7-8: Practice + Review (5 lessons)

MONTH 3-4: IELTS Course (20-30 lessons)
  Focus: Writing (8) + Speaking (8) + Reading (6) + Listening (6)

MONTH 5-6: TOEFL iBT (15 lessons) + TOEIC (10 lessons)
  Cross-tag reusable content

Output: ~50-60 videos in 6 months
With cross-exam reuse: covers all 5 exams
```

---

## 11. LIVE CLASS INTEGRATION

### Implementation (extends EduBot)

```typescript
// EduBot: Add live class commands to webhook.ts

// /classes — show upcoming classes
bot.command('classes', async (ctx) => {
  const classes = await fetch(`${HUB_API_URL}/api/classes/upcoming`).then(r => r.json());

  const keyboard = classes.map(c => [{
    text: `📅 ${c.title} — ${formatDate(c.scheduled_at)}`,
    callback_data: `class_${c.id}`
  }]);

  await ctx.reply('📚 Upcoming Live Classes:\n\n' +
    classes.map(c => `• ${c.title}\n  ${formatDate(c.scheduled_at)} WIB\n  📝 ${c.description}`).join('\n\n'),
    { reply_markup: { inline_keyboard: keyboard } }
  );
});

// Callback: class selected → show Zoom link
bot.action(/class_(.+)/, async (ctx) => {
  const classId = ctx.match[1];
  const cls = await fetch(`${HUB_API_URL}/api/classes/${classId}`).then(r => r.json());

  await ctx.reply(
    `📅 ${cls.title}\n\n` +
    `⏰ ${formatDate(cls.scheduled_at)} WIB\n` +
    `⏱ Duration: ${cls.duration_minutes} minutes\n\n` +
    `🔗 Join Zoom:\n${cls.zoom_link}\n\n` +
    `📖 Description: ${cls.description}`
  );
});

// Cron: 1 hour before class → send reminder
// Already handled by EduBot's cron system — add a new cron check
```

### Hub: Live class management

```typescript
// Hub API: /api/classes/*
// Admin creates classes via simple form:
//   title, description, scheduled_at, zoom_link, duration_minutes

// Hub stores in live_classes table
// EduBot reads from Hub API
// Students get notifications via Telegram

// Post-class:
//   Admin uploads recording URL
//   Hub updates live_classes.recording_url
//   Tutor Bot sends: "Today's class recording: [url]"
//   Recording added to video library (if reusable)
```

---

## 12. BUILD PHASES

### Phase 1: Foundation (Week 1-3)

```
Week 1: Database + Auth
  Task 1.1: Create Supabase project + run schema SQL
  Task 1.2: Set up Cloudflare Workers project (hub/)
  Task 1.3: Implement auth routes (register, login, verify, refresh, logout)
  Task 1.4: Set SSO cookie (domain: .osee.co.id)
  Task 1.5: Build registration page with referral code support
  Task 1.6: Build login page
  Task 1.7: Implement auth guard router (role-based: teacher/student/admin)

Week 2: Teacher Portal MVP
  Task 2.1: Teacher dashboard page (stats overview)
  Task 2.2: Classroom creation + join code generation
  Task 2.3: Student registration via referral link (/r/CODE)
  Task 2.4: Classroom enrollment system
  Task 2.5: OSEE branding widget component
  Task 2.6: Tutor Bot link component (floating CTA)

Week 3: Webhook System
  Task 3.1: Webhook receiver endpoints (ibt, itp, iels, toeic, booking, edubot)
  Task 3.2: Webhook event processing pipeline
  Task 3.3: Student progress unified table updates
  Task 3.4: Commission trigger on webhook events
  Task 3.5: Webhook secret authentication
```

### Phase 2: AI Engine (Week 4-7)

```
Week 4: RAG Knowledge Base
  Task 4.1: Set up pgvector extension in Supabase
  Task 4.2: Create document ingestion script
  Task 4.3: Ingest Tier 1 materials (CEFR descriptors, Kurikulum Merdeka, ETS specs)
  Task 4.4: Ingest EduBot error pattern data
  Task 4.5: Implement vector search function (match_documents)
  Task 4.6: Build RAG search API endpoint

Week 5: AI Writing Grader
  Task 5.1: Implement gradeWriting service (GPT-4o-mini + RAG)
  Task 5.2: Grading queue system (pending → processing → completed)
  Task 5.3: AI grader UI page (upload essay, select rubric, view results)
  Task 5.4: Quota checking (free: 50/month, pro: unlimited)
  Task 5.5: Store results in ai_grading_queue table
  Task 5.6: Bridge to EduBot's existing writing route (alternative)

Week 6: AI Material Generator
  Task 6.1: Implement generateMaterial service (GPT-4o-mini + RAG)
  Task 6.2: Generation queue system
  Task 6.3: Material generator UI page (type, exam, level, topic, options)
  Task 6.4: Content validation pipeline (reuse EduBot's contentValidator)
  Task 6.5: Generated material preview + add to syllabus
  Task 6.6: Quota checking (free: 10/month)

Week 7: AI Speaking Evaluator
  Task 7.1: Bridge to EduBot's speaking evaluation (Whisper + GPT)
  Task 7.2: Speaking grader UI (record audio, submit, view results)
  Task 7.3: R2 audio upload pipeline
  Task 7.4: Quota checking
```

### Phase 3: Reports + Syllabus (Week 8-11)

```
Week 8: Student Reports
  Task 8.1: Implement report generation service
  Task 8.2: Student report PDF template (with teacher branding + OSEE footer)
  Task 8.3: Report viewer page
  Task 8.4: Batch report generation (all students in classroom)
  Task 8.5: Report download/email feature

Week 9: Classroom Reports
  Task 9.1: Classroom report aggregation service
  Task 9.2: Classroom report PDF template
  Task 9.3: Weakness heatmap visualization
  Task 9.4: Teacher effectiveness metrics

Week 10: Syllabus Builder
  Task 10.1: Material library component (left column)
  Task 10.2: Syllabus timeline component (right column)
  Task 10.3: Drag-and-drop implementation (@dnd-kit)
  Task 10.4: Batch save (PUT syllabus items)
  Task 10.5: Material browser from all platforms (via platform bridge API)
  Task 10.6: AI-generated materials integration (from Phase 2)

Week 11: Student Portal
  Task 11.1: Student dashboard (syllabus, progress, readiness)
  Task 11.2: Syllabus view page (with deep links to practice platforms)
  Task 11.3: Progress tracking page
  Task 11.4: Readiness gauge component
  Task 11.5: Cross-exam score map component
  Task 11.6: Contextual "Book Official Test" CTA (only when readiness > 80%)
```

### Phase 4: Commission + Video (Week 12-15)

```
Week 12: Commission System
  Task 12.1: Commission dashboard page (earnings, breakdown, history)
  Task 12.2: Payout request system
  Task 12.3: Payout tracking (pending → confirmed → paid)
  Task 12.4: AI quota bonus system (earn generations by bringing students)
  Task 12.5: Ambassador program (2x rates, badge, featured)

Week 13: Video Content System
  Task 13.1: Video course management (admin)
  Task 13.2: Video lesson player (with comprehension quiz overlay)
  Task 13.3: Video progress tracking
  Task 13.4: Video course library page (student)
  Task 13.5: Free preview (YouTube) vs premium (R2) gating
  Task 13.6: Teacher can assign video lessons to syllabus

Week 14: Live Class Integration
  Task 14.1: Live class management (admin form)
  Task 14.2: Upcoming classes page (student)
  Task 14.3: EduBot integration (Zoom link sharing via Telegram)
  Task 14.4: Auto-reminder cron (1 hour before class)
  Task 14.5: Post-class recording upload + notification

Week 15: White-Label + Pro Tier
  Task 15.1: Branding config system
  Task 15.2: Pro tier upgrade page + payment
  Task 15.3: Institution tier (custom subdomain, multi-teacher)
  Task 15.4: OSEE branding hide/show logic (free = visible, pro = hideable)
```

### Phase 5: Ecosystem Integration (Week 16-18)

```
Week 16: EduBot Bridge
  Task 16.1: Link Telegram account to OSEE account
  Task 16.2: EduBot reads student progress from Hub API
  Task 16.3: EduBot deep-links students to practice platforms
  Task 16.4: EduBot knows teacher's syllabus → tutors on those topics
  Task 16.5: EduBot reports progress back to Hub

Week 17: Ambassador Program + Launch
  Task 17.1: Ambassador recruitment page
  Task 17.2: Ambassador dashboard (recruited teachers, bonuses)
  Task 17.3: Teacher proposal document (PDF template)
  Task 17.4: Landing page (prep.osee.co.id)
  Task 17.5: SEO optimization (osee.co.id blog integration)

Week 18: Polish + Deploy
  Task 18.1: Error handling + logging
  Task 18.2: Performance optimization (caching, CDN)
  Task 18.3: Mobile responsiveness
  Task 18.4: Analytics dashboard (admin)
  Task 18.5: Deploy to production (Cloudflare Pages + Workers)
```

---

## 13. FOLDER STRUCTURE

### Complete project structure

```
osee-edubot/                     # Existing repo (keep as-is)
├── worker/                       # Existing EduBot Workers
├── frontend/                     # Existing EduBot React app
├── ...

osee-prep-hub/                    # NEW repo for the Hub
├── worker/                       # Cloudflare Workers (Hub API)
│   ├── src/
│   │   ├── index.ts              # Main entry + route registration
│   │   ├── types.ts              # TypeScript interfaces
│   │   │
│   │   ├── routes/
│   │   │   ├── auth.ts           # Auth + SSO
│   │   │   ├── teacher.ts        # Teacher portal API
│   │   │   ├── student.ts        # Student portal API
│   │   │   ├── ai.ts             # AI grading + generation
│   │   │   ├── commission.ts     # Commission + payouts
│   │   │   ├── webhook.ts        # Webhook receivers
│   │   │   ├── video.ts          # Video content
│   │   │   ├── classes.ts        # Live classes
│   │   │   ├── syllabus.ts       # Syllabus builder
│   │   │   ├── reports.ts        # Report generation
│   │   │   ├── platform.ts       # Cross-platform bridge
│   │   │   └── admin.ts          # Admin API
│   │   │
│   │   ├── services/
│   │   │   ├── supabase.ts       # Supabase client
│   │   │   ├── jwt.ts            # JWT utilities
│   │   │   ├── rag-search.ts     # RAG vector search
│   │   │   ├── ai-grading.ts     # Writing/speaking grading
│   │   │   ├── ai-generation.ts  # Material generation
│   │   │   ├── commission.ts     # Commission engine
│   │   │   ├── quota.ts          # AI quota management
│   │   │   ├── reports.ts        # Report generation
│   │   │   ├── pdf.ts            # PDF generation
│   │   │   ├── edubot-bridge.ts  # Calls EduBot API
│   │   │   ├── webhook-processor.ts # Webhook event processing
│   │   │   └── branding.ts       # White-label branding
│   │   │
│   │   └── middleware/
│   │       ├── auth.ts           # JWT verification middleware
│   │       ├── quota.ts          # Quota checking middleware
│   │       └── cors.ts           # CORS configuration
│   │
│   ├── wrangler.toml             # Cloudflare Workers config
│   ├── package.json
│   └── tsconfig.json
│
├── frontend/                     # React/Vite (Hub frontend)
│   ├── src/
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   ├── api/                  # API client layer
│   │   ├── stores/               # Zustand stores
│   │   ├── components/           # Reusable UI
│   │   ├── pages/                # Route pages
│   │   │   ├── Landing.tsx
│   │   │   ├── Login.tsx
│   │   │   ├── Register.tsx
│   │   │   ├── RegisterViaReferral.tsx
│   │   │   ├── teacher/
│   │   │   ├── student/
│   │   │   └── admin/
│   │   ├── hooks/
│   │   ├── types/
│   │   └── utils/
│   ├── index.html
│   ├── vite.config.ts
│   ├── tailwind.config.js
│   └── package.json
│
├── scripts/                      # Utility scripts
│   ├── ingest-knowledge-base.ts  # RAG document ingestion
│   ├── seed-commission-rates.ts  # Seed commission rates
│   ├── seed-cross-exam-map.ts    # Seed cross-exam score map
│   └── migrate-edubot-users.ts   # Migrate EduBot users to unified_profiles
│
├── docs/                         # Documentation
│   ├── API.md                    # API reference
│   ├── DEPLOYMENT.md             # Deployment guide
│   ├── COMMISSION.md             # Commission system docs
│   └── AMBASSADOR.md             # Ambassador program guide
│
├── schema.sql                    # Supabase schema (full SQL)
├── wrangler.toml                 # Workers config
├── package.json
├── turbo.json                    # Monorepo config (optional)
└── README.md
```

---

## 14. ENVIRONMENT VARIABLES

### Hub Workers (.env / wrangler secrets)

```bash
# Supabase
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=xxx
SUPABASE_SERVICE_KEY=xxx

# JWT
JWT_SECRET=xxx
JWT_EXPIRY=7d

# OpenAI
OPENAI_API_KEY=xxx

# Cloudflare
CF_ACCOUNT_ID=xxx
CF_API_TOKEN=xxx

# EduBot bridge
EDUBOT_API_URL=https://edubot-webapp.pages.dev
EDUBOT_INTERNAL_SECRET=xxx

# Webhook secrets (shared with each practice platform)
WEBHOOK_SECRET_IBT=xxx
WEBHOOK_SECRET_ITP=xxx
WEBHOOK_SECRET_IELTS=xxx
WEBHOOK_SECRET_TOEIC=xxx
WEBHOOK_SECRET_BOOKING=xxx
WEBHOOK_SECRET_EDUBOT=xxx

# Frontend
WEBAPP_URL=https://prep.osee.co.id

# Cloudflare R2 (video + audio storage)
R2_BUCKET_VIDEOS=osee-videos
R2_BUCKET_AUDIO=osee-audio
R2_ACCOUNT_ID=xxx
R2_ACCESS_KEY_ID=xxx
R2_SECRET_ACCESS_KEY=xxx

# Payment (TriPay — reuse EduBot's)
TRIPAY_API_KEY=xxx
TRIPAY_PRIVATE_KEY=xxx
TRIPAY_MERCHANT_CODE=xxx

# Telegram (for EduBot bridge — live class notifications)
TELEGRAM_BOT_TOKEN=xxx
TELEGRAM_CHANNEL_ID=-1003884450070

# Environment
ENVIRONMENT=production
```

### Frontend (.env)

```bash
VITE_API_URL=https://prep.osee.co.id/api
VITE_EDUBOT_URL=https://t.me/osee_edubot
VITE_OSEE_BOOKING_URL=https://osee.co.id
VITE_IBT_URL=https://ibt.osee.co.id
VITE_ITP_URL=https://test.osee.co.id
VITE_IELTS_URL=https://ielts.osee.co.id
VITE_TOEIC_URL=https://toeic.osee.co.id
```

---

## 15. DEPLOYMENT

### Cloudflare Workers (Hub API)

```bash
# Install wrangler
npm install -g wrangler

# Login
wrangler login

# Create D1 database (if using D1 for Hub — alternative to Supabase)
# NOTE: Using Supabase for Hub database, not D1

# Deploy Workers
cd osee-prep-hub/worker
wrangler deploy

# Set secrets
wrangler secret put SUPABASE_URL
wrangler secret put SUPABASE_SERVICE_KEY
wrangler secret put JWT_SECRET
wrangler secret put OPENAI_API_KEY
# ... (all env vars from section 14)
```

### Cloudflare Pages (Hub Frontend)

```bash
cd osee-prep-hub/frontend
npm run build
wrangler pages deploy dist --project-name=osee-prep-hub
```

### Supabase

```bash
# Create project at supabase.com
# Run schema SQL in SQL editor
# Enable pgvector extension
# Set up RLS policies (included in schema)
# Create storage buckets for video/audio if needed
```

### Custom domain setup

```
prep.osee.co.id → Cloudflare Pages (frontend)
                  Cloudflare Workers (API: /api/*)

DNS:
  prep.osee.co.id    CNAME   osee-prep-hub.pages.dev
  prep.osee.co.id    A       (Cloudflare Workers IP for /api/*)

Cookie domain: .osee.co.id (shared across all subdomains)
```

### Webhook setup on existing platforms

```
For each practice platform (ibt, itp, ielts, toeic):
  1. Add webhook secret to their environment
  2. Add webhook call on test completion:
     POST https://prep.osee.co.id/api/webhook/{platform}
     Headers: X-Webhook-Secret: {secret}
     Body: { event, user_email, score, section_scores, ... }

For osee.co.id:
  1. Add webhook on booking confirmation:
     POST https://prep.osee.co.id/api/webhook/booking
     Body: { event: 'official_booking', user_email, test_type, booking_amount, ... }

For EduBot:
  1. Add webhook on premium subscription:
     POST https://prep.osee.co.id/api/webhook/edubot
     Body: { event: 'premium_subscribed', telegram_id, ... }
```

---

## APPENDIX A: AI QUOTA EARNING MECHANICS

```
FREE TIER QUOTAS:
  Grading:     50 credits/month (essays or speaking evaluations)
  Generation:  10 credits/month (material generation)
  Reports:     10 credits/month (student/classroom reports)

EARN MORE BY BRINGING STUDENTS:
  +5 generation credits per student who registers via referral code
  +5 generation credits per student who completes first practice test
  +10 generation credits per student who books official test
  +10 generation credits per student who subscribes to EduBot premium

EXAMPLE:
  Teacher with 20 students who all complete tests:
  10 (base) + 20×5 (registrations) + 20×5 (first tests) = 210 generation credits/month
  Teacher with 50 students:
  10 + 50×5 + 50×5 = 510 generation credits/month

PRO TIER (Rp 50k/month):
  Unlimited grading, generation, reports
  Classroom reports
  Custom branding (hide OSEE logo)

INSTITUTION TIER (Rp 200k-500k/month):
  Everything in Pro
  Custom subdomain
  Multi-teacher (multiple teacher accounts under one institution)
  Admin dashboard for school administrator
  White-label completely
```

---

## APPENDIX B: AMBASSADOR PROGRAM

```
WHO: 20 founding teachers, recruited manually
WHAT: Enhanced commission + unlimited AI + featured status

AMBASSADOR BENEFITS:
  ✓ Unlimited AI grading + generation (no quota)
  ✓ 2x commission rate (Rp 20k per first test, Rp 100k per booking, Rp 30k/month premium)
  ✓ "OSEE Certified Educator" badge on profile + reports
  ✓ Featured on OSEE social media + website
  ✓ Early access to new features
  ✓ Free Pro tier for life

AMBASSADOR OBLIGATIONS:
  📋 Use platform with their students (real usage)
  📋 Post about it on Instagram/TikTok (at least 1x/month)
  📋 Recruit 5 other teachers in first 3 months
  📋 Provide weekly feedback

RECRUITMENT:
  Target: English teachers with 100+ students, active on social media
  Channels: Instagram (#gurubahasainggris, #lestofl, #persiapanielts),
            Facebook groups (Guru Bahasa Inggris Indonesia),
            TikTok English teacher creators,
            EduBot channel followers who are teachers
```

---

## APPENDIX C: TEACHER PROPOSAL DOCUMENT TEMPLATE

```
OSEE TEACHER PARTNER PROGRAM
"AI tools + income for English teachers in Indonesia"

WHAT YOU GET (FREE):
  ✓ AI writing grader — grade 50 essays in 4 minutes, not 10 hours
  ✓ AI material generator — create worksheets, quizzes, passages in seconds
  ✓ AI speaking evaluator — students record, AI scores pronunciation + fluency
  ✓ Drag-and-drop syllabus builder
  ✓ Student management + progress tracking
  ✓ Printable student reports (branded with your name)
  ✓ Classroom analytics dashboard
  ✓ Cross-exam support (TOEFL iBT, IELTS, TOEIC, ITP)
  ✓ Your own referral code for students
  ✓ Tutor Bot link for your students (AI chat tutor in Telegram)
  ✓ Free live classes via Zoom (shared through Tutor Bot)
  ✓ Free video lessons (growing library)

WHAT YOU EARN:
  • Rp 10,000 per student who completes first practice test
  • Rp 50,000 per student who books official test at OSEE
  • Rp 15,000/month per student on EduBot premium (recurring)
  • Rp 25,000 per student who buys a practice package
  • Example: 30 students → Rp 500k-1.5juta/month

WHY OSEE:
  • Official ETS Test Center since 2014
  • 5 practice platforms (TOEFL iBT, IELTS, TOEIC, ITP + AI Tutor Bot)
  • Trusted by IIEF and ITC
  • AI trained on Indonesian-accented English
  • Materials validated for quality
  • Works on low-end Android with slow internet

HOW TO START:
  1. Register at prep.osee.co.id/teacher (free, 2 minutes)
  2. Create a classroom
  3. Share your referral code with students
  4. Build your syllabus (AI can help generate materials)
  5. Track progress + earn commission

EARN MORE AI CREDITS:
  +5 credits per student who registers
  +5 credits per student who completes a test
  +10 credits per student who books an official test
  (Or upgrade to Pro: Rp 50k/month for unlimited everything)

Contact: [WhatsApp/Telegram/Email]
Demo: [Calendly link for 15-min walkthrough]
```

---

**END OF BLUEPRINT**

This document is self-contained. Hand it to OpenCode or Claude Code and say:

> "Build the OSEE Education Hub according to this blueprint. Start with Phase 1, Week 1, Task 1.1. Follow each task in order. Commit after every task. Do not skip ahead."

The blueprint is designed so each phase is independently deployable and testable. You can launch after Phase 2 (AI engine) with just the writing grader as a standalone tool, then expand.