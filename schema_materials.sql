-- ============================================================
-- OSEE PREP HUB — MATERIAL DATABASE MIGRATION
-- Unified exam material bank + student answers + parent reports
-- Adds: material_packages, material_assets, exam_questions,
--       skill_taxonomy, student_question_answers, parent_reports
-- Depends on: schema.sql (unified_profiles, classrooms, classroom_enrollments)
-- Idempotent: safe to re-apply via psql / Supabase REST.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. MATERIAL PACKAGES — versioned groups of exam content
-- ============================================================

CREATE TABLE IF NOT EXISTS material_packages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_code TEXT UNIQUE NOT NULL,
  exam_type TEXT NOT NULL CHECK (exam_type IN ('TOEIC','TOEFL_IBT','TOEFL_ITP','IELTS','GENERAL')),
  product_line TEXT NOT NULL,
  target_cefr TEXT,
  source TEXT,
  version INTEGER NOT NULL DEFAULT 1,
  is_published BOOLEAN DEFAULT FALSE,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_packages_exam ON material_packages(exam_type);
CREATE INDEX IF NOT EXISTS idx_packages_published ON material_packages(is_published);

-- ============================================================
-- 2. MATERIAL ASSETS — audio, images, passages, transcripts
-- ============================================================

CREATE TABLE IF NOT EXISTS material_assets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_id UUID REFERENCES material_packages(id) ON DELETE CASCADE,
  asset_type TEXT NOT NULL CHECK (asset_type IN ('audio','image','passage','transcript','stimulus_card')),
  part TEXT,
  title TEXT,
  storage_url TEXT,
  storage_key TEXT,
  transcript TEXT,
  context TEXT,
  text_type TEXT,
  secondary_text TEXT,
  cefr_level TEXT,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_assets_package ON material_assets(package_id);
CREATE INDEX IF NOT EXISTS idx_assets_type_part ON material_assets(asset_type, part);

-- ============================================================
-- 3. EXAM QUESTIONS — typed question bank
-- ============================================================

CREATE TABLE IF NOT EXISTS exam_questions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  package_id UUID REFERENCES material_packages(id) ON DELETE CASCADE,
  exam_type TEXT NOT NULL,
  product_line TEXT NOT NULL,
  part TEXT NOT NULL,
  question_number INT NOT NULL,
  question_type TEXT,
  section TEXT,
  stimulus_asset_id UUID REFERENCES material_assets(id) ON DELETE SET NULL,
  question_text TEXT NOT NULL,
  options JSONB,
  correct_answer TEXT,
  explanation TEXT,
  blanks_json JSONB,
  scoring_rubric TEXT,
  sample_response TEXT,
  difficulty TEXT,
  cefr_level TEXT,
  skill_tags TEXT[],
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(package_id, question_number)
);

CREATE INDEX IF NOT EXISTS idx_questions_package ON exam_questions(package_id);
CREATE INDEX IF NOT EXISTS idx_questions_exam_part ON exam_questions(exam_type, part);
CREATE INDEX IF NOT EXISTS idx_questions_skills ON exam_questions USING GIN(skill_tags);
CREATE INDEX IF NOT EXISTS idx_questions_cefr ON exam_questions(cefr_level);

-- ============================================================
-- 4. SKILL TAXONOMY — reference data
-- ============================================================

CREATE TABLE IF NOT EXISTS skill_taxonomy (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  exam_type TEXT NOT NULL,
  part TEXT NOT NULL,
  skill_key TEXT NOT NULL,
  skill_label TEXT NOT NULL,
  description TEXT,
  UNIQUE(exam_type, part, skill_key)
);

-- ============================================================
-- 5. STUDENT QUESTION ANSWERS — per-question answer tracking
-- ============================================================

CREATE TABLE IF NOT EXISTS student_question_answers (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES exam_questions(id) ON DELETE CASCADE,
  classroom_id UUID REFERENCES classrooms(id) ON DELETE SET NULL,
  student_answer TEXT,
  is_correct BOOLEAN,
  time_spent_seconds INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_answers_student ON student_question_answers(student_id);
CREATE INDEX IF NOT EXISTS idx_answers_question ON student_question_answers(question_id);
CREATE INDEX IF NOT EXISTS idx_answers_classroom ON student_question_answers(classroom_id);

-- ============================================================
-- 6. PARENT REPORTS — generated reports sent to parents
-- ============================================================

CREATE TABLE IF NOT EXISTS parent_reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  classroom_id UUID REFERENCES classrooms(id) ON DELETE SET NULL,
  teacher_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  report_type TEXT NOT NULL DEFAULT 'progress' CHECK (report_type IN ('progress','weakness','summary','recommendation')),
  period_start TIMESTAMPTZ,
  period_end TIMESTAMPTZ,
  content JSONB NOT NULL,
  parent_email TEXT,
  parent_name TEXT,
  status TEXT DEFAULT 'draft' CHECK (status IN ('draft','sent','failed')),
  sent_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_student ON parent_reports(student_id);
CREATE INDEX IF NOT EXISTS idx_reports_teacher ON parent_reports(teacher_id);
CREATE INDEX IF NOT EXISTS idx_reports_classroom ON parent_reports(classroom_id);

-- ============================================================
-- 7. RLS POLICIES
-- ============================================================

-- material_packages: readable by all authenticated, writable by admin
ALTER TABLE material_packages ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS material_packages_select ON material_packages;
CREATE POLICY material_packages_select ON material_packages FOR SELECT USING (true);
DROP POLICY IF EXISTS material_packages_insert ON material_packages;
CREATE POLICY material_packages_insert ON material_packages FOR INSERT WITH CHECK ((SELECT role FROM unified_profiles WHERE id = auth.uid()) IN ('admin','teacher'));
DROP POLICY IF EXISTS material_packages_update ON material_packages;
CREATE POLICY material_packages_update ON material_packages FOR UPDATE USING ((SELECT role FROM unified_profiles WHERE id = auth.uid()) IN ('admin','teacher'));

-- material_assets: same as packages
ALTER TABLE material_assets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS material_assets_select ON material_assets;
CREATE POLICY material_assets_select ON material_assets FOR SELECT USING (true);

-- exam_questions: readable by all, writable by admin/teacher
ALTER TABLE exam_questions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS exam_questions_select ON exam_questions;
CREATE POLICY exam_questions_select ON exam_questions FOR SELECT USING (true);
DROP POLICY IF EXISTS exam_questions_insert ON exam_questions;
CREATE POLICY exam_questions_insert ON exam_questions FOR INSERT WITH CHECK ((SELECT role FROM unified_profiles WHERE id = auth.uid()) IN ('admin','teacher'));

-- skill_taxonomy: readable by all
ALTER TABLE skill_taxonomy ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS skill_taxonomy_select ON skill_taxonomy;
CREATE POLICY skill_taxonomy_select ON skill_taxonomy FOR SELECT USING (true);

-- student_question_answers: student sees own, teacher sees classroom members
ALTER TABLE student_question_answers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sqa_student_select ON student_question_answers;
CREATE POLICY sqa_student_select ON student_question_answers FOR SELECT USING (
  student_id = auth.uid()
  OR EXISTS (SELECT 1 FROM classrooms c JOIN classroom_enrollments ce ON ce.classroom_id = c.id WHERE c.teacher_id = auth.uid() AND ce.student_id = student_question_answers.student_id)
  OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
);
DROP POLICY IF EXISTS sqa_student_insert ON student_question_answers;
CREATE POLICY sqa_student_insert ON student_question_answers FOR INSERT WITH CHECK (student_id = auth.uid());

-- parent_reports: teacher sees own, admin sees all
ALTER TABLE parent_reports ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS pr_teacher_select ON parent_reports;
CREATE POLICY pr_teacher_select ON parent_reports FOR SELECT USING (
  teacher_id = auth.uid()
  OR student_id = auth.uid()
  OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
);
DROP POLICY IF EXISTS pr_teacher_insert ON parent_reports;
CREATE POLICY pr_teacher_insert ON parent_reports FOR INSERT WITH CHECK (
  teacher_id = auth.uid()
  OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
);

-- ============================================================
-- 8. UPDATED_AT TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION update_material_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS material_packages_updated_at ON material_packages;
CREATE TRIGGER material_packages_updated_at
  BEFORE UPDATE ON material_packages
  FOR EACH ROW EXECUTE FUNCTION update_material_updated_at();

-- ============================================================
-- 9. SEED: TOEIC SKILL TAXONOMY
-- ============================================================

INSERT INTO skill_taxonomy (exam_type, part, skill_key, skill_label, description) VALUES
('TOEIC','1','photo_description','Photo Description','Identify what is happening in a photograph'),
('TOEIC','2','question_response','Question-Response','Choose the best response to a spoken question'),
('TOEIC','3','conversation','Conversation','Understand multi-speaker conversations with 3 questions per set'),
('TOEIC','4','talk','Talk','Understand monologue talks with 3 questions per set'),
('TOEIC','5','incomplete_sentence','Incomplete Sentences','Grammar and vocabulary fill-in-the-blank'),
('TOEIC','6','text_completion','Text Completion','Grammar and vocabulary in passage context'),
('TOEIC','7','reading_comprehension','Reading Comprehension','Understand single, double, and triple passages'),
('TOEIC','7','inference','Inference','Draw conclusions from implied information'),
('TOEIC','7','detail','Detail Questions','Find specific information in passages'),
('TOEIC','S1','read_aloud','Read Aloud','Read text aloud with correct pronunciation and intonation'),
('TOEIC','S2','describe_picture','Describe Picture','Describe a photograph in detail'),
('TOEIC','S3','respond_questions','Respond to Questions','Answer questions about a scenario'),
('TOEIC','S4','respond_information','Respond with Information','Answer questions using provided information'),
('TOEIC','S5','express_opinion','Express Opinion','Express and support an opinion on a topic'),
('TOEIC','W1','picture_sentence','Picture Sentence','Write a sentence describing a picture'),
('TOEIC','W2','written_request','Written Request','Write a response to an email or request'),
('TOEIC','W3','opinion_essay','Opinion Essay','Write an essay expressing and supporting an opinion')
ON CONFLICT (exam_type, part, skill_key) DO NOTHING;

-- ============================================================
-- END OF MATERIAL DATABASE MIGRATION
-- ============================================================