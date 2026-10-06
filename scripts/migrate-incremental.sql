-- ============================================================
-- OSEE Prep Hub — Incremental migration
-- Tables + functions added since last production push
-- ============================================================

-- 0. Add retry_count to webhook_events for dead-letter handling.
ALTER TABLE webhook_events ADD COLUMN IF NOT EXISTS retry_count INTEGER DEFAULT 0;

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

-- 9. student_progress_unified — add practice_count columns + UNIQUE constraint on student_id
-- The UNIQUE(student_id) constraint is required for upsert (ON CONFLICT) in student-progress.ts
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS ibt_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS itp_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS ielts_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS toeic_practice_count INTEGER DEFAULT 0;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS edubot_practice_count INTEGER DEFAULT 0;
-- Drop the old non-unique index if it exists, then add unique constraint
DROP INDEX IF EXISTS idx_progress_student;
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'student_progress_unified_student_id_key'
  ) THEN
    ALTER TABLE student_progress_unified ADD CONSTRAINT student_progress_unified_student_id_key UNIQUE (student_id);
  END IF;
END $$;

-- 10. ai_generation_queue — add user_id column (code queries user_id, schema has teacher_id)
ALTER TABLE ai_generation_queue ADD COLUMN IF NOT EXISTS user_id UUID;
-- Backfill user_id from teacher_id for existing rows
UPDATE ai_generation_queue SET user_id = teacher_id WHERE user_id IS NULL;

-- ============================================================
-- Wave 3: Ambassador badge + effectiveness + email support
-- ============================================================

-- 11. Add badge column to teacher_profiles
-- NOTE: schema.sql now includes badge in the CREATE TABLE for fresh applies.
-- This ALTER is kept for live DBs created before the schema.sql consolidation.
ALTER TABLE teacher_profiles ADD COLUMN IF NOT EXISTS badge TEXT DEFAULT NULL;
-- Values: NULL (no badge), 'osee_certified_educator' (ambassador)
UPDATE teacher_profiles SET badge = 'osee_certified_educator' WHERE is_ambassador = TRUE;

-- ============================================================
-- Wave 4: Teacher invitations (partner → teacher recruitment) + RLS hardening
-- ============================================================

-- 12. Create teacher_invitations table (for live DBs predating schema.sql consolidation)
CREATE TABLE IF NOT EXISTS teacher_invitations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  partner_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  teacher_email TEXT NOT NULL,
  institution_name TEXT NOT NULL,
  token TEXT NOT NULL UNIQUE,
  accepted_at TIMESTAMPTZ,
  accepted_by UUID REFERENCES unified_profiles(id),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_teacher_invitations_partner ON teacher_invitations(partner_id);
CREATE INDEX IF NOT EXISTS idx_teacher_invitations_token ON teacher_invitations(token);
CREATE INDEX IF NOT EXISTS idx_teacher_invitations_email ON teacher_invitations(teacher_email);

-- 13. Enable RLS + add policies for teacher_invitations
ALTER TABLE teacher_invitations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS teacher_invitations_partner_select ON teacher_invitations;
CREATE POLICY teacher_invitations_partner_select ON teacher_invitations
  FOR SELECT USING (
    partner_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS teacher_invitations_partner_insert ON teacher_invitations;
CREATE POLICY teacher_invitations_partner_insert ON teacher_invitations
  FOR INSERT WITH CHECK (partner_id = auth.uid());
DROP POLICY IF EXISTS teacher_invitations_admin_update ON teacher_invitations;
CREATE POLICY teacher_invitations_admin_update ON teacher_invitations
  FOR UPDATE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- ============================================================
-- Wave 5: Close RLS default-deny gaps on 20 tables
-- These tables had RLS ENABLED but no policy (default-deny all access
-- via the anon/authenticated key). The worker bypasses RLS via the
-- service key, so production API traffic is unaffected; these policies
-- enable direct-client Supabase calls and satisfy Blueprint RLS.
-- Idempotent via DROP POLICY IF EXISTS + CREATE POLICY.
-- ============================================================

-- teacher_profiles
DROP POLICY IF EXISTS teacher_profiles_self_select ON teacher_profiles;
CREATE POLICY teacher_profiles_self_select ON teacher_profiles
  FOR SELECT USING (user_id = auth.uid() OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS teacher_profiles_self_update ON teacher_profiles;
CREATE POLICY teacher_profiles_self_update ON teacher_profiles
  FOR UPDATE USING (user_id = auth.uid());
DROP POLICY IF EXISTS teacher_profiles_teacher_insert ON teacher_profiles;
CREATE POLICY teacher_profiles_teacher_insert ON teacher_profiles
  FOR INSERT WITH CHECK (user_id = auth.uid());

-- classroom_enrollments
DROP POLICY IF EXISTS enrollment_student_select ON classroom_enrollments;
CREATE POLICY enrollment_student_select ON classroom_enrollments
  FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid())
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS enrollment_teacher_insert ON classroom_enrollments;
CREATE POLICY enrollment_teacher_insert ON classroom_enrollments
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid())
  );
DROP POLICY IF EXISTS enrollment_teacher_update ON classroom_enrollments;
CREATE POLICY enrollment_teacher_update ON classroom_enrollments
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid())
  );
DROP POLICY IF EXISTS enrollment_student_insert ON classroom_enrollments;
CREATE POLICY enrollment_student_insert ON classroom_enrollments
  FOR INSERT WITH CHECK (student_id = auth.uid());

-- syllabus_items
DROP POLICY IF EXISTS syllabus_items_select ON syllabus_items;
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
        OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
      )
    )
  );
DROP POLICY IF EXISTS syllabus_items_teacher_insert ON syllabus_items;
CREATE POLICY syllabus_items_teacher_insert ON syllabus_items
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM syllabi s WHERE s.id = syllabus_id AND s.teacher_id = auth.uid())
  );
DROP POLICY IF EXISTS syllabus_items_teacher_update ON syllabus_items;
CREATE POLICY syllabus_items_teacher_update ON syllabus_items
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM syllabi s WHERE s.id = syllabus_id AND s.teacher_id = auth.uid())
  );
DROP POLICY IF EXISTS syllabus_items_teacher_delete ON syllabus_items;
CREATE POLICY syllabus_items_teacher_delete ON syllabus_items
  FOR DELETE USING (
    EXISTS (SELECT 1 FROM syllabi s WHERE s.id = syllabus_id AND s.teacher_id = auth.uid())
  );

-- teacher_referrals
DROP POLICY IF EXISTS referral_teacher_select ON teacher_referrals;
CREATE POLICY referral_teacher_select ON teacher_referrals
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR student_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- commission_rates
DROP POLICY IF EXISTS commission_rates_select ON commission_rates;
CREATE POLICY commission_rates_select ON commission_rates
  FOR SELECT USING (TRUE);
DROP POLICY IF EXISTS commission_rates_admin_insert ON commission_rates;
CREATE POLICY commission_rates_admin_insert ON commission_rates
  FOR INSERT WITH CHECK ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS commission_rates_admin_update ON commission_rates;
CREATE POLICY commission_rates_admin_update ON commission_rates
  FOR UPDATE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS commission_rates_admin_delete ON commission_rates;
CREATE POLICY commission_rates_admin_delete ON commission_rates
  FOR DELETE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- commission_payouts (INSERT + UPDATE — SELECT already exists)
DROP POLICY IF EXISTS commission_payouts_teacher_insert ON commission_payouts;
CREATE POLICY commission_payouts_teacher_insert ON commission_payouts
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS commission_payouts_admin_update ON commission_payouts;
CREATE POLICY commission_payouts_admin_update ON commission_payouts
  FOR UPDATE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- ai_generation_queue
DROP POLICY IF EXISTS generation_teacher_select ON ai_generation_queue;
CREATE POLICY generation_teacher_select ON ai_generation_queue
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR user_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS generation_teacher_insert ON ai_generation_queue;
CREATE POLICY generation_teacher_insert ON ai_generation_queue
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS generation_teacher_update ON ai_generation_queue;
CREATE POLICY generation_teacher_update ON ai_generation_queue
  FOR UPDATE USING (
    teacher_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- ai_grading_queue (INSERT + UPDATE — SELECT already exists)
DROP POLICY IF EXISTS grading_teacher_insert ON ai_grading_queue;
CREATE POLICY grading_teacher_insert ON ai_grading_queue
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS grading_teacher_update ON ai_grading_queue;
CREATE POLICY grading_teacher_update ON ai_grading_queue
  FOR UPDATE USING (
    teacher_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- ai_quota_usage
DROP POLICY IF EXISTS quota_self_select ON ai_quota_usage;
CREATE POLICY quota_self_select ON ai_quota_usage
  FOR SELECT USING (
    user_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS quota_self_upsert ON ai_quota_usage;
CREATE POLICY quota_self_upsert ON ai_quota_usage
  FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS quota_self_update ON ai_quota_usage;
CREATE POLICY quota_self_update ON ai_quota_usage
  FOR UPDATE USING (user_id = auth.uid());

-- ai_quota_limits
DROP POLICY IF EXISTS quota_limits_select ON ai_quota_limits;
CREATE POLICY quota_limits_select ON ai_quota_limits
  FOR SELECT USING (TRUE);

-- student_progress_history
DROP POLICY IF EXISTS history_student_select ON student_progress_history;
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
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- platform_links
DROP POLICY IF EXISTS platform_links_select ON platform_links;
CREATE POLICY platform_links_select ON platform_links
  FOR SELECT USING (is_active = TRUE);

-- video_courses
DROP POLICY IF EXISTS video_courses_select ON video_courses;
CREATE POLICY video_courses_select ON video_courses
  FOR SELECT USING (is_published = TRUE OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- video_progress (INSERT + UPDATE — SELECT already exists)
DROP POLICY IF EXISTS video_progress_user_insert ON video_progress;
CREATE POLICY video_progress_user_insert ON video_progress
  FOR INSERT WITH CHECK (user_id = auth.uid());
DROP POLICY IF EXISTS video_progress_user_update ON video_progress;
CREATE POLICY video_progress_user_update ON video_progress
  FOR UPDATE USING (user_id = auth.uid());

-- teacher_subscriptions
DROP POLICY IF EXISTS sub_teacher_select ON teacher_subscriptions;
CREATE POLICY sub_teacher_select ON teacher_subscriptions
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS sub_admin_insert ON teacher_subscriptions;
CREATE POLICY sub_admin_insert ON teacher_subscriptions
  FOR INSERT WITH CHECK ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS sub_admin_update ON teacher_subscriptions;
CREATE POLICY sub_admin_update ON teacher_subscriptions
  FOR UPDATE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- branding_configs
DROP POLICY IF EXISTS branding_teacher_select ON branding_configs;
CREATE POLICY branding_teacher_select ON branding_configs
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS branding_teacher_insert ON branding_configs;
CREATE POLICY branding_teacher_insert ON branding_configs
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS branding_teacher_update ON branding_configs;
CREATE POLICY branding_teacher_update ON branding_configs
  FOR UPDATE USING (teacher_id = auth.uid());

-- pricing_config
DROP POLICY IF EXISTS pricing_config_select ON pricing_config;
CREATE POLICY pricing_config_select ON pricing_config
  FOR SELECT USING (is_active = TRUE OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS pricing_config_admin_insert ON pricing_config;
CREATE POLICY pricing_config_admin_insert ON pricing_config
  FOR INSERT WITH CHECK ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS pricing_config_admin_update ON pricing_config;
CREATE POLICY pricing_config_admin_update ON pricing_config
  FOR UPDATE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');
DROP POLICY IF EXISTS pricing_config_admin_delete ON pricing_config;
CREATE POLICY pricing_config_admin_delete ON pricing_config
  FOR DELETE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin');

-- order_items
DROP POLICY IF EXISTS order_items_user_select ON order_items;
CREATE POLICY order_items_user_select ON order_items
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM orders o WHERE o.id = order_id AND o.user_id = auth.uid())
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- cross_exam_score_map
DROP POLICY IF EXISTS cross_exam_select ON cross_exam_score_map;
CREATE POLICY cross_exam_select ON cross_exam_score_map
  FOR SELECT USING (TRUE);

-- Note: webhook_events intentionally left with no policy (service-only).

-- ============================================================
-- Wave 6: updated_at triggers + FK indexes + ON DELETE behaviors + seed
-- ============================================================

-- 14. Generic updated_at trigger for tables missing it.
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS unified_profiles_updated_at ON unified_profiles;
CREATE TRIGGER unified_profiles_updated_at
  BEFORE UPDATE ON unified_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS teacher_profiles_updated_at ON teacher_profiles;
CREATE TRIGGER teacher_profiles_updated_at
  BEFORE UPDATE ON teacher_profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS syllabi_updated_at ON syllabi;
CREATE TRIGGER syllabi_updated_at
  BEFORE UPDATE ON syllabi FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS knowledge_base_documents_updated_at ON knowledge_base_documents;
CREATE TRIGGER knowledge_base_documents_updated_at
  BEFORE UPDATE ON knowledge_base_documents FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS video_courses_updated_at ON video_courses;
CREATE TRIGGER video_courses_updated_at
  BEFORE UPDATE ON video_courses FOR EACH ROW EXECUTE FUNCTION set_updated_at();
DROP TRIGGER IF EXISTS commission_rates_updated_at ON commission_rates;
CREATE TRIGGER commission_rates_updated_at
  BEFORE UPDATE ON commission_rates FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- 15. Additional FK indexes (idempotent).
CREATE INDEX IF NOT EXISTS idx_teacher_ambassador_by ON teacher_profiles(ambassador_recruited_by);
CREATE INDEX IF NOT EXISTS idx_syllabi_classroom ON syllabi(classroom_id);
CREATE INDEX IF NOT EXISTS idx_syllabi_teacher ON syllabi(teacher_id);
CREATE INDEX IF NOT EXISTS idx_syllabus_items_prereq ON syllabus_items(prerequisite_item_id);
CREATE INDEX IF NOT EXISTS idx_referral_classroom ON teacher_referrals(classroom_id);
CREATE INDEX IF NOT EXISTS idx_commission_student ON commission_ledger(student_id);
CREATE INDEX IF NOT EXISTS idx_kb_uploaded_by ON knowledge_base_documents(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_grading_student ON ai_grading_queue(student_id);
CREATE INDEX IF NOT EXISTS idx_grading_classroom ON ai_grading_queue(classroom_id);
CREATE INDEX IF NOT EXISTS idx_grading_item ON ai_grading_queue(syllabus_item_id);
CREATE INDEX IF NOT EXISTS idx_gen_classroom ON ai_generation_queue(classroom_id);
CREATE INDEX IF NOT EXISTS idx_gen_syllabus ON ai_generation_queue(syllabus_id);
CREATE INDEX IF NOT EXISTS idx_gen_user ON ai_generation_queue(user_id);
CREATE INDEX IF NOT EXISTS idx_progress_syllabus ON student_progress_unified(syllabus_id);
CREATE INDEX IF NOT EXISTS idx_webhook_user ON webhook_events(user_id);
CREATE INDEX IF NOT EXISTS idx_branding_teacher ON branding_configs(teacher_id);
CREATE INDEX IF NOT EXISTS idx_video_course_exam ON video_courses(exam_type);
CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_order_items_status ON order_items(order_id, fulfillment_status);
CREATE INDEX IF NOT EXISTS idx_vouchers_lookup ON vouchers(item_type, status);
CREATE INDEX IF NOT EXISTS idx_cross_exam_source ON cross_exam_score_map(source_exam);
CREATE INDEX IF NOT EXISTS idx_cross_exam_target ON cross_exam_score_map(target_exam);

-- GIN trigram indexes for fuzzy search (pg_trgm already enabled).
CREATE INDEX IF NOT EXISTS idx_profiles_email_trgm ON unified_profiles USING gin (email gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_profiles_name_trgm ON unified_profiles USING gin (display_name gin_trgm_ops);

-- 16. FK ON DELETE behaviors — replace blocking NO ACTION with CASCADE/SET NULL.
-- commission_ledger.teacher_id / student_id → SET NULL (keep ledger history, orphan-safe).
ALTER TABLE commission_ledger DROP CONSTRAINT IF EXISTS commission_ledger_teacher_id_fkey;
ALTER TABLE commission_ledger DROP CONSTRAINT IF EXISTS commission_ledger_student_id_fkey;
ALTER TABLE commission_ledger ADD CONSTRAINT commission_ledger_teacher_id_fkey
  FOREIGN KEY (teacher_id) REFERENCES unified_profiles(id) ON DELETE SET NULL;
ALTER TABLE commission_ledger ADD CONSTRAINT commission_ledger_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES unified_profiles(id) ON DELETE SET NULL;

-- ai_grading_queue.teacher_id / student_id → CASCADE (queue rows are disposable).
ALTER TABLE ai_grading_queue DROP CONSTRAINT IF EXISTS ai_grading_queue_teacher_id_fkey;
ALTER TABLE ai_grading_queue DROP CONSTRAINT IF EXISTS ai_grading_queue_student_id_fkey;
ALTER TABLE ai_grading_queue ADD CONSTRAINT ai_grading_queue_teacher_id_fkey
  FOREIGN KEY (teacher_id) REFERENCES unified_profiles(id) ON DELETE CASCADE;
ALTER TABLE ai_grading_queue ADD CONSTRAINT ai_grading_queue_student_id_fkey
  FOREIGN KEY (student_id) REFERENCES unified_profiles(id) ON DELETE CASCADE;

-- ai_generation_queue.teacher_id / user_id → CASCADE.
ALTER TABLE ai_generation_queue DROP CONSTRAINT IF EXISTS ai_generation_queue_teacher_id_fkey;
ALTER TABLE ai_generation_queue DROP CONSTRAINT IF EXISTS ai_generation_queue_user_id_fkey;
ALTER TABLE ai_generation_queue ADD CONSTRAINT ai_generation_queue_teacher_id_fkey
  FOREIGN KEY (teacher_id) REFERENCES unified_profiles(id) ON DELETE CASCADE;
ALTER TABLE ai_generation_queue ADD CONSTRAINT ai_generation_queue_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES unified_profiles(id) ON DELETE CASCADE;

-- order_items.assigned_student_id → SET NULL (keep order history).
ALTER TABLE order_items DROP CONSTRAINT IF EXISTS order_items_assigned_student_id_fkey;
ALTER TABLE order_items ADD CONSTRAINT order_items_assigned_student_id_fkey
  FOREIGN KEY (assigned_student_id) REFERENCES unified_profiles(id) ON DELETE SET NULL;

-- vouchers.redeemed_by → SET NULL.
ALTER TABLE vouchers DROP CONSTRAINT IF EXISTS vouchers_redeemed_by_fkey;
ALTER TABLE vouchers ADD CONSTRAINT vouchers_redeemed_by_fkey
  FOREIGN KEY (redeemed_by) REFERENCES unified_profiles(id) ON DELETE SET NULL;

-- knowledge_base_documents.uploaded_by → SET NULL.
ALTER TABLE knowledge_base_documents DROP CONSTRAINT IF EXISTS knowledge_base_documents_uploaded_by_fkey;
ALTER TABLE knowledge_base_documents ADD CONSTRAINT knowledge_base_documents_uploaded_by_fkey
  FOREIGN KEY (uploaded_by) REFERENCES unified_profiles(id) ON DELETE SET NULL;

-- teacher_referrals.classroom_id → CASCADE (referrals die with the classroom).
ALTER TABLE teacher_referrals DROP CONSTRAINT IF EXISTS teacher_referrals_classroom_id_fkey;
ALTER TABLE teacher_referrals ADD CONSTRAINT teacher_referrals_classroom_id_fkey
  FOREIGN KEY (classroom_id) REFERENCES classrooms(id) ON DELETE CASCADE;

-- 17. Seed platform_links (idempotent — upsert on (platform, exam_type)).
-- First ensure the unique constraint exists (for live DBs created without it).
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='platform_links_platform_exam_type_key') THEN
    ALTER TABLE platform_links ADD CONSTRAINT platform_links_platform_exam_type_key UNIQUE (platform, exam_type);
  END IF;
END $$;

INSERT INTO platform_links (platform, exam_type, url, label) VALUES
  ('ibt',    'TOEFL_IBT', 'https://ibt.osee.co.id',     'OSEE IBT Practice'),
  ('itp',    'TOEFL_ITP', 'https://test.osee.co.id',    'OSEE ITP Practice'),
  ('ielts',  'IELTS',     'https://ielts.osee.co.id',  'OSEE IELTS Practice'),
  ('toeic',  'TOEIC',     'https://toeic.osee.co.id',  'OSEE TOEIC Practice'),
  ('edubot', 'GENERAL',   'https://t.me/osee_edubot',  'EduBot Tutor'),
  ('osee',   'TOEFL_IBT', 'https://osee.co.id/booking','OSEE Official Test Booking')
ON CONFLICT (platform, exam_type) DO UPDATE SET url = EXCLUDED.url, label = EXCLUDED.label;

-- ============================================================
-- Wave 7: Syllabus item annotations (labels/comments/attachments persistence)
-- ============================================================

-- 18. Add label_ids JSONB column to syllabus_items.
ALTER TABLE syllabus_items ADD COLUMN IF NOT EXISTS label_ids JSONB DEFAULT '[]';

-- 19. Create syllabus_item_comments + syllabus_item_attachments tables.
CREATE TABLE IF NOT EXISTS syllabus_item_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_item_id UUID NOT NULL REFERENCES syllabus_items(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_syllabus_item_comments_item ON syllabus_item_comments(syllabus_item_id);

CREATE TABLE IF NOT EXISTS syllabus_item_attachments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  syllabus_item_id UUID NOT NULL REFERENCES syllabus_items(id) ON DELETE CASCADE,
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  label TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_syllabus_item_attachments_item ON syllabus_item_attachments(syllabus_item_id);

-- 20. Enable RLS + policies for the two new annotation tables.
ALTER TABLE syllabus_item_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE syllabus_item_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS syllabus_item_comments_teacher_select ON syllabus_item_comments;
CREATE POLICY syllabus_item_comments_teacher_select ON syllabus_item_comments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS syllabus_item_comments_teacher_insert ON syllabus_item_comments;
CREATE POLICY syllabus_item_comments_teacher_insert ON syllabus_item_comments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS syllabus_item_comments_teacher_delete ON syllabus_item_comments;
CREATE POLICY syllabus_item_comments_teacher_delete ON syllabus_item_comments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS syllabus_item_attachments_teacher_select ON syllabus_item_attachments;
CREATE POLICY syllabus_item_attachments_teacher_select ON syllabus_item_attachments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS syllabus_item_attachments_teacher_insert ON syllabus_item_attachments;
CREATE POLICY syllabus_item_attachments_teacher_insert ON syllabus_item_attachments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS syllabus_item_attachments_teacher_delete ON syllabus_item_attachments;
CREATE POLICY syllabus_item_attachments_teacher_delete ON syllabus_item_attachments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
  );

-- ============================================================
-- Wave 8: Premium subscription tracking + recurring commission
-- ============================================================

-- 21. Add premium tracking columns to student_progress_unified.
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS has_premium BOOLEAN DEFAULT FALSE;
ALTER TABLE student_progress_unified ADD COLUMN IF NOT EXISTS last_premium_credit_at TIMESTAMPTZ;

-- ============================================================
-- Wave 9: Private lessons (Goal 1 — "punya siswa kelas atau les")
-- ============================================================

-- 22. Add is_private flag to classrooms for 1-on-1 private lessons.
ALTER TABLE classrooms ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE;

-- ============================================================
-- Wave 10: Fix infinite RLS recursion with is_admin() function
-- ============================================================

-- 23. Create is_admin() SECURITY DEFINER function (bypasses RLS, no recursion).
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM unified_profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- 24. Replace all inline admin-check subqueries with is_admin() (35 policies).
-- DROP + CREATE for each affected policy to avoid recursion.
DROP POLICY IF EXISTS profiles_self_select ON unified_profiles;
CREATE POLICY profiles_self_select ON unified_profiles FOR SELECT USING (auth.uid() = id OR is_admin());
DROP POLICY IF EXISTS classrooms_teacher_select ON classrooms;
CREATE POLICY classrooms_teacher_select ON classrooms FOR SELECT USING (teacher_id = auth.uid() OR EXISTS (
    SELECT 1 FROM classroom_enrollments
    WHERE classroom_id = classrooms.id AND student_id = auth.uid() AND is_active = TRUE
  ) OR is_admin());
DROP POLICY IF EXISTS syllabi_teacher_select ON syllabi;
CREATE POLICY syllabi_teacher_select ON syllabi FOR SELECT USING (
    teacher_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classroom_enrollments ce
      JOIN syllabi s ON s.classroom_id = ce.classroom_id
      WHERE ce.student_id = auth.uid() AND s.id = syllabi.id AND ce.is_active = TRUE
    )
    OR is_admin()
  );
DROP POLICY IF EXISTS commission_teacher_select ON commission_ledger;
CREATE POLICY commission_teacher_select ON commission_ledger FOR SELECT USING (teacher_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS grading_teacher_select ON ai_grading_queue;
CREATE POLICY grading_teacher_select ON ai_grading_queue FOR SELECT USING (
    teacher_id = auth.uid()
    OR student_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS progress_student_select ON student_progress_unified;
CREATE POLICY progress_student_select ON student_progress_unified FOR SELECT USING (
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
DROP POLICY IF EXISTS video_select ON video_lessons;
CREATE POLICY video_select ON video_lessons FOR SELECT USING (is_published = TRUE OR is_admin());
DROP POLICY IF EXISTS live_class_select ON live_classes;
CREATE POLICY live_class_select ON live_classes FOR SELECT USING (status IN ('scheduled', 'live', 'completed') OR is_admin());
DROP POLICY IF EXISTS teacher_profiles_self_select ON teacher_profiles;
CREATE POLICY teacher_profiles_self_select ON teacher_profiles FOR SELECT USING (user_id = auth.uid() OR is_admin());
DROP POLICY IF EXISTS enrollment_student_select ON classroom_enrollments;
CREATE POLICY enrollment_student_select ON classroom_enrollments FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classrooms c WHERE c.id = classroom_id AND c.teacher_id = auth.uid()
    )
    OR is_admin()
  );
DROP POLICY IF EXISTS syllabus_items_select ON syllabus_items;
CREATE POLICY syllabus_items_select ON syllabus_items FOR SELECT USING (
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
DROP POLICY IF EXISTS syllabus_item_comments_teacher_select ON syllabus_item_comments;
CREATE POLICY syllabus_item_comments_teacher_select ON syllabus_item_comments FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
    OR is_admin()
  );
DROP POLICY IF EXISTS syllabus_item_attachments_teacher_select ON syllabus_item_attachments;
CREATE POLICY syllabus_item_attachments_teacher_select ON syllabus_item_attachments FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM syllabus_items si
      JOIN syllabi s ON s.id = si.syllabus_id
      WHERE si.id = syllabus_item_id AND s.teacher_id = auth.uid()
    )
    OR is_admin()
  );
DROP POLICY IF EXISTS referral_teacher_select ON teacher_referrals;
CREATE POLICY referral_teacher_select ON teacher_referrals FOR SELECT USING (
    teacher_id = auth.uid()
    OR student_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS commission_rates_admin_insert ON commission_rates;
CREATE POLICY commission_rates_admin_insert ON commission_rates FOR INSERT WITH CHECK (is_admin());
DROP POLICY IF EXISTS commission_rates_admin_update ON commission_rates;
CREATE POLICY commission_rates_admin_update ON commission_rates FOR UPDATE USING (is_admin());
DROP POLICY IF EXISTS commission_rates_admin_delete ON commission_rates;
CREATE POLICY commission_rates_admin_delete ON commission_rates FOR DELETE USING (is_admin());
DROP POLICY IF EXISTS commission_payouts_admin_update ON commission_payouts;
CREATE POLICY commission_payouts_admin_update ON commission_payouts FOR UPDATE USING (is_admin());
DROP POLICY IF EXISTS generation_teacher_select ON ai_generation_queue;
CREATE POLICY generation_teacher_select ON ai_generation_queue FOR SELECT USING (
    teacher_id = auth.uid()
    OR user_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS generation_teacher_update ON ai_generation_queue;
CREATE POLICY generation_teacher_update ON ai_generation_queue FOR UPDATE USING (
    teacher_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS grading_teacher_update ON ai_grading_queue;
CREATE POLICY grading_teacher_update ON ai_grading_queue FOR UPDATE USING (
    teacher_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS quota_self_select ON ai_quota_usage;
CREATE POLICY quota_self_select ON ai_quota_usage FOR SELECT USING (
    user_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS history_student_select ON student_progress_history;
CREATE POLICY history_student_select ON student_progress_history FOR SELECT USING (
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
DROP POLICY IF EXISTS video_courses_select ON video_courses;
CREATE POLICY video_courses_select ON video_courses FOR SELECT USING (is_published = TRUE OR is_admin());
DROP POLICY IF EXISTS sub_teacher_select ON teacher_subscriptions;
CREATE POLICY sub_teacher_select ON teacher_subscriptions FOR SELECT USING (
    teacher_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS sub_admin_insert ON teacher_subscriptions;
CREATE POLICY sub_admin_insert ON teacher_subscriptions FOR INSERT WITH CHECK (is_admin());
DROP POLICY IF EXISTS sub_admin_update ON teacher_subscriptions;
CREATE POLICY sub_admin_update ON teacher_subscriptions FOR UPDATE USING (is_admin());
DROP POLICY IF EXISTS branding_teacher_select ON branding_configs;
CREATE POLICY branding_teacher_select ON branding_configs FOR SELECT USING (
    teacher_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS pricing_config_select ON pricing_config;
CREATE POLICY pricing_config_select ON pricing_config FOR SELECT USING (is_active = TRUE OR is_admin());
DROP POLICY IF EXISTS pricing_config_admin_insert ON pricing_config;
CREATE POLICY pricing_config_admin_insert ON pricing_config FOR INSERT WITH CHECK (is_admin());
DROP POLICY IF EXISTS pricing_config_admin_update ON pricing_config;
CREATE POLICY pricing_config_admin_update ON pricing_config FOR UPDATE USING (is_admin());
DROP POLICY IF EXISTS pricing_config_admin_delete ON pricing_config;
CREATE POLICY pricing_config_admin_delete ON pricing_config FOR DELETE USING (is_admin());
DROP POLICY IF EXISTS order_items_user_select ON order_items;
CREATE POLICY order_items_user_select ON order_items FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM orders o WHERE o.id = order_id AND o.user_id = auth.uid()
    )
    OR is_admin()
  );
DROP POLICY IF EXISTS teacher_invitations_partner_select ON teacher_invitations;
CREATE POLICY teacher_invitations_partner_select ON teacher_invitations FOR SELECT USING (
    partner_id = auth.uid()
    OR is_admin()
  );
DROP POLICY IF EXISTS teacher_invitations_admin_update ON teacher_invitations;
CREATE POLICY teacher_invitations_admin_update ON teacher_invitations FOR UPDATE USING (is_admin());
-- ============================================================
-- Wave 11: Material catalog — global reusable material repository
-- ============================================================

-- 25. Create material_catalog table.
CREATE TABLE IF NOT EXISTS material_catalog (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  source_type TEXT NOT NULL CHECK (source_type IN (
    'platform_ibt', 'platform_itp', 'platform_ielts', 'platform_toeic',
    'edubot', 'teacher_custom', 'ai_generated', 'video_lesson'
  )),
  source_material_id TEXT,
  source_platform_url TEXT,
  title TEXT NOT NULL,
  description TEXT,
  item_type TEXT NOT NULL CHECK (item_type IN (
    'reading', 'listening', 'speaking', 'writing',
    'grammar', 'vocabulary', 'mock_test', 'diagnostic',
    'video', 'live_class', 'assignment', 'review'
  )),
  section TEXT,
  difficulty TEXT,
  estimated_minutes INTEGER DEFAULT 20,
  ai_generated_content JSONB,
  created_by UUID REFERENCES unified_profiles(id) ON DELETE SET NULL,
  is_public BOOLEAN DEFAULT TRUE,
  tags TEXT[] DEFAULT '{}',
  exam_types TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_material_catalog_type ON material_catalog(item_type);
CREATE INDEX IF NOT EXISTS idx_material_catalog_difficulty ON material_catalog(difficulty);
CREATE INDEX IF NOT EXISTS idx_material_catalog_source ON material_catalog(source_type);
CREATE INDEX IF NOT EXISTS idx_material_catalog_public ON material_catalog(is_public);
CREATE INDEX IF NOT EXISTS idx_material_catalog_tags ON material_catalog USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_material_catalog_exam_types ON material_catalog USING gin(exam_types);

-- 26. Enable RLS + policies.
ALTER TABLE material_catalog ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS material_catalog_select ON material_catalog;
CREATE POLICY material_catalog_select ON material_catalog
  FOR SELECT USING (
    is_public = TRUE OR created_by = auth.uid() OR is_admin()
  );
DROP POLICY IF EXISTS material_catalog_insert ON material_catalog;
CREATE POLICY material_catalog_insert ON material_catalog
  FOR INSERT WITH CHECK (created_by = auth.uid() OR is_admin());
DROP POLICY IF EXISTS material_catalog_update ON material_catalog;
CREATE POLICY material_catalog_update ON material_catalog
  FOR UPDATE USING (created_by = auth.uid() OR is_admin());
DROP POLICY IF EXISTS material_catalog_delete ON material_catalog;
CREATE POLICY material_catalog_delete ON material_catalog
  FOR DELETE USING (created_by = auth.uid() OR is_admin());

-- 27. Seed built-in platform catalog (24 curated materials).
INSERT INTO material_catalog (source_type, source_material_id, source_platform_url, title, description, item_type, section, difficulty, estimated_minutes, exam_types, tags) VALUES
  ('platform_ibt', 'ibt-reading-basics', 'https://ibt.osee.co.id', 'iBT Reading — Basics', 'Reading passages & questions, foundation level', 'reading', 'reading', 'B1', 30, '{TOEFL_IBT}', '{inference,passage}'),
  ('platform_ibt', 'ibt-reading-advanced', 'https://ibt.osee.co.id', 'iBT Reading — Advanced', 'Inference & rhetoric-focused passages', 'reading', 'reading', 'C1', 45, '{TOEFL_IBT}', '{inference,rhetoric}'),
  ('platform_ibt', 'ibt-listening-conversations', 'https://ibt.osee.co.id', 'iBT Listening — Conversations', 'Campus-dialogue listening sets', 'listening', 'listening', 'B2', 25, '{TOEFL_IBT}', '{conversation,campus}'),
  ('platform_ibt', 'ibt-listening-lectures', 'https://ibt.osee.co.id', 'iBT Listening — Lectures', 'Mini-lecture listening practice', 'listening', 'listening', 'C1', 40, '{TOEFL_IBT}', '{lecture,academic}'),
  ('platform_ibt', 'ibt-speaking-task1', 'https://ibt.osee.co.id', 'iBT Speaking — Task 1', 'Independent speaking prompts', 'speaking', 'speaking', 'B2', 20, '{TOEFL_IBT}', '{independent,prompt}'),
  ('platform_ibt', 'ibt-speaking-task2', 'https://ibt.osee.co.id', 'iBT Speaking — Task 2', 'Integrated speaking (read+listen+speak)', 'speaking', 'speaking', 'C1', 30, '{TOEFL_IBT}', '{integrated,speaking}'),
  ('platform_ibt', 'ibt-writing-independent', 'https://ibt.osee.co.id', 'iBT Writing — Independent', 'Opinion essay prompts', 'writing', 'writing', 'B2', 30, '{TOEFL_IBT}', '{essay,opinion}'),
  ('platform_ibt', 'ibt-writing-integrated', 'https://ibt.osee.co.id', 'iBT Writing — Integrated', 'Read-listen-write tasks', 'writing', 'writing', 'C1', 40, '{TOEFL_IBT}', '{integrated,writing}'),
  ('platform_itp', 'itp-reading-basics', 'https://test.osee.co.id', 'ITP Reading — Basics', 'Structure & written expression', 'reading', 'reading', 'B1', 30, '{TOEFL_ITP}', '{structure,grammar}'),
  ('platform_itp', 'itp-listening-basics', 'https://test.osee.co.id', 'ITP Listening — Basics', 'Short conversation listening', 'listening', 'listening', 'B1', 25, '{TOEFL_ITP}', '{conversation}'),
  ('platform_itp', 'itp-grammar-structure', 'https://test.osee.co.id', 'ITP Grammar — Structure', 'Sentence structure correction', 'grammar', 'grammar', 'B2', 20, '{TOEFL_ITP}', '{grammar,structure}'),
  ('platform_itp', 'itp-vocabulary', 'https://test.osee.co.id', 'ITP Vocabulary', 'Academic word list practice', 'vocabulary', 'vocabulary', 'B1', 15, '{TOEFL_ITP}', '{vocab,academic}'),
  ('platform_ielts', 'ielts-reading-academic', 'https://ielts.osee.co.id', 'IELTS Reading — Academic', 'Academic passage practice', 'reading', 'reading', 'B2', 40, '{IELTS}', '{academic,passage}'),
  ('platform_ielts', 'ielts-listening', 'https://ielts.osee.co.id', 'IELTS Listening', 'Four-section listening test', 'listening', 'listening', 'B2', 30, '{IELTS}', '{listening,test}'),
  ('platform_ielts', 'ielts-speaking-part1', 'https://ielts.osee.co.id', 'IELTS Speaking — Part 1', 'Personal interview questions', 'speaking', 'speaking', 'B2', 15, '{IELTS}', '{interview,personal}'),
  ('platform_ielts', 'ielts-speaking-part2', 'https://ielts.osee.co.id', 'IELTS Speaking — Part 2', 'Long-turn monologue', 'speaking', 'speaking', 'C1', 20, '{IELTS}', '{monologue,cue-card}'),
  ('platform_ielts', 'ielts-writing-task1', 'https://ielts.osee.co.id', 'IELTS Writing — Task 1', 'Chart/graph description', 'writing', 'writing', 'B2', 20, '{IELTS}', '{chart,description}'),
  ('platform_ielts', 'ielts-writing-task2', 'https://ielts.osee.co.id', 'IELTS Writing — Task 2', 'Academic essay', 'writing', 'writing', 'C1', 40, '{IELTS}', '{essay,academic}'),
  ('platform_toeic', 'toeic-listening-photographs', 'https://toeic.osee.co.id', 'TOEIC Listening — Photographs', 'Picture description', 'listening', 'listening', 'A2', 15, '{TOEIC}', '{picture,business}'),
  ('platform_toeic', 'toeic-listening-short-talks', 'https://toeic.osee.co.id', 'TOEIC Listening — Short Talks', 'Business monologues', 'listening', 'listening', 'B1', 25, '{TOEIC}', '{business,talk}'),
  ('platform_toeic', 'toeic-reading-incomplete', 'https://toeic.osee.co.id', 'TOEIC Reading — Incomplete Sentences', 'Grammar/vocab fill-in-blank', 'reading', 'reading', 'B1', 20, '{TOEIC}', '{grammar,vocab}'),
  ('platform_toeic', 'toeic-reading-comprehension', 'https://toeic.osee.co.id', 'TOEIC Reading — Comprehension', 'Passage-based questions', 'reading', 'reading', 'B2', 30, '{TOEIC}', '{passage,business}'),
  ('edubot', 'edubot-conversation', 'https://edubot.osee.co.id', 'EduBot — Conversation Practice', 'AI-powered spoken conversation', 'speaking', 'speaking', 'B1', 30, '{GENERAL}', '{conversation,ai}'),
  ('edubot', 'edubot-writing-feedback', 'https://edubot.osee.co.id', 'EduBot — Writing Feedback', 'AI essay scoring + feedback', 'writing', 'writing', 'B2', 25, '{GENERAL}', '{writing,ai,feedback}')
ON CONFLICT DO NOTHING;
