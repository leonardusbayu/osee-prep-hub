-- ============================================================
-- OSEE PREP HUB — LESSON BOARD FEATURE MIGRATION
-- Remalt-style visual mind-map lesson boards for teachers.
-- Adds: lesson_boards, lesson_board_versions, teacher_materials,
--       lesson_templates, node_comments, lesson_shares,
--       lesson_assessments, lesson_ai_feedback.
-- Depends on: schema.sql (unified_profiles, syllabi,
--             knowledge_base_documents).
-- Idempotent: safe to re-apply via psql / Supabase REST.
-- ============================================================

-- Ensure required extension is present (uuid_generate_v4)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. LESSON BOARDS — a teacher's visual canvas (one board = one lesson plan)
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_boards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  syllabus_id UUID REFERENCES syllabi(id) ON DELETE SET NULL,  -- optional link to a syllabus the board is for
  title TEXT NOT NULL,
  description TEXT,
  canvas_state JSONB NOT NULL DEFAULT '{}'::jsonb,  -- full node graph: positions, sizes, content, edges, metadata
  thumbnail_url TEXT,
  tags TEXT[],                          -- e.g. ['reading','B1','KD-3.1']
  target_exam TEXT CHECK (target_exam IN ('TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL')),
  cefr_level TEXT,                      -- 'A1','A2','B1','B2','C1','C2'
  kp_tags JSONB DEFAULT '[]'::jsonb,    -- Kurikulum Merdeka competency tags: [{code,label}]
  is_template BOOLEAN DEFAULT FALSE,
  is_published BOOLEAN DEFAULT FALSE,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  version INTEGER NOT NULL DEFAULT 1,
  last_saved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lesson_boards_teacher ON lesson_boards(teacher_id);
CREATE INDEX IF NOT EXISTS idx_lesson_boards_template ON lesson_boards(is_template);
CREATE INDEX IF NOT EXISTS idx_lesson_boards_status ON lesson_boards(status);

ALTER TABLE lesson_boards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_boards_teacher_select ON lesson_boards;
CREATE POLICY lesson_boards_teacher_select ON lesson_boards
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS lesson_boards_teacher_insert ON lesson_boards;
CREATE POLICY lesson_boards_teacher_insert ON lesson_boards
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS lesson_boards_teacher_update ON lesson_boards;
CREATE POLICY lesson_boards_teacher_update ON lesson_boards
  FOR UPDATE USING (teacher_id = auth.uid());
DROP POLICY IF EXISTS lesson_boards_teacher_delete ON lesson_boards;
CREATE POLICY lesson_boards_teacher_delete ON lesson_boards
  FOR DELETE USING (teacher_id = auth.uid());

-- ============================================================
-- 2. LESSON BOARD VERSIONS — version history for undo/restore
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_board_versions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  board_id UUID NOT NULL REFERENCES lesson_boards(id) ON DELETE CASCADE,
  version INTEGER NOT NULL,
  canvas_state JSONB NOT NULL,
  saved_by UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  label TEXT,                          -- optional label like "before AI critic" or "v2 final"
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(board_id, version)
);

CREATE INDEX IF NOT EXISTS idx_lesson_board_versions_board ON lesson_board_versions(board_id);

ALTER TABLE lesson_board_versions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_board_versions_select ON lesson_board_versions;
CREATE POLICY lesson_board_versions_select ON lesson_board_versions
  FOR SELECT USING (
    saved_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS lesson_board_versions_insert ON lesson_board_versions;
CREATE POLICY lesson_board_versions_insert ON lesson_board_versions
  FOR INSERT WITH CHECK (
    saved_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS lesson_board_versions_delete ON lesson_board_versions;
CREATE POLICY lesson_board_versions_delete ON lesson_board_versions
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- ============================================================
-- 3. TEACHER MATERIALS — persistent material library ("My Stuff")
--    Reusable sources that persist across boards.
-- ============================================================

CREATE TABLE IF NOT EXISTS teacher_materials (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('pdf','docx','url','youtube','text','image','slides')),
  source_url TEXT,                     -- for url/youtube
  storage_key TEXT,                    -- R2 key for uploaded files
  storage_url TEXT,                    -- public R2 URL
  extracted_text TEXT,                 -- ingested text content
  metadata JSONB DEFAULT '{}'::jsonb,
  cluster_id UUID,                     -- link to a knowledge_base_documents cluster (optional)
  tags TEXT[],
  size_bytes BIGINT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_teacher_materials_teacher ON teacher_materials(teacher_id);
CREATE INDEX IF NOT EXISTS idx_teacher_materials_type ON teacher_materials(type);

ALTER TABLE teacher_materials ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS teacher_materials_teacher_select ON teacher_materials;
CREATE POLICY teacher_materials_teacher_select ON teacher_materials
  FOR SELECT USING (
    teacher_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS teacher_materials_teacher_insert ON teacher_materials;
CREATE POLICY teacher_materials_teacher_insert ON teacher_materials
  FOR INSERT WITH CHECK (teacher_id = auth.uid());
DROP POLICY IF EXISTS teacher_materials_teacher_update ON teacher_materials;
CREATE POLICY teacher_materials_teacher_update ON teacher_materials
  FOR UPDATE USING (teacher_id = auth.uid());
DROP POLICY IF EXISTS teacher_materials_teacher_delete ON teacher_materials;
CREATE POLICY teacher_materials_teacher_delete ON teacher_materials
  FOR DELETE USING (teacher_id = auth.uid());

-- ============================================================
-- 4. LESSON TEMPLATES — starter board layouts teachers can pick from.
--    Readable by all teachers; only creator/admin can modify.
--    (No RLS — access is open at the DB layer; service key enforces
--     write restrictions server-side.)
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  description TEXT,
  category TEXT NOT NULL CHECK (category IN (
    'reading','writing','speaking','grammar','vocabulary','mixed','exam_prep'
  )),
  canvas_state JSONB NOT NULL,         -- the starter node graph
  target_exam TEXT,
  cefr_level TEXT,
  kp_tags JSONB DEFAULT '[]'::jsonb,
  is_official BOOLEAN DEFAULT FALSE,   -- true for OSEE-curated templates
  created_by UUID REFERENCES unified_profiles(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lesson_templates_category ON lesson_templates(category);
CREATE INDEX IF NOT EXISTS idx_lesson_templates_official ON lesson_templates(is_official);

-- ============================================================
-- 5. NODE COMMENTS — comments/annotations on specific nodes within a board
--    (for self-review or collaboration).
-- ============================================================

CREATE TABLE IF NOT EXISTS node_comments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  board_id UUID NOT NULL REFERENCES lesson_boards(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,                -- the canvas node id this comment is attached to
  author_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  resolved BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_node_comments_board ON node_comments(board_id);
CREATE INDEX IF NOT EXISTS idx_node_comments_node ON node_comments(board_id, node_id);

ALTER TABLE node_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS node_comments_select ON node_comments;
CREATE POLICY node_comments_select ON node_comments
  FOR SELECT USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS node_comments_insert ON node_comments;
CREATE POLICY node_comments_insert ON node_comments
  FOR INSERT WITH CHECK (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS node_comments_update ON node_comments;
CREATE POLICY node_comments_update ON node_comments
  FOR UPDATE USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS node_comments_delete ON node_comments;
CREATE POLICY node_comments_delete ON node_comments
  FOR DELETE USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );

-- ============================================================
-- 6. LESSON SHARES — sharing a board with another teacher
--    (collaboration or read-only).
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_shares (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  board_id UUID NOT NULL REFERENCES lesson_boards(id) ON DELETE CASCADE,
  shared_with_email TEXT,              -- email of invited teacher (resolved to user id on accept)
  shared_with_id UUID REFERENCES unified_profiles(id) ON DELETE CASCADE,
  shared_by UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  permission TEXT NOT NULL DEFAULT 'view' CHECK (permission IN ('view','edit','admin')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','accepted','declined','revoked')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lesson_shares_board ON lesson_shares(board_id);
CREATE INDEX IF NOT EXISTS idx_lesson_shares_with ON lesson_shares(shared_with_id);

ALTER TABLE lesson_shares ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_shares_select ON lesson_shares;
CREATE POLICY lesson_shares_select ON lesson_shares
  FOR SELECT USING (
    shared_by = auth.uid()
    OR shared_with_id = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS lesson_shares_insert ON lesson_shares;
CREATE POLICY lesson_shares_insert ON lesson_shares
  FOR INSERT WITH CHECK (shared_by = auth.uid());
DROP POLICY IF EXISTS lesson_shares_update ON lesson_shares;
CREATE POLICY lesson_shares_update ON lesson_shares
  FOR UPDATE USING (
    shared_by = auth.uid()
    OR shared_with_id = auth.uid()
  );
DROP POLICY IF EXISTS lesson_shares_delete ON lesson_shares;
CREATE POLICY lesson_shares_delete ON lesson_shares
  FOR DELETE USING (
    shared_by = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- ============================================================
-- 7. LESSON ASSESSMENTS — assessment artifacts generated from a board
--    (answer keys, rubrics, exit tickets, auto-grade config).
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_assessments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  board_id UUID NOT NULL REFERENCES lesson_boards(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN (
    'answer_key','rubric','exit_ticket','auto_grade_config','quiz'
  )),
  node_id TEXT,                        -- which canvas node this assessment is for
  content JSONB NOT NULL,               -- the assessment content (questions+answers, rubric criteria, etc.)
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lesson_assessments_board ON lesson_assessments(board_id);
CREATE INDEX IF NOT EXISTS idx_lesson_assessments_type ON lesson_assessments(type);

ALTER TABLE lesson_assessments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_assessments_select ON lesson_assessments;
CREATE POLICY lesson_assessments_select ON lesson_assessments
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS lesson_assessments_insert ON lesson_assessments;
CREATE POLICY lesson_assessments_insert ON lesson_assessments
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS lesson_assessments_update ON lesson_assessments;
CREATE POLICY lesson_assessments_update ON lesson_assessments
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS lesson_assessments_delete ON lesson_assessments;
CREATE POLICY lesson_assessments_delete ON lesson_assessments
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );

-- ============================================================
-- 8. LESSON AI FEEDBACK — AI critic results + teacher/student flags
--    (for the system to learn).
-- ============================================================

CREATE TABLE IF NOT EXISTS lesson_ai_feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  board_id UUID NOT NULL REFERENCES lesson_boards(id) ON DELETE CASCADE,
  node_id TEXT NOT NULL,
  feedback_type TEXT NOT NULL CHECK (feedback_type IN ('critic','teacher_flag','student_flag')),
  severity TEXT CHECK (severity IN ('info','warning','error','critical')),
  body TEXT NOT NULL,
  category TEXT,                        -- 'factual_error'|'grade_mismatch'|'bias'|'missing_objective'|'other'
  resolved BOOLEAN DEFAULT FALSE,
  reported_by UUID REFERENCES unified_profiles(id) ON DELETE SET NULL,
  ai_response JSONB,                   -- for critic type, the full structured review
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_lesson_ai_feedback_board ON lesson_ai_feedback(board_id);
CREATE INDEX IF NOT EXISTS idx_lesson_ai_feedback_node ON lesson_ai_feedback(board_id, node_id);
CREATE INDEX IF NOT EXISTS idx_lesson_ai_feedback_type ON lesson_ai_feedback(feedback_type);

ALTER TABLE lesson_ai_feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS lesson_ai_feedback_select ON lesson_ai_feedback;
CREATE POLICY lesson_ai_feedback_select ON lesson_ai_feedback
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR reported_by = auth.uid()
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );
DROP POLICY IF EXISTS lesson_ai_feedback_insert ON lesson_ai_feedback;
CREATE POLICY lesson_ai_feedback_insert ON lesson_ai_feedback
  FOR INSERT WITH CHECK (
    reported_by = auth.uid()
    OR EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
  );
DROP POLICY IF EXISTS lesson_ai_feedback_update ON lesson_ai_feedback;
CREATE POLICY lesson_ai_feedback_update ON lesson_ai_feedback
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR reported_by = auth.uid()
  );
DROP POLICY IF EXISTS lesson_ai_feedback_delete ON lesson_ai_feedback;
CREATE POLICY lesson_ai_feedback_delete ON lesson_ai_feedback
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM lesson_boards b
      WHERE b.id = board_id AND b.teacher_id = auth.uid()
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

-- ============================================================
-- 9. UPDATED_AT TRIGGERS — auto-maintain updated_at on board tables
-- ============================================================

CREATE OR REPLACE FUNCTION update_boards_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS lesson_boards_updated_at ON lesson_boards;
CREATE TRIGGER lesson_boards_updated_at
  BEFORE UPDATE ON lesson_boards
  FOR EACH ROW
  EXECUTE FUNCTION update_boards_updated_at();

DROP TRIGGER IF EXISTS teacher_materials_updated_at ON teacher_materials;
CREATE TRIGGER teacher_materials_updated_at
  BEFORE UPDATE ON teacher_materials
  FOR EACH ROW
  EXECUTE FUNCTION update_boards_updated_at();

DROP TRIGGER IF EXISTS lesson_templates_updated_at ON lesson_templates;
CREATE TRIGGER lesson_templates_updated_at
  BEFORE UPDATE ON lesson_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_boards_updated_at();

DROP TRIGGER IF EXISTS node_comments_updated_at ON node_comments;
CREATE TRIGGER node_comments_updated_at
  BEFORE UPDATE ON node_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_boards_updated_at();

DROP TRIGGER IF EXISTS lesson_assessments_updated_at ON lesson_assessments;
CREATE TRIGGER lesson_assessments_updated_at
  BEFORE UPDATE ON lesson_assessments
  FOR EACH ROW
  EXECUTE FUNCTION update_boards_updated_at();

-- ============================================================
-- 10. SEED DATA — Official OSEE-curated lesson templates
-- ============================================================

-- Template 1: Reading Comprehension Builder
INSERT INTO lesson_templates (
  id, name, description, category, canvas_state, target_exam, cefr_level, is_official
) VALUES (
  'a0000000-0000-4000-8000-000000000001',
  'Reading Comprehension Builder',
  'A starter board for building a reading comprehension lesson: source material flows into strategy theory, worked examples, practice questions, key vocabulary, and a reading agent node.',
  'reading',
  '{
    "nodes": {
      "input": {
        "position": {"x": 40, "y": 220},
        "size": {"w": 320, "h": 160},
        "data": {"type": "input", "title": "Source Material", "color": "#dbeafe", "headerLabel": "Input"}
      },
      "theory": {
        "position": {"x": 440, "y": 60},
        "size": {"w": 320, "h": 180},
        "data": {"type": "theory", "title": "Reading Strategy", "color": "#fef3c7", "headerLabel": "Theory"}
      },
      "examples": {
        "position": {"x": 440, "y": 260},
        "size": {"w": 320, "h": 180},
        "data": {"type": "examples", "title": "Worked Examples", "color": "#dcfce7", "headerLabel": "Examples"}
      },
      "exercises": {
        "position": {"x": 840, "y": 60},
        "size": {"w": 320, "h": 200},
        "data": {"type": "exercises", "title": "Comprehension Questions", "color": "#fce7f3", "headerLabel": "Practice"}
      },
      "vocabulary": {
        "position": {"x": 840, "y": 280},
        "size": {"w": 320, "h": 160},
        "data": {"type": "vocabulary", "title": "Key Vocabulary", "color": "#ede9fe", "headerLabel": "Vocab"}
      },
      "reading_agent": {
        "position": {"x": 1240, "y": 160},
        "size": {"w": 320, "h": 200},
        "data": {"type": "reading_agent", "title": "Reading Agent", "color": "#fde68a", "headerLabel": "AI Agent"}
      }
    },
    "edges": [
      {"from": "input", "to": "theory", "faded": false},
      {"from": "input", "to": "examples", "faded": false},
      {"from": "theory", "to": "exercises", "faded": false},
      {"from": "examples", "to": "exercises", "faded": false},
      {"from": "exercises", "to": "vocabulary", "faded": false},
      {"from": "exercises", "to": "reading_agent", "faded": false}
    ]
  }'::jsonb,
  'TOEFL_IBT',
  'B2',
  TRUE
) ON CONFLICT (id) DO NOTHING;

-- Template 2: Vocab Builder 5-Step
INSERT INTO lesson_templates (
  id, name, description, category, canvas_state, target_exam, cefr_level, is_official
) VALUES (
  'a0000000-0000-4000-8000-000000000002',
  'Vocab Builder 5-Step',
  'A five-step vocabulary builder: ingest a source, select target words, generate definitions/theory, build practice exercises, and assemble a final vocabulary output set with activities.',
  'vocabulary',
  '{
    "nodes": {
      "input": {
        "position": {"x": 40, "y": 200},
        "size": {"w": 320, "h": 160},
        "data": {"type": "input", "title": "Word Source", "color": "#dbeafe", "headerLabel": "Input"}
      },
      "select": {
        "position": {"x": 440, "y": 200},
        "size": {"w": 320, "h": 180},
        "data": {"type": "select", "title": "Target Words", "color": "#dcfce7", "headerLabel": "Select"}
      },
      "theory": {
        "position": {"x": 840, "y": 40},
        "size": {"w": 320, "h": 180},
        "data": {"type": "theory", "title": "Definitions & Notes", "color": "#fef3c7", "headerLabel": "Theory"}
      },
      "exercises": {
        "position": {"x": 840, "y": 320},
        "size": {"w": 320, "h": 180},
        "data": {"type": "exercises", "title": "Practice Activities", "color": "#fce7f3", "headerLabel": "Practice"}
      },
      "output": {
        "position": {"x": 1240, "y": 200},
        "size": {"w": 320, "h": 200},
        "data": {"type": "output", "title": "Final Vocab Set", "color": "#ede9fe", "headerLabel": "Output"}
      }
    },
    "edges": [
      {"from": "input", "to": "select", "faded": false},
      {"from": "select", "to": "theory", "faded": false},
      {"from": "select", "to": "exercises", "faded": false},
      {"from": "theory", "to": "exercises", "faded": false},
      {"from": "exercises", "to": "output", "faded": false}
    ]
  }'::jsonb,
  'IELTS',
  'B1',
  TRUE
) ON CONFLICT (id) DO NOTHING;

-- Template 3: Grammar Lesson with Assessment
INSERT INTO lesson_templates (
  id, name, description, category, canvas_state, target_exam, cefr_level, is_official
) VALUES (
  'a0000000-0000-4000-8000-000000000003',
  'Grammar Lesson with Assessment',
  'A grammar lesson board that includes theory, worked examples, practice exercises, and an assessment node (exit ticket / quiz) before producing a final output.',
  'grammar',
  '{
    "nodes": {
      "input": {
        "position": {"x": 40, "y": 200},
        "size": {"w": 320, "h": 160},
        "data": {"type": "input", "title": "Grammar Topic", "color": "#dbeafe", "headerLabel": "Input"}
      },
      "theory": {
        "position": {"x": 440, "y": 40},
        "size": {"w": 320, "h": 180},
        "data": {"type": "theory", "title": "Rule & Explanation", "color": "#fef3c7", "headerLabel": "Theory"}
      },
      "examples": {
        "position": {"x": 440, "y": 320},
        "size": {"w": 320, "h": 180},
        "data": {"type": "examples", "title": "Worked Examples", "color": "#dcfce7", "headerLabel": "Examples"}
      },
      "exercises": {
        "position": {"x": 840, "y": 40},
        "size": {"w": 320, "h": 200},
        "data": {"type": "exercises", "title": "Practice Drills", "color": "#fce7f3", "headerLabel": "Practice"}
      },
      "assessment": {
        "position": {"x": 840, "y": 320},
        "size": {"w": 320, "h": 200},
        "data": {"type": "assessment", "title": "Exit Ticket / Quiz", "color": "#fde68a", "headerLabel": "Assessment"}
      },
      "output": {
        "position": {"x": 1240, "y": 200},
        "size": {"w": 320, "h": 200},
        "data": {"type": "output", "title": "Lesson Summary", "color": "#ede9fe", "headerLabel": "Output"}
      }
    },
    "edges": [
      {"from": "input", "to": "theory", "faded": false},
      {"from": "input", "to": "examples", "faded": false},
      {"from": "theory", "to": "exercises", "faded": false},
      {"from": "examples", "to": "exercises", "faded": false},
      {"from": "exercises", "to": "assessment", "faded": false},
      {"from": "exercises", "to": "output", "faded": false},
      {"from": "assessment", "to": "output", "faded": false}
    ]
  }'::jsonb,
  'TOEFL_ITP',
  'B1',
  TRUE
) ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- END OF LESSON BOARD MIGRATION
-- ============================================================