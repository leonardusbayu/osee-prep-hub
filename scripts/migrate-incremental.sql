-- ============================================================
-- OSEE Prep Hub — Incremental migration
-- Tables + functions added since last production push
-- ============================================================

-- 1. syllabus_item_progress — per-student syllabus item tracking
CREATE TABLE IF NOT EXISTS syllabus_item_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_item_id UUID NOT NULL REFERENCES syllabus_items(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  status TEXT DEFAULT 'not_started' CHECK (status IN ('not_started', 'started', 'completed')),
  score DECIMAL,
  started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  UNIQUE(syllabus_item_id, student_id)
);
CREATE INDEX IF NOT EXISTS idx_sip_item ON syllabus_item_progress(syllabus_item_id);
CREATE INDEX IF NOT EXISTS idx_sip_student ON syllabus_item_progress(student_id);

-- 2. commission_payouts — teacher withdrawal requests
CREATE TABLE IF NOT EXISTS commission_payouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  amount DECIMAL NOT NULL,
  method TEXT CHECK (method IN ('bank_transfer', 'gopay', 'ovo', 'dana')),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'paid', 'rejected', 'cancelled')),
  reference TEXT,
  notes TEXT,
  requested_at TIMESTAMPTZ DEFAULT NOW(),
  processed_at TIMESTAMPTZ,
  paid_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_payout_teacher ON commission_payouts(teacher_id);
CREATE INDEX IF NOT EXISTS idx_payout_status ON commission_payouts(status);

-- 3. student_progress_history — audit trail per practice attempt
CREATE TABLE IF NOT EXISTS student_progress_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  exam_type TEXT,
  section TEXT,
  score DECIMAL,
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS idx_history_student ON student_progress_history(student_id);
CREATE INDEX IF NOT EXISTS idx_history_completed ON student_progress_history(completed_at);

-- 4. platform_links — deep links per exam type
CREATE TABLE IF NOT EXISTS platform_links (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  platform TEXT NOT NULL,
  exam_type TEXT NOT NULL,
  url TEXT NOT NULL,
  label TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_platform_links_exam ON platform_links(exam_type);

-- 5. order_items.fulfillment_status — add new statuses (ALTER CHECK constraint)
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_fulfillment_status_check;
ALTER TABLE order_items ADD CONSTRAINT order_items_fulfillment_status_check CHECK (fulfillment_status IN (
  'pending','voucher_generated','booking_confirmed','pending_booking','pending_assignment','booking_failed','fulfilled','failed'
));

-- 6. match_documents — updated function with category/cefr/tier filter via JOIN
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
-- Wave 2: fix missing tables + columns (runtime crash fixes)
-- ============================================================

-- 7. class_registrations — student registers interest for a live class
CREATE TABLE IF NOT EXISTS class_registrations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES live_classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  registered_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(class_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_class_reg_class ON class_registrations(class_id);
CREATE INDEX IF NOT EXISTS idx_class_reg_user ON class_registrations(user_id);

-- 8. video_progress — track student watch progress per lesson
CREATE TABLE IF NOT EXISTS video_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES video_lessons(id) ON DELETE CASCADE,
  watched_seconds INTEGER DEFAULT 0,
  completed BOOLEAN DEFAULT FALSE,
  quiz_score INTEGER,
  last_watched_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);
CREATE INDEX IF NOT EXISTS idx_video_progress_user ON video_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_video_progress_lesson ON video_progress(lesson_id);

-- 9. student_progress_unified — add practice_count columns
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS ibt_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS itp_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS ielts_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS toeic_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS edubot_practice_count INTEGER DEFAULT 0;

-- 10. ai_generation_queue — add user_id column (code queries user_id, schema has teacher_id)
ALTER TABLE ai_generation_queue ADD COLUMN IF NOT EXISTS user_id UUID;
-- Backfill user_id from teacher_id for existing rows
UPDATE ai_generation_queue SET user_id = teacher_id WHERE user_id IS NULL;
