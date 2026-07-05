
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

  -- Flavor profile (from brainstorm â€” cognitive pacing)
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
    'pending','voucher_generated','booking_confirmed','fulfilled','failed'
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
