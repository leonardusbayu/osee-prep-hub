-- Migration: OSEE Prep Hub new tables (Wave 1-5)
-- All DDL is idempotent (IF NOT EXISTS / DROP IF EXISTS).

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

-- live_classes already exists in original schema (T12 extended it).
-- Add T12 columns idempotently: syllabus_id, livekit_room_name, started_at, ended_at.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='live_classes' AND column_name='syllabus_id') THEN
    ALTER TABLE live_classes ADD COLUMN syllabus_id UUID REFERENCES syllabi(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='live_classes' AND column_name='livekit_room_name') THEN
    ALTER TABLE live_classes ADD COLUMN livekit_room_name TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='live_classes' AND column_name='started_at') THEN
    ALTER TABLE live_classes ADD COLUMN started_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='live_classes' AND column_name='ended_at') THEN
    ALTER TABLE live_classes ADD COLUMN ended_at TIMESTAMPTZ;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_live_classes_syllabus ON live_classes(syllabus_id);
-- Add teacher_id column (original schema uses teacher_name text — keep both)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='live_classes' AND column_name='teacher_id') THEN
    ALTER TABLE live_classes ADD COLUMN teacher_id UUID REFERENCES unified_profiles(id);
  END IF;
END $$;
CREATE INDEX IF NOT EXISTS idx_live_classes_teacher ON live_classes(teacher_id, scheduled_at DESC);

CREATE TABLE IF NOT EXISTS live_class_attendees (
  class_id UUID NOT NULL REFERENCES live_classes(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ,
  left_at TIMESTAMPTZ,
  PRIMARY KEY (class_id, user_id)
);

-- live_classes RLS already exists. Skip override.
ALTER TABLE live_class_attendees ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS live_class_attendees_self_read ON live_class_attendees;
CREATE POLICY live_class_attendees_self_read ON live_class_attendees
  FOR SELECT USING (user_id = auth.uid());

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
  WHERE e.metadata @> filter
  ORDER BY e.embedding <=> query_embedding
  LIMIT match_count;
$$ LANGUAGE SQL;

-- ================================
-- Done.
