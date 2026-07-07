-- Fix: student_progress_history table (referenced in edubot-bridge.ts but never created)
CREATE TABLE IF NOT EXISTS student_progress_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  student_id UUID NOT NULL REFERENCES unified_profiles(id) ON DELETE CASCADE,
  platform TEXT NOT NULL,
  exam_type TEXT,
  section TEXT,
  score DECIMAL,
  metadata JSONB DEFAULT '{}',
  completed_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_progress_history_student ON student_progress_history(student_id);
CREATE INDEX IF NOT EXISTS idx_progress_history_platform ON student_progress_history(platform);

ALTER TABLE student_progress_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS progress_history_student_select ON student_progress_history;
CREATE POLICY progress_history_student_select ON student_progress_history
  FOR SELECT USING (
    student_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM classrooms c
      JOIN classroom_enrollments ce ON ce.classroom_id = c.id
      WHERE c.teacher_id = auth.uid() AND ce.student_id = student_progress_history.student_id
    )
    OR (SELECT role FROM unified_profiles WHERE id = auth.uid()) = 'admin'
  );

DROP POLICY IF EXISTS progress_history_insert ON student_progress_history;
CREATE POLICY progress_history_insert ON student_progress_history
  FOR INSERT WITH CHECK (true); -- edubot bridge inserts via service key