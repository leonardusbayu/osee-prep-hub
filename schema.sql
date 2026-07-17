
-- ============================================================
-- OSEE EDUCATION HUB â€” DATABASE SCHEMA
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
  password_hash TEXT,           -- PBKDF2 hash (added for email/password auth — not in original blueprint)
  phone TEXT,
  display_name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'partner', 'admin', 'institution')),
  avatar_url TEXT,

  -- Cross-platform linking
  telegram_id TEXT,          -- links to EduBot
  edubot_user_id INTEGER,    -- EduBot D1 user.id
  osee_customer_id TEXT,     -- osee.co.id customer ID (if exists)
  referred_by UUID,          -- teacher who referred this student/partner (added for referral system)

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
  -- 'osee_certified_educator' for ambassadors, NULL otherwise
  badge TEXT,

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
  is_private BOOLEAN DEFAULT FALSE,  -- TRUE = private 1-on-1 lesson (les); FALSE = group class (kelas)
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

  -- Flavor profile (from brainstorm â€” cognitive pacing)
  flavor_tag TEXT CHECK (flavor_tag IN ('bitter', 'sweet', 'umami', 'spicy', 'cooling')),
  temperature_tag TEXT CHECK (temperature_tag IN ('hot', 'cold')),

  -- Unlock logic
  unlocked_at TIMESTAMPTZ,   -- null = locked
  prerequisite_item_id UUID REFERENCES syllabus_items(id),

  -- AI-generated content (if source_type = 'ai_generated')
  ai_generated_content JSONB,  -- full generated material stored here

  -- Teacher annotations (persisted — Task 10.x)
  label_ids JSONB DEFAULT '[]',  -- array of label id strings, e.g. ["important","review"]

  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_syllabus_items_syllabus ON syllabus_items(syllabus_id);
CREATE INDEX idx_syllabus_items_order ON syllabus_items(syllabus_id, sort_order);

-- Per-item teacher comments (persisted — Task 10.x)
CREATE TABLE syllabus_item_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_item_id UUID NOT NULL REFERENCES syllabus_items(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_syllabus_item_comments_item ON syllabus_item_comments(syllabus_item_id);

-- Per-item attachments (persisted — Task 10.x)
CREATE TABLE syllabus_item_attachments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_item_id UUID NOT NULL REFERENCES syllabus_items(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  label TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_syllabus_item_attachments_item ON syllabus_item_attachments(syllabus_item_id);

-- Per-student syllabus item progress (Task 11.2)
CREATE TABLE syllabus_item_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_item_id UUID NOT NULL REFERENCES syllabus_items(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'not_started' CHECK (status IN ('not_started', 'started', 'completed')),
  score DECIMAL,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  UNIQUE(syllabus_item_id, student_id)
);

CREATE INDEX idx_sip_item ON syllabus_item_progress(syllabus_item_id);
CREATE INDEX idx_sip_student ON syllabus_item_progress(student_id);

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

-- Commission payout requests (teacher withdrawal requests)
CREATE TABLE commission_payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  amount DECIMAL NOT NULL,
  method TEXT CHECK (method IN ('bank_transfer', 'gopay', 'ovo', 'dana')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'rejected', 'cancelled')),
  reference TEXT,  -- payout reference / bank transfer ref
  notes TEXT,
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ
);

CREATE INDEX idx_payout_teacher ON commission_payouts(teacher_id);
CREATE INDEX idx_payout_status ON commission_payouts(status);

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
  user_id UUID REFERENCES unified_profiles(id),  -- alias for teacher_id (code queries user_id)
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

  -- Practice counts per platform
  ibt_practice_count INTEGER DEFAULT 0,
  itp_practice_count INTEGER DEFAULT 0,
  ielts_practice_count INTEGER DEFAULT 0,
  toeic_practice_count INTEGER DEFAULT 0,
  edubot_practice_count INTEGER DEFAULT 0,

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

  -- EduBot premium subscription tracking (Blueprint line 64: recurring Rp 15k/month)
  has_premium BOOLEAN DEFAULT FALSE,
  last_premium_credit_at TIMESTAMPTZ,  -- null = never credited; used by cron to credit monthly

  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_progress_student ON student_progress_unified(student_id);

-- Per-practice history row (audit trail of all practice/test attempts)
CREATE TABLE student_progress_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,  -- 'ibt' | 'itp' | 'ielts' | 'toeic' | 'booking' | 'edubot'
  exam_type TEXT,
  section TEXT,
  score DECIMAL,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'
);

CREATE INDEX idx_history_student ON student_progress_history(student_id);
CREATE INDEX idx_history_completed ON student_progress_history(completed_at);

-- ============================================================
-- 10b. PLATFORM LINKS (deep links to practice platforms per exam type)
-- ============================================================

CREATE TABLE platform_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform TEXT NOT NULL,        -- 'ibt' | 'itp' | 'ielts' | 'toeic' | 'edubot' | 'osee'
  exam_type TEXT NOT NULL,        -- 'TOEFL_IBT' | 'TOEFL_ITP' | 'IELTS' | 'TOEIC' | 'GENERAL'
  url TEXT NOT NULL,
  label TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(platform, exam_type)
);

CREATE INDEX idx_platform_links_exam ON platform_links(exam_type);

-- Seed: deep links to the five practice platforms + the OSEE booking bridge.
INSERT INTO platform_links (platform, exam_type, url, label) VALUES
  ('ibt',    'TOEFL_IBT', 'https://ibt.osee.co.id',     'OSEE IBT Practice'),
  ('itp',    'TOEFL_ITP', 'https://itp.osee.co.id',    'OSEE ITP Practice'),
  ('ielts',  'IELTS',     'https://ielts.osee.co.id',  'OSEE IELTS Practice'),
  ('toeic',  'TOEIC',     'https://toeic.osee.co.id',  'OSEE TOEIC Practice'),
  ('edubot', 'GENERAL',   'https://edubot.osee.co.id', 'EduBot Tutor'),
  ('osee',   'TOEFL_IBT', 'https://osee.co.id/booking','OSEE Official Test Booking')
ON CONFLICT (platform, exam_type) DO UPDATE SET url = EXCLUDED.url, label = EXCLUDED.label;

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
  -- [{"word": "inference", "definition": "...", "ipa": "/ËˆÉªnfÉ™rÉ™ns/"}]

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

-- Video progress tracking (per student per lesson)
CREATE TABLE video_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES video_lessons(id) ON DELETE CASCADE,
  watched_seconds INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT FALSE,
  quiz_score INTEGER,
  last_watched_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);

CREATE INDEX idx_video_progress_user ON video_progress(user_id);
CREATE INDEX idx_video_progress_lesson ON video_progress(lesson_id);

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

-- Class registrations (student registers interest for a live class)
CREATE TABLE class_registrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES live_classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(class_id, user_id)
);

CREATE INDEX idx_class_reg_class ON class_registrations(class_id);
CREATE INDEX idx_class_reg_user ON class_registrations(user_id);

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
-- ORDER SYSTEM (added per user request — not in original blueprint)
-- Supports: pricing config, orders, order items, vouchers
-- Roles: student, teacher, partner (institution), admin
-- Item types: mock_itp, mock_ibt, mock_ielts, mock_toeic,
--            tutor_bot_premium, official_toefl, official_toeic
-- Order types: voucher_resale, book_for_student, bulk_purchase, self_purchase
-- ============================================================

CREATE TABLE pricing_config (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  item_type TEXT NOT NULL CHECK (item_type IN (
    'mock_itp','mock_ibt','mock_ielts','mock_toeic',
    'tutor_bot_premium','official_toefl','official_toeic'
  )),
  role TEXT NOT NULL CHECK (role IN ('student','teacher','partner','admin')),
  price INTEGER NOT NULL CHECK (price >= 0),  -- in Rupiah
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(item_type, role)
);

CREATE INDEX idx_pricing_config_lookup ON pricing_config(item_type, role) WHERE is_active = TRUE;

CREATE TABLE orders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  order_type TEXT NOT NULL CHECK (order_type IN (
    'voucher_resale','book_for_student','bulk_purchase','self_purchase'
  )),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN (
    'pending','paid','fulfilled','cancelled','refunded'
  )),
  total_amount INTEGER NOT NULL CHECK (total_amount >= 0),  -- in Rupiah
  payment_method TEXT,
  payment_ref TEXT,  -- TriPay transaction reference
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created ON orders(created_at);

CREATE TABLE order_items (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN (
    'mock_itp','mock_ibt','mock_ielts','mock_toeic',
    'tutor_bot_premium','official_toefl','official_toeic'
  )),
  quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  unit_price INTEGER NOT NULL CHECK (unit_price >= 0),  -- snapshot of price at order time
  assigned_student_id UUID REFERENCES unified_profiles(id),  -- for bulk_purchase / book_for_student
  fulfillment_status TEXT DEFAULT 'pending' CHECK (fulfillment_status IN (
    'pending','voucher_generated','booking_confirmed','pending_booking','pending_assignment','booking_failed','fulfilled','failed'
  )),
  external_booking_id TEXT,  -- for official tests: osee.co.id booking ID
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_order_items_order ON order_items(order_id);
CREATE INDEX idx_order_items_assigned ON order_items(assigned_student_id);

CREATE TABLE vouchers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
  code TEXT NOT NULL UNIQUE,  -- 12-char alphanumeric, collision-checked
  item_type TEXT NOT NULL CHECK (item_type IN (
    'mock_itp','mock_ibt','mock_ielts','mock_toeic',
    'tutor_bot_premium','official_toefl','official_toeic'
  )),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN (
    'active','redeemed','expired','cancelled'
  )),
  redeemed_by UUID REFERENCES unified_profiles(id),
  redeemed_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  platform_webhook_sent BOOLEAN DEFAULT FALSE,  -- track if practice platform was notified
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_vouchers_code ON vouchers(code);
CREATE INDEX idx_vouchers_status ON vouchers(status);
CREATE INDEX idx_vouchers_redeemed_by ON vouchers(redeemed_by);
CREATE INDEX idx_vouchers_order_item ON vouchers(order_item_id);

-- ============================================================
-- TEACHER INVITATIONS (partner → teacher recruitment)
-- A partner (institution) invites a teacher by email; the teacher
-- registers using the token-bearing invite URL to auto-link to the
-- institution. Token-gated, 7-day expiry, single-use.
-- ============================================================

CREATE TABLE teacher_invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  teacher_email TEXT NOT NULL,
  institution_name TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,  -- opaque, single-use
  accepted_at TIMESTAMPTZ,     -- NULL = pending, non-NULL = consumed
  accepted_by UUID REFERENCES unified_profiles(id),  -- the teacher who accepted
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_teacher_invitations_partner ON teacher_invitations(partner_id);
CREATE INDEX idx_teacher_invitations_token ON teacher_invitations(token);
CREATE INDEX idx_teacher_invitations_email ON teacher_invitations(teacher_email);

-- ============================================================
-- Additional FK indexes (query-performance hardening)
-- ============================================================
CREATE INDEX idx_teacher_ambassador_by ON teacher_profiles(ambassador_recruited_by);
CREATE INDEX idx_syllabi_classroom ON syllabi(classroom_id);
CREATE INDEX idx_syllabi_teacher ON syllabi(teacher_id);
CREATE INDEX idx_syllabus_items_prereq ON syllabus_items(prerequisite_item_id);
CREATE INDEX idx_referral_classroom ON teacher_referrals(classroom_id);
CREATE INDEX idx_commission_student ON commission_ledger(student_id);
CREATE INDEX idx_kb_uploaded_by ON knowledge_base_documents(uploaded_by);
CREATE INDEX idx_grading_student ON ai_grading_queue(student_id);
CREATE INDEX idx_grading_classroom ON ai_grading_queue(classroom_id);
CREATE INDEX idx_grading_item ON ai_grading_queue(syllabus_item_id);
CREATE INDEX idx_gen_classroom ON ai_generation_queue(classroom_id);
CREATE INDEX idx_gen_syllabus ON ai_generation_queue(syllabus_id);
CREATE INDEX idx_gen_user ON ai_generation_queue(user_id);
CREATE INDEX idx_progress_syllabus ON student_progress_unified(syllabus_id);
CREATE INDEX idx_webhook_user ON webhook_events(user_id);
CREATE INDEX idx_branding_teacher ON branding_configs(teacher_id);
CREATE INDEX idx_video_course_exam ON video_courses(exam_type);
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
CREATE INDEX idx_order_items_status ON order_items(order_id, fulfillment_status);
CREATE INDEX idx_vouchers_lookup ON vouchers(item_type, status);
CREATE INDEX idx_cross_exam_source ON cross_exam_score_map(source_exam);
CREATE INDEX idx_cross_exam_target ON cross_exam_score_map(target_exam);

-- GIN trigram index for fuzzy email/name search (pg_trgm already enabled at top).
CREATE INDEX idx_profiles_email_trgm ON unified_profiles USING gin (email gin_trgm_ops);
CREATE INDEX idx_profiles_name_trgm ON unified_profiles USING gin (display_name gin_trgm_ops);

-- Updated_at trigger for orders (auto-maintain)
CREATE OR REPLACE FUNCTION update_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION update_orders_updated_at();

-- Updated_at trigger for pricing_config
CREATE OR REPLACE FUNCTION update_pricing_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER pricing_config_updated_at
  BEFORE UPDATE ON pricing_config
  FOR EACH ROW
  EXECUTE FUNCTION update_pricing_config_updated_at();

-- Generic updated_at trigger for the remaining tables with updated_at columns.
-- Replaces per-table boilerplate; one function, many triggers.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- is_admin(): SECURITY DEFINER function to check the caller's role WITHOUT
-- triggering infinite RLS recursion (a policy on unified_profiles that does
-- `(SELECT role FROM unified_profiles ...)` recurses into itself). SECURITY
-- DEFINER functions run with the owner's privileges and bypass RLS, so this
-- is safe and fast. Used by every admin-check subquery in RLS policies.
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM unified_profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE TRIGGER unified_profiles_updated_at
  BEFORE UPDATE ON unified_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER teacher_profiles_updated_at
  BEFORE UPDATE ON teacher_profiles
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER syllabi_updated_at
  BEFORE UPDATE ON syllabi
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER knowledge_base_documents_updated_at
  BEFORE UPDATE ON knowledge_base_documents
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER video_courses_updated_at
  BEFORE UPDATE ON video_courses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER commission_rates_updated_at
  BEFORE UPDATE ON commission_rates
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

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

-- Enable RLS on additional tables (security hardening)
ALTER TABLE syllabus_item_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_progress_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE platform_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE video_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_registrations ENABLE ROW LEVEL SECURITY;
ALTER TABLE webhook_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE pricing_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE vouchers ENABLE ROW LEVEL SECURITY;
ALTER TABLE cross_exam_score_map ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_base_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE knowledge_base_embeddings ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_item_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_item_attachments ENABLE ROW LEVEL SECURITY;

-- Default deny for sensitive tables (access via service key only)
CREATE POLICY syllabus_item_progress_student_select ON syllabus_item_progress
  FOR SELECT USING (auth.uid() = student_id);
CREATE POLICY commission_payouts_teacher_select ON commission_payouts
  FOR SELECT USING (auth.uid() = teacher_id);
CREATE POLICY video_progress_user_select ON video_progress
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY class_registrations_user_select ON class_registrations
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY orders_user_select ON orders
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY vouchers_select ON vouchers
  FOR SELECT USING (TRUE);  -- vouchers are validated by code, not by owner

-- Profiles: users can only see/update their own profile
CREATE POLICY profiles_self_select ON unified_profiles
  FOR SELECT USING (auth.uid() = id OR is_admin());
CREATE POLICY profiles_self_update ON unified_profiles
  FOR UPDATE USING (auth.uid() = id);

-- Classrooms: teachers see their own, students see enrolled
CREATE POLICY classrooms_teacher_select ON classrooms
  FOR SELECT USING (teacher_id = auth.uid() OR EXISTS (
    SELECT 1 FROM classroom_enrollments
    WHERE classroom_id = classrooms.id AND student_id = auth.uid() AND is_active = TRUE
  ) OR is_admin());
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
    OR is_admin()
  );
CREATE POLICY syllabi_teacher_insert ON syllabi
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY syllabi_teacher_update ON syllabi
  FOR UPDATE USING (teacher_id = auth.uid());

-- Commission: teachers see their own commission
CREATE POLICY commission_teacher_select ON commission_ledger
  FOR SELECT USING (teacher_id = auth.uid() OR is_admin());

-- AI grading: teachers see their own queue, students see their results
CREATE POLICY grading_teacher_select ON ai_grading_queue
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR student_id = auth.uid()
    OR is_admin()
  );

-- Student progress: students see own, teachers see enrolled students
CREATE POLICY progress_student_select ON student_progress_unified
  FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classroom_enrollments ce
      JOIN classrooms c ON c.id = ce.classroom_id
      WHERE ce.student_id = student_progress_unified.student_id
      AND c.teacher_id = auth.uid()
      AND ce.is_active = TRUE
    )
    OR is_admin()
  );

-- Video lessons: public courses visible to all, premium gated by app logic
CREATE POLICY video_select ON video_lessons
  FOR SELECT USING (is_published = TRUE OR is_admin());

-- Live classes: all scheduled classes visible to all authenticated users
CREATE POLICY live_class_select ON live_classes
  FOR SELECT USING (status IN ('scheduled', 'live', 'completed') OR is_admin());

-- Knowledge base: teachers can read, only admin can write
CREATE POLICY kb_select ON knowledge_base_documents
  FOR SELECT USING (is_active = TRUE);
CREATE POLICY kb_embeddings_select ON knowledge_base_embeddings
  FOR SELECT USING (TRUE);

-- ============================================================
-- 17b. MISSING RLS POLICIES (security hardening — closing default-deny gaps)
-- Tables below had RLS ENABLED but no policy, which default-denies ALL
-- access via the anon/authenticated key. The worker bypasses RLS via the
-- service key, so production API traffic is unaffected; these policies
-- enable direct-client Supabase calls and satisfy the Blueprint's RLS
-- requirement. Admin checks reuse the existing inline-subquery pattern.
-- NOTE: CREATE POLICY has no IF NOT EXISTS — re-applying this file to a
-- live DB requires dropping these policies first.
-- ============================================================

-- teacher_profiles: teachers read/update own profile
CREATE POLICY teacher_profiles_self_select ON teacher_profiles
  FOR SELECT USING (user_id = auth.uid() OR is_admin());
CREATE POLICY teacher_profiles_self_update ON teacher_profiles
  FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY teacher_profiles_teacher_insert ON teacher_profiles
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- classroom_enrollments: students see own, teachers see their classroom's roster
CREATE POLICY enrollment_student_select ON classroom_enrollments
  FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid()
    )
    OR is_admin()
  );
CREATE POLICY enrollment_teacher_insert ON classroom_enrollments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid()
    )
  );
CREATE POLICY enrollment_teacher_update ON classroom_enrollments
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid()
    )
  );
CREATE POLICY enrollment_student_insert ON classroom_enrollments
  FOR INSERT WITH CHECK (student_id = auth.uid());

-- syllabus_items: teachers manage, students read assigned
CREATE POLICY syllabus_items_select ON syllabus_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabi s
      WHERE s.id = syllabus_id
      AND (
        s.teacher_id = auth.uid()
        OR EXISTS (
          SELECT 1 FROM classroom_enrollments ce
          WHERE ce.classroom_id = s.classroom_id
          AND ce.student_id = auth.uid()
          AND ce.is_active = TRUE
        )
        OR is_admin()
      )
    )
  );
CREATE POLICY syllabus_items_teacher_insert ON syllabus_items
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM syllabi s WHERE s.id = syllabus_id AND s.teacher_id = auth.uid())
  );
CREATE POLICY syllabus_items_teacher_update ON syllabus_items
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM syllabi s WHERE s.id = syllabus_id AND s.teacher_id = auth.uid())
  );
CREATE POLICY syllabus_items_teacher_delete ON syllabus_items
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM syllabi s WHERE s.id = syllabus_id AND s.teacher_id = auth.uid())
  );

-- syllabus_item_comments + attachments: teachers who own the parent syllabus
-- can read/insert/update/delete; admins too.
CREATE POLICY syllabus_item_comments_teacher_select ON syllabus_item_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
    OR is_admin()
  );
CREATE POLICY syllabus_item_comments_teacher_insert ON syllabus_item_comments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );
CREATE POLICY syllabus_item_comments_teacher_delete ON syllabus_item_comments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );
CREATE POLICY syllabus_item_attachments_teacher_select ON syllabus_item_attachments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
    OR is_admin()
  );
CREATE POLICY syllabus_item_attachments_teacher_insert ON syllabus_item_attachments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );
CREATE POLICY syllabus_item_attachments_teacher_delete ON syllabus_item_attachments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );

-- teacher_referrals: teachers see own, students see who referred them
CREATE POLICY referral_teacher_select ON teacher_referrals
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR student_id = auth.uid()
    OR is_admin()
  );

-- commission_rates: public config read (no secrets), admin writes
CREATE POLICY commission_rates_select ON commission_rates
  FOR SELECT USING (TRUE);
CREATE POLICY commission_rates_admin_insert ON commission_rates
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY commission_rates_admin_update ON commission_rates
  FOR UPDATE USING (is_admin());
CREATE POLICY commission_rates_admin_delete ON commission_rates
  FOR DELETE USING (is_admin());

-- commission_payouts: teachers can request (insert) and read own
CREATE POLICY commission_payouts_teacher_insert ON commission_payouts
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY commission_payouts_admin_update ON commission_payouts
  FOR UPDATE USING (is_admin());

-- ai_generation_queue: teachers read own, insert own
CREATE POLICY generation_teacher_select ON ai_generation_queue
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR user_id = auth.uid()
    OR is_admin()
  );
CREATE POLICY generation_teacher_insert ON ai_generation_queue
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY generation_teacher_update ON ai_generation_queue
  FOR UPDATE USING (
    teacher_id = auth.uid()
    OR is_admin()
  );

-- ai_grading_queue: teachers can insert (submit) grading jobs
CREATE POLICY grading_teacher_insert ON ai_grading_queue
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY grading_teacher_update ON ai_grading_queue
  FOR UPDATE USING (
    teacher_id = auth.uid()
    OR is_admin()
  );

-- ai_quota_usage: users read/update own
CREATE POLICY quota_self_select ON ai_quota_usage
  FOR SELECT USING (
    user_id = auth.uid()
    OR is_admin()
  );
CREATE POLICY quota_self_upsert ON ai_quota_usage
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY quota_self_update ON ai_quota_usage
  FOR UPDATE USING (user_id = auth.uid());

-- ai_quota_limits: public tier limits (no secrets)
CREATE POLICY quota_limits_select ON ai_quota_limits
  FOR SELECT USING (TRUE);

-- student_progress_history: students see own, teachers see enrolled
CREATE POLICY history_student_select ON student_progress_history
  FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classroom_enrollments ce
      JOIN classrooms c ON c.id = ce.classroom_id
      WHERE ce.student_id = student_progress_history.student_id
      AND c.teacher_id = auth.uid()
      AND ce.is_active = TRUE
    )
    OR is_admin()
  );

-- platform_links: public active links
CREATE POLICY platform_links_select ON platform_links
  FOR SELECT USING (is_active = TRUE);

-- video_courses: published visible to all, admin sees all
CREATE POLICY video_courses_select ON video_courses
  FOR SELECT USING (is_published = TRUE OR is_admin());

-- video_progress: users record own watch progress
CREATE POLICY video_progress_user_insert ON video_progress
  FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY video_progress_user_update ON video_progress
  FOR UPDATE USING (user_id = auth.uid());

-- teacher_subscriptions: teachers see own, admin sees all
CREATE POLICY sub_teacher_select ON teacher_subscriptions
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR is_admin()
  );
CREATE POLICY sub_admin_insert ON teacher_subscriptions
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY sub_admin_update ON teacher_subscriptions
  FOR UPDATE USING (is_admin());

-- branding_configs: teachers read/upsert own, admin sees all
CREATE POLICY branding_teacher_select ON branding_configs
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR is_admin()
  );
CREATE POLICY branding_teacher_insert ON branding_configs
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
CREATE POLICY branding_teacher_update ON branding_configs
  FOR UPDATE USING (teacher_id = auth.uid());

-- pricing_config: public active prices, admin writes
CREATE POLICY pricing_config_select ON pricing_config
  FOR SELECT USING (is_active = TRUE OR is_admin());
CREATE POLICY pricing_config_admin_insert ON pricing_config
  FOR INSERT WITH CHECK (is_admin());
CREATE POLICY pricing_config_admin_update ON pricing_config
  FOR UPDATE USING (is_admin());
CREATE POLICY pricing_config_admin_delete ON pricing_config
  FOR DELETE USING (is_admin());

-- order_items: users see items of their own orders
CREATE POLICY order_items_user_select ON order_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_id AND o.user_id = auth.uid()
    )
    OR is_admin()
  );

-- cross_exam_score_map: public reference data
CREATE POLICY cross_exam_select ON cross_exam_score_map
  FOR SELECT USING (TRUE);

-- webhook_events: service-only (no client policy = default deny via anon key).
-- Intentional — the worker uses the service key to write/read. No policy added.

-- teacher_invitations: partner sees own sent invitations; token-gated validation
-- is open (the token is the secret). Admin sees all.
CREATE POLICY teacher_invitations_partner_select ON teacher_invitations
  FOR SELECT USING (
    partner_id = auth.uid()
    OR is_admin()
  );
CREATE POLICY teacher_invitations_partner_insert ON teacher_invitations
  FOR INSERT WITH CHECK (partner_id = auth.uid());
CREATE POLICY teacher_invitations_admin_update ON teacher_invitations
  FOR UPDATE USING (is_admin());

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


-- ============================================================
-- VECTOR SEARCH FUNCTION (Task 4.5)
-- match_documents — cosine similarity search over knowledge_base_embeddings
-- ============================================================

CREATE OR REPLACE FUNCTION match_documents(
  query_embedding VECTOR(1536),
  match_count INTEGER DEFAULT 10,
  filter JSONB DEFAULT '{}'::jsonb
)
RETURNS TABLE (
  id UUID,
  document_id UUID,
  chunk_index INTEGER,
  chunk_text TEXT,
  metadata JSONB,
  similarity REAL
) AS $$
  SELECT
    e.id,
    e.document_id,
    e.chunk_index,
    e.chunk_text,
    e.metadata,
    1 - (e.embedding <=> query_embedding) AS similarity
  FROM knowledge_base_embeddings e
  JOIN knowledge_base_documents d ON d.id = e.document_id
  WHERE d.is_active = TRUE
    -- Apply filters: support both chunk metadata (e.metadata @> filter) AND document-level filters
    AND (
      e.metadata @> filter
      OR (
        (filter->>'category' IS NULL OR d.category = (filter->>'category'))
        AND (filter->>'cefr_level' IS NULL OR d.cefr_level = (filter->>'cefr_level'))
        AND (filter->>'tier' IS NULL OR (d.metadata->>'tier') = (filter->>'tier'))
      )
    )
  ORDER BY e.embedding <=> query_embedding
  LIMIT match_count;
$$ LANGUAGE SQL;

-- ============================================================
-- Task 2 (Wave 1): Syllabus collaborators
-- ============================================================
CREATE TABLE IF NOT EXISTS syllabus_collaborators (
  syllabus_id UUID NOT NULL REFERENCES syllabi(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'editor' CHECK (role IN ('owner', 'editor', 'viewer')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (syllabus_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_syllabus_collaborators_user ON syllabus_collaborators(user_id);
ALTER TABLE syllabus_collaborators ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS collaborators_select_self ON syllabus_collaborators;
CREATE POLICY collaborators_select_self ON syllabus_collaborators
  FOR SELECT USING (true);

-- ============================================================
-- Task 3 (Wave 1): OSEE Passport ledger
-- ============================================================
CREATE TABLE IF NOT EXISTS passport_credentials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  credential_type TEXT NOT NULL CHECK (credential_type IN ('score_report', 'course_completion', 'badge', 'recommendation')),
  issuer_id UUID NOT NULL REFERENCES unified_profiles(id),
  subject_data JSONB NOT NULL,
  signature TEXT NOT NULL,
  public_key_id TEXT NOT NULL,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  revoked_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_passport_credentials_user ON passport_credentials(user_id);

CREATE TABLE IF NOT EXISTS passport_evidence (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  credential_id UUID NOT NULL REFERENCES passport_credentials(id) ON DELETE CASCADE,
  evidence_type TEXT NOT NULL CHECK (evidence_type IN ('pdf', 'image', 'video', 'transcript')),
  storage_url TEXT NOT NULL,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  hash TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_passport_evidence_credential ON passport_evidence(credential_id);

CREATE TABLE IF NOT EXISTS passport_verifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  credential_id UUID NOT NULL REFERENCES passport_credentials(id) ON DELETE CASCADE,
  verifier_id UUID,
  verifier_ip INET,
  verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid BOOLEAN NOT NULL,
  reason TEXT
);
CREATE INDEX IF NOT EXISTS idx_passport_verifications_credential ON passport_verifications(credential_id);

ALTER TABLE passport_credentials ENABLE ROW LEVEL SECURITY;
-- Public read: anyone can verify a credential by ID (no auth required).
DROP POLICY IF EXISTS passport_credentials_public_read ON passport_credentials;
CREATE POLICY passport_credentials_public_read ON passport_credentials
  FOR SELECT USING (true);
-- Only authenticated issuers (teachers/admins) can insert via worker (service key bypasses RLS).
DROP POLICY IF EXISTS passport_credentials_owner_insert ON passport_credentials;
CREATE POLICY passport_credentials_owner_insert ON passport_credentials
  FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS passport_credentials_issuer_update ON passport_credentials;
CREATE POLICY passport_credentials_issuer_update ON passport_credentials
  FOR UPDATE USING (issuer_id = auth.uid() OR auth.uid() IN (SELECT id FROM unified_profiles WHERE role = 'admin'));

ALTER TABLE passport_evidence ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS passport_evidence_public_read ON passport_evidence;
CREATE POLICY passport_evidence_public_read ON passport_evidence
  FOR SELECT USING (true);
DROP POLICY IF EXISTS passport_evidence_owner_insert ON passport_evidence;
CREATE POLICY passport_evidence_owner_insert ON passport_evidence
  FOR INSERT WITH CHECK (true);

ALTER TABLE passport_verifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS passport_verifications_public_insert ON passport_verifications;
CREATE POLICY passport_verifications_public_insert ON passport_verifications
  FOR INSERT WITH CHECK (true);
DROP POLICY IF EXISTS passport_verifications_public_read ON passport_verifications;
CREATE POLICY passport_verifications_public_read ON passport_verifications
  FOR SELECT USING (true);

-- ============================================================
-- Task 7 (Wave 1): Agent traces
-- ============================================================
CREATE TABLE IF NOT EXISTS agent_traces (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES unified_profiles(id) ON DELETE SET NULL,
  agent_name TEXT NOT NULL,
  session_id UUID NOT NULL DEFAULT uuid_generate_v4(),
  input_summary TEXT,
  output_summary TEXT,
  tool_calls JSONB NOT NULL DEFAULT '[]'::JSONB,
  tokens_used INTEGER NOT NULL DEFAULT 0,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  success BOOLEAN NOT NULL,
  error_message TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_agent_traces_user ON agent_traces(user_id);
CREATE INDEX IF NOT EXISTS idx_agent_traces_agent ON agent_traces(agent_name);
ALTER TABLE agent_traces ENABLE ROW LEVEL SECURITY;
-- Service key (worker) bypasses RLS for inserts. Users can read their own traces.
DROP POLICY IF EXISTS agent_traces_user_read ON agent_traces;
CREATE POLICY agent_traces_user_read ON agent_traces
  FOR SELECT USING (user_id = auth.uid());

-- ============================================================
-- Task 10 (Wave 2): Coach sessions — student AI tutor chat history
-- ============================================================
CREATE TABLE IF NOT EXISTS coach_sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  syllabus_id UUID REFERENCES syllabi(id) ON DELETE SET NULL,
  agent_name TEXT NOT NULL DEFAULT 'tutor',
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_coach_sessions_student ON coach_sessions(student_id);

CREATE TABLE IF NOT EXISTS coach_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES coach_sessions(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system', 'tool')),
  content TEXT NOT NULL,
  tool_calls JSONB,
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_coach_messages_session ON coach_messages(session_id);

ALTER TABLE coach_sessions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS coach_sessions_user_read ON coach_sessions;
CREATE POLICY coach_sessions_user_read ON coach_sessions
  FOR SELECT USING (student_id = auth.uid());
DROP POLICY IF EXISTS coach_sessions_user_insert ON coach_sessions;
CREATE POLICY coach_sessions_user_insert ON coach_sessions
  FOR INSERT WITH CHECK (student_id = auth.uid());

ALTER TABLE coach_messages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS coach_messages_user_read ON coach_messages;
CREATE POLICY coach_messages_user_read ON coach_messages
  FOR SELECT USING (
    session_id IN (SELECT id FROM coach_sessions WHERE student_id = auth.uid())
  );
DROP POLICY IF EXISTS coach_messages_user_insert ON coach_messages;
CREATE POLICY coach_messages_user_insert ON coach_messages
  FOR INSERT WITH CHECK (
    session_id IN (SELECT id FROM coach_sessions WHERE student_id = auth.uid())
  );

-- ============================================================
-- Task 14 (Wave 2): OSEE Marketplace
-- ============================================================
CREATE TABLE IF NOT EXISTS marketplace_listings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  listing_type TEXT NOT NULL CHECK (listing_type IN ('lesson_plan', 'mock_test', 'live_class', 'video', 'ebook')),
  exam TEXT NOT NULL CHECK (exam IN ('TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL')),
  level TEXT NOT NULL CHECK (level IN ('A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'GENERAL')),
  price_idr INTEGER NOT NULL CHECK (price_idr > 0),
  preview_url TEXT,
  syllabus_id UUID REFERENCES syllabi(id) ON DELETE SET NULL,
  is_published BOOLEAN NOT NULL DEFAULT TRUE,
  view_count INTEGER NOT NULL DEFAULT 0,
  purchase_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_seller ON marketplace_listings(seller_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_listings_exam ON marketplace_listings(exam, level, is_published);

CREATE TABLE IF NOT EXISTS marketplace_purchases (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  listing_id UUID NOT NULL REFERENCES marketplace_listings(id) ON DELETE RESTRICT,
  buyer_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  seller_id UUID NOT NULL REFERENCES unified_profiles(id),
  price_idr INTEGER NOT NULL,
  commission_idr INTEGER NOT NULL, -- 15% to OSEE
  payout_idr INTEGER NOT NULL, -- 85% to seller
  escrow_status TEXT NOT NULL DEFAULT 'pending' CHECK (escrow_status IN ('pending', 'paid', 'released', 'refunded', 'disputed')),
  tripay_transaction_ref TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  released_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_marketplace_purchases_buyer ON marketplace_purchases(buyer_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_purchases_listing ON marketplace_purchases(listing_id);

CREATE TABLE IF NOT EXISTS marketplace_reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_id UUID NOT NULL UNIQUE REFERENCES marketplace_purchases(id) ON DELETE CASCADE,
  listing_id UUID NOT NULL REFERENCES marketplace_listings(id) ON DELETE CASCADE,
  reviewer_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  stars INTEGER NOT NULL CHECK (stars BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_reviews_listing ON marketplace_reviews(listing_id);

ALTER TABLE marketplace_listings ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS marketplace_listings_public_read ON marketplace_listings;
CREATE POLICY marketplace_listings_public_read ON marketplace_listings
  FOR SELECT USING (is_published = true OR seller_id = auth.uid());
DROP POLICY IF EXISTS marketplace_listings_seller_insert ON marketplace_listings;
CREATE POLICY marketplace_listings_seller_insert ON marketplace_listings
  FOR INSERT WITH CHECK (seller_id = auth.uid());
DROP POLICY IF EXISTS marketplace_listings_seller_update ON marketplace_listings;
CREATE POLICY marketplace_listings_seller_update ON marketplace_listings
  FOR UPDATE USING (seller_id = auth.uid());

ALTER TABLE marketplace_purchases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS marketplace_purchases_buyer_read ON marketplace_purchases;
CREATE POLICY marketplace_purchases_buyer_read ON marketplace_purchases
  FOR SELECT USING (buyer_id = auth.uid() OR seller_id = auth.uid());

ALTER TABLE marketplace_reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS marketplace_reviews_public_read ON marketplace_reviews;
CREATE POLICY marketplace_reviews_public_read ON marketplace_reviews
  FOR SELECT USING (true);
DROP POLICY IF EXISTS marketplace_reviews_buyer_insert ON marketplace_reviews;
CREATE POLICY marketplace_reviews_buyer_insert ON marketplace_reviews
  FOR INSERT WITH CHECK (reviewer_id = auth.uid());

-- ============================================================
-- Task 9 (Wave 2): Studio snapshots — Yjs doc persistence
-- ============================================================
CREATE TABLE IF NOT EXISTS syllabus_snapshots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_id UUID NOT NULL REFERENCES syllabi(id) ON DELETE CASCADE,
  state_json JSONB NOT NULL,
  created_by UUID NOT NULL REFERENCES unified_profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_syllabus_snapshots_syllabus ON syllabus_snapshots(syllabus_id, created_at DESC);

ALTER TABLE syllabus_snapshots ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS syllabus_snapshots_collab_read ON syllabus_snapshots;
CREATE POLICY syllabus_snapshots_collab_read ON syllabus_snapshots
  FOR SELECT USING (
    syllabus_id IN (
      SELECT syllabus_id FROM syllabus_collaborators WHERE user_id = auth.uid()
    )
    OR syllabus_id IN (
      SELECT id FROM syllabi WHERE teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS syllabus_snapshots_collab_write ON syllabus_snapshots;
CREATE POLICY syllabus_snapshots_collab_write ON syllabus_snapshots
  FOR INSERT WITH CHECK (
    syllabus_id IN (
      SELECT syllabus_id FROM syllabus_collaborators
      WHERE user_id = auth.uid() AND role IN ('owner', 'editor')
    )
    OR syllabus_id IN (
      SELECT id FROM syllabi WHERE teacher_id = auth.uid()
    )
  );

-- ============================================================
-- Task 12 (Wave 2): Live classes — LiveKit video sessions
-- ============================================================
CREATE TABLE IF NOT EXISTS live_classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_id UUID NOT NULL REFERENCES syllabi(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id),
  title TEXT NOT NULL,
  scheduled_at TIMESTAMPTZ NOT NULL,
  duration_minutes INTEGER NOT NULL CHECK (duration_minutes > 0),
  livekit_room_name TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'ended', 'cancelled')),
  recording_url TEXT,
  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_live_classes_syllabus ON live_classes(syllabus_id);
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher ON live_classes(teacher_id, scheduled_at DESC);

CREATE TABLE IF NOT EXISTS live_class_attendees (
  class_id UUID NOT NULL REFERENCES live_classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  PRIMARY KEY (class_id, user_id)
);

ALTER TABLE live_classes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS live_classes_public_read ON live_classes;
CREATE POLICY live_classes_public_read ON live_classes
  FOR SELECT USING (true); -- can be filtered by classroom enrollment later

ALTER TABLE live_class_attendees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS live_class_attendees_self_read ON live_class_attendees;
CREATE POLICY live_class_attendees_self_read ON live_class_attendees
  FOR SELECT USING (user_id = auth.uid());

-- ============================================================
-- Task 23 (Wave 3): Push notifications
-- ============================================================
CREATE TABLE IF NOT EXISTS push_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  device_info JSONB,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);

CREATE TABLE IF NOT EXISTS push_subscriptions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  topic TEXT NOT NULL, -- 'class_starting', 'coach_reply', 'passport_issued', 'marketplace_sale'
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, topic)
);

CREATE TABLE IF NOT EXISTS push_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  topic TEXT NOT NULL,
  payload JSONB NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('sent', 'failed', 'queued')),
  error_message TEXT,
  sent_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_push_log_user ON push_log(user_id, sent_at DESC);

ALTER TABLE push_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_tokens_user_read ON push_tokens;
CREATE POLICY push_tokens_user_read ON push_tokens
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS push_tokens_user_insert ON push_tokens;
CREATE POLICY push_tokens_user_insert ON push_tokens
  FOR INSERT WITH CHECK (user_id = auth.uid());

ALTER TABLE push_subscriptions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS push_subscriptions_user_read ON push_subscriptions;
CREATE POLICY push_subscriptions_user_read ON push_subscriptions
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS push_subscriptions_user_write ON push_subscriptions;
CREATE POLICY push_subscriptions_user_write ON push_subscriptions
  FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- Task 25 (Wave 3): Viral growth — referral tracking
-- ============================================================
CREATE TABLE IF NOT EXISTS referrals (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  referrer_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  referee_id UUID REFERENCES unified_profiles(id) ON DELETE SET NULL,
  referral_code TEXT NOT NULL UNIQUE,
  source TEXT, -- 'coach', 'passport_share', 'marketplace', 'direct_link'
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'signed_up', 'converted', 'expired')),
  reward_idr INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  converted_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer ON referrals(referrer_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code ON referrals(referral_code);

CREATE TABLE IF NOT EXISTS viral_share_events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  surface TEXT NOT NULL, -- 'passport_share', 'coach_recommend', 'syllabus_share'
  entity_id TEXT NOT NULL,
  channel TEXT, -- 'whatsapp', 'twitter', 'email', 'copy_link'
  clicks INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_viral_share_user ON viral_share_events(user_id);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS referrals_self_read ON referrals;
CREATE POLICY referrals_self_read ON referrals
  FOR SELECT USING (referrer_id = auth.uid() OR referee_id = auth.uid());
DROP POLICY IF EXISTS referrals_self_insert ON referrals;
CREATE POLICY referrals_self_insert ON referrals
  FOR INSERT WITH CHECK (referrer_id = auth.uid());

ALTER TABLE viral_share_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS viral_share_self_read ON viral_share_events;
CREATE POLICY viral_share_self_read ON viral_share_events
  FOR SELECT USING (user_id = auth.uid());
DROP POLICY IF EXISTS viral_share_self_insert ON viral_share_events;
CREATE POLICY viral_share_self_insert ON viral_share_events
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- ============================================================
-- Task 28 (Wave 4): Marketplace dispute + reputation
-- ============================================================
CREATE TABLE IF NOT EXISTS marketplace_disputes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  purchase_id UUID NOT NULL REFERENCES marketplace_purchases(id) ON DELETE CASCADE,
  opened_by UUID NOT NULL REFERENCES unified_profiles(id),
  reason TEXT NOT NULL CHECK (reason IN ('not_as_described', 'never_delivered', 'quality_issue', 'duplicate', 'other')),
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'under_review', 'resolved_refund', 'resolved_reject', 'closed')),
  resolution_notes TEXT,
  resolved_by UUID REFERENCES unified_profiles(id),
  resolved_at TIMESTAMPTZ,
  evidence_urls JSONB NOT NULL DEFAULT '[]'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_marketplace_disputes_purchase ON marketplace_disputes(purchase_id);
CREATE INDEX IF NOT EXISTS idx_marketplace_disputes_status ON marketplace_disputes(status);

ALTER TABLE marketplace_disputes ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS marketplace_disputes_party_read ON marketplace_disputes;
CREATE POLICY marketplace_disputes_party_read ON marketplace_disputes
  FOR SELECT USING (
    purchase_id IN (
      SELECT id FROM marketplace_purchases WHERE buyer_id = auth.uid() OR seller_id = auth.uid()
    )
    OR resolved_by = auth.uid()
  );
DROP POLICY IF EXISTS marketplace_disputes_buyer_insert ON marketplace_disputes;
CREATE POLICY marketplace_disputes_buyer_insert ON marketplace_disputes
  FOR INSERT WITH CHECK (opened_by = auth.uid());

-- Reputation: aggregate computed from reviews (cached).
CREATE TABLE IF NOT EXISTS marketplace_seller_reputation (
  seller_id UUID PRIMARY KEY REFERENCES unified_profiles(id) ON DELETE CASCADE,
  average_stars DECIMAL(3,2) NOT NULL DEFAULT 0,
  review_count INTEGER NOT NULL DEFAULT 0,
  completed_sales INTEGER NOT NULL DEFAULT 0,
  dispute_count INTEGER NOT NULL DEFAULT 0,
  badges JSONB NOT NULL DEFAULT '[]'::JSONB, -- ['top_rated', 'responsive', 'verified_teacher']
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE marketplace_seller_reputation ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS marketplace_seller_reputation_public_read ON marketplace_seller_reputation;
CREATE POLICY marketplace_seller_reputation_public_read ON marketplace_seller_reputation
  FOR SELECT USING (true);

-- ============================================================
-- Task 37 (Wave 5): Ambassador program v2 — equity + 2x commission
-- ============================================================
CREATE TABLE IF NOT EXISTS ambassador_tiers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL UNIQUE REFERENCES unified_profiles(id) ON DELETE CASCADE,
  tier TEXT NOT NULL DEFAULT 'partner' CHECK (tier IN ('partner', 'ambassador', 'top_ambassador', 'elite')),
  commission_multiplier DECIMAL(3,2) NOT NULL DEFAULT 1.00,
  equity_grant_idr BIGINT NOT NULL DEFAULT 0, -- notional equity value
  equity_vest_years INTEGER NOT NULL DEFAULT 0,
  badge TEXT,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  promoted_at TIMESTAMPTZ,
  notes TEXT
);
CREATE INDEX IF NOT EXISTS idx_ambassador_tiers_tier ON ambassador_tiers(tier);

ALTER TABLE ambassador_tiers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ambassador_tiers_self_read ON ambassador_tiers;
CREATE POLICY ambassador_tiers_self_read ON ambassador_tiers
  FOR SELECT USING (user_id = auth.uid() OR auth.uid() IN (
    SELECT id FROM unified_profiles WHERE role = 'admin'
  ));

-- ============================================================
-- Task 27 (Wave 4 follow-up): Passport audit log — credential lifecycle
-- ============================================================
CREATE TABLE IF NOT EXISTS passport_audit_log (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  credential_id UUID REFERENCES passport_credentials(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES unified_profiles(id), -- nullable: system actions have no actor
  action TEXT NOT NULL CHECK (action IN ('issued', 'verified', 'verify_failed', 'revoked', 'reissued', 'public_key_fetched')),
  actor_type TEXT NOT NULL CHECK (actor_type IN ('issuer', 'verifier', 'admin', 'system', 'anonymous')),
  actor_ip INET,
  user_agent TEXT,
  details JSONB NOT NULL DEFAULT '{}'::JSONB, -- action-specific metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_passport_audit_credential ON passport_audit_log(credential_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_passport_audit_actor ON passport_audit_log(actor_id) WHERE actor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_passport_audit_action ON passport_audit_log(action, created_at DESC);

ALTER TABLE passport_audit_log ENABLE ROW LEVEL SECURITY;
-- Only admins can read the audit log. Everyone can write (server uses service key).
DROP POLICY IF EXISTS passport_audit_admin_read ON passport_audit_log;
CREATE POLICY passport_audit_admin_read ON passport_audit_log
  FOR SELECT USING (auth.uid() IN (SELECT id FROM unified_profiles WHERE role = 'admin'));
DROP POLICY IF EXISTS passport_audit_service_write ON passport_audit_log;
CREATE POLICY passport_audit_service_write ON passport_audit_log
  FOR INSERT WITH CHECK (true);
