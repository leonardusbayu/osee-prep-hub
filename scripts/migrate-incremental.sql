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