import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Material bank service — browse the exam material database.
 *
 * Read access to material_packages, material_assets, exam_questions,
 * skill_taxonomy, and student_question_answers (answer recording + progress).
 */

export interface MaterialPackage {
  id: string;
  package_code: string;
  exam_type: string;
  product_line: string;
  target_cefr: string | null;
  source: string | null;
  version: number;
  is_published: boolean;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
}

export interface MaterialAsset {
  id: string;
  package_id: string | null;
  asset_type: string;
  part: string | null;
  title: string | null;
  storage_url: string | null;
  storage_key: string | null;
  transcript: string | null;
  context: string | null;
  text_type: string | null;
  secondary_text: string | null;
  cefr_level: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
}

export interface ExamQuestion {
  id: string;
  package_id: string;
  exam_type: string;
  product_line: string;
  part: string;
  question_number: number;
  question_type: string | null;
  section: string | null;
  stimulus_asset_id: string | null;
  question_text: string;
  options: Record<string, unknown> | null;
  correct_answer: string | null;
  explanation: string | null;
  blanks_json: Record<string, unknown> | null;
  scoring_rubric: string | null;
  sample_response: string | null;
  difficulty: string | null;
  cefr_level: string | null;
  skill_tags: string[] | null;
  metadata: Record<string, unknown>;
  created_at: string;
  asset?: { storage_url: string | null; transcript: string | null; context: string | null } | null;
}

export interface SkillTaxonomy {
  id: string;
  exam_type: string;
  part: string;
  skill_key: string;
  skill_label: string;
  description: string | null;
}

export interface StudentAnswer {
  id: string;
  student_id: string;
  question_id: string;
  classroom_id: string | null;
  student_answer: string | null;
  is_correct: boolean | null;
  time_spent_seconds: number | null;
  created_at: string;
}

// ============================================================
// Packages
// ============================================================

/** List material packages, optionally filtered by exam type / product line. */
export async function listPackages(
  env: Env,
  opts?: { examType?: string; productLine?: string; publishedOnly?: boolean }
): Promise<Array<{
  id: string;
  package_code: string;
  exam_type: string;
  product_line: string;
  target_cefr: string | null;
  version: number;
  is_published: boolean;
  metadata: Record<string, unknown>;
  created_at: string;
}>> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('material_packages')
    .select('id, package_code, exam_type, product_line, target_cefr, version, is_published, metadata, created_at');
  if (opts?.examType) query = query.eq('exam_type', opts.examType);
  if (opts?.productLine) query = query.eq('product_line', opts.productLine);
  if (opts?.publishedOnly) query = query.eq('is_published', true);
  const { data, error } = await query.order('created_at', { ascending: false });
  if (error) throw new Error(`List packages failed: ${error.message}`);
  return (data ?? []) as unknown as Array<{
    id: string;
    package_code: string;
    exam_type: string;
    product_line: string;
    target_cefr: string | null;
    version: number;
    is_published: boolean;
    metadata: Record<string, unknown>;
    created_at: string;
  }>;
}

/** Get a full material package row by ID. */
export async function getPackage(env: Env, packageId: string): Promise<MaterialPackage | null> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('material_packages')
    .select('*')
    .eq('id', packageId)
    .maybeSingle();
  if (error) throw new Error(`Get package failed: ${error.message}`);
  return (data as MaterialPackage) ?? null;
}

// ============================================================
// Questions
// ============================================================

const QUESTION_SELECT =
  'id, package_id, exam_type, product_line, part, question_number, question_type, ' +
  'section, stimulus_asset_id, question_text, options, correct_answer, explanation, ' +
  'difficulty, cefr_level, skill_tags, created_at';

/** Attach stimulus asset (storage_url, transcript, context) to questions that reference one. */
async function attachAssets(env: Env, questions: ExamQuestion[]): Promise<ExamQuestion[]> {
  const assetIds = questions
    .map((q) => q.stimulus_asset_id)
    .filter((id): id is string => !!id);
  if (assetIds.length === 0) return questions;
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('material_assets')
    .select('id, storage_url, transcript, context')
    .in('id', assetIds);
  // ponytail: asset fetch is best-effort — questions still render without stimulus
  if (error || !data) return questions;
  const assetMap = new Map(
    (data as unknown as Array<{ id: string; storage_url: string | null; transcript: string | null; context: string | null }>)
      .map((a) => [a.id, { storage_url: a.storage_url, transcript: a.transcript, context: a.context }])
  );
  return questions.map((q) =>
    q.stimulus_asset_id && assetMap.has(q.stimulus_asset_id)
      ? { ...q, asset: assetMap.get(q.stimulus_asset_id)! }
      : q
  );
}

/** Paginated list of exam questions with optional filters. */
export async function listQuestions(
  env: Env,
  opts?: {
    packageId?: string;
    examType?: string;
    part?: string;
    section?: string;
    cefrLevel?: string;
    skillTag?: string;
    limit?: number;
    offset?: number;
  }
): Promise<{ questions: ExamQuestion[]; total: number }> {
  const supabase = getSupabase(env);
  let query = supabase.from('exam_questions').select(QUESTION_SELECT, { count: 'exact' });
  if (opts?.packageId) query = query.eq('package_id', opts.packageId);
  if (opts?.examType) query = query.eq('exam_type', opts.examType);
  if (opts?.part) query = query.eq('part', opts.part);
  if (opts?.section) query = query.eq('section', opts.section);
  if (opts?.cefrLevel) query = query.eq('cefr_level', opts.cefrLevel);
  if (opts?.skillTag) query = query.contains('skill_tags', [opts.skillTag]);
  const limit = opts?.limit ?? 50;
  const offset = opts?.offset ?? 0;
  const { data, error, count } = await query
    .order('part', { ascending: true })
    .order('question_number', { ascending: true })
    .range(offset, offset + limit - 1);
  if (error) throw new Error(`List questions failed: ${error.message}`);
  const questions = (data ?? []) as unknown as unknown as ExamQuestion[];
  const enriched = await attachAssets(env, questions);
  return { questions: enriched, total: count ?? 0 };
}

/** Get a single exam question with its joined stimulus asset. */
export async function getQuestion(env: Env, questionId: string): Promise<ExamQuestion | null> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('exam_questions')
    .select(QUESTION_SELECT)
    .eq('id', questionId)
    .maybeSingle();
  if (error) throw new Error(`Get question failed: ${error.message}`);
  if (!data) return null;
  const enriched = await attachAssets(env, [data as unknown as ExamQuestion]);
  return enriched[0];
}

// ============================================================
// Skills
// ============================================================

/** List skill taxonomy rows, optionally filtered by exam type. */
export async function listSkills(
  env: Env,
  opts?: { examType?: string }
): Promise<SkillTaxonomy[]> {
  const supabase = getSupabase(env);
  let query = supabase.from('skill_taxonomy').select('*');
  if (opts?.examType) query = query.eq('exam_type', opts.examType);
  const { data, error } = await query.order('part', { ascending: true });
  if (error) throw new Error(`List skills failed: ${error.message}`);
  return (data ?? []) as SkillTaxonomy[];
}

// ============================================================
// Search
// ============================================================

/** Full-text search on question_text + explanation via case-insensitive LIKE. */
export async function searchQuestions(
  env: Env,
  query: string,
  opts?: { examType?: string; limit?: number }
): Promise<ExamQuestion[]> {
  const supabase = getSupabase(env);
  // ponytail: ilike OR — strip commas/parens to keep the PostgREST filter string valid
  const term = query.replace(/[,()]/g, ' ').trim();
  if (!term) return [];
  const limit = opts?.limit ?? 20;
  let q = supabase
    .from('exam_questions')
    .select(QUESTION_SELECT)
    .or(`question_text.ilike.%${term}%,explanation.ilike.%${term}%`)
    .limit(limit);
  if (opts?.examType) q = q.eq('exam_type', opts.examType);
  const { data, error } = await q;
  if (error) throw new Error(`Search questions failed: ${error.message}`);
  return attachAssets(env, (data ?? []) as unknown as unknown as ExamQuestion[]);
}

// ============================================================
// Student answers + progress
// ============================================================

/** Record a student's answer to a question. */
export async function recordAnswer(
  env: Env,
  input: {
    student_id: string;
    question_id: string;
    student_answer: string;
    is_correct: boolean;
    time_spent_seconds?: number;
    classroom_id?: string;
  }
): Promise<StudentAnswer> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('student_question_answers')
    .insert({
      student_id: input.student_id,
      question_id: input.question_id,
      student_answer: input.student_answer,
      is_correct: input.is_correct,
      time_spent_seconds: input.time_spent_seconds ?? null,
      classroom_id: input.classroom_id ?? null,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Record answer failed: ${error?.message}`);
  return data as StudentAnswer;
}

/** Get a student's answer history with summary stats. */
export async function getStudentAnswers(
  env: Env,
  studentId: string
): Promise<{
  answers: Array<StudentAnswer & { exam_type: string | null; part: string | null }>;
  total_correct: number;
  total_answered: number;
  by_part: Record<string, { correct: number; total: number }>;
}> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('student_question_answers')
    .select(
      'id, student_id, question_id, classroom_id, student_answer, is_correct, ' +
      'time_spent_seconds, created_at, exam_questions!question_id(exam_type, part)'
    )
    .eq('student_id', studentId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(`Get student answers failed: ${error.message}`);

  const rows = (data ?? []) as unknown as Array<Record<string, unknown>>;
  let total_correct = 0;
  let total_answered = 0;
  const by_part: Record<string, { correct: number; total: number }> = {};

  const answers = rows.map((row) => {
    const eq = (row.exam_questions ?? {}) as { exam_type: string | null; part: string | null };
    const isCorrect = row.is_correct === true;
    const part = eq.part ?? 'unknown';
    if (isCorrect) total_correct += 1;
    total_answered += 1;
    by_part[part] ??= { correct: 0, total: 0 };
    if (isCorrect) by_part[part].correct += 1;
    by_part[part].total += 1;
    return {
      id: row.id as string,
      student_id: row.student_id as string,
      question_id: row.question_id as string,
      classroom_id: (row.classroom_id as string) ?? null,
      student_answer: (row.student_answer as string) ?? null,
      is_correct: (row.is_correct as boolean) ?? null,
      time_spent_seconds: (row.time_spent_seconds as number) ?? null,
      created_at: row.created_at as string,
      exam_type: eq.exam_type ?? null,
      part: eq.part ?? null,
    };
  });

  return { answers, total_correct, total_answered, by_part };
}

/** Get per-student progress summary for a classroom. Teacher must own the classroom. */
export async function getClassroomProgress(
  env: Env,
  teacherId: string,
  classroomId: string
): Promise<Array<{
  student_id: string;
  student_name: string;
  total_answered: number;
  total_correct: number;
  accuracy: number;
  weak_parts: string[];
  by_part: Record<string, { correct: number; total: number }>;
}>> {
  const supabase = getSupabase(env);

  // Verify classroom ownership
  const { data: classroom } = await supabase
    .from('classrooms')
    .select('id, teacher_id')
    .eq('id', classroomId)
    .maybeSingle();
  if (!classroom) throw new Error('Classroom not found');
  if ((classroom as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Classroom not owned by teacher');
  }

  // Active enrollments with student display names
  const { data: enrollments, error: eErr } = await supabase
    .from('classroom_enrollments')
    .select('student_id, unified_profiles!student_id(display_name)')
    .eq('classroom_id', classroomId)
    .eq('is_active', true);
  if (eErr) throw new Error(`List enrollments failed: ${eErr.message}`);
  const students = (enrollments ?? []) as unknown as Array<{
    student_id: string;
    unified_profiles: { display_name: string } | null;
  }>;
  if (students.length === 0) return [];

  // All answers from enrolled students in this classroom, with part info for aggregation
  const studentIds = students.map((s) => s.student_id);
  const { data: answers, error: aErr } = await supabase
    .from('student_question_answers')
    .select('student_id, is_correct, exam_questions!question_id(part)')
    .eq('classroom_id', classroomId)
    .in('student_id', studentIds);
  if (aErr) throw new Error(`List answers failed: ${aErr.message}`);

  // Aggregate per student
  const byStudent: Record<
    string,
    { total_answered: number; total_correct: number; by_part: Record<string, { correct: number; total: number }> }
  > = {};
  for (const row of (answers ?? []) as unknown as Array<Record<string, unknown>>) {
    const sid = row.student_id as string;
    const isCorrect = row.is_correct === true;
    const eq = (row.exam_questions ?? {}) as { part: string | null };
    const part = eq.part ?? 'unknown';
    byStudent[sid] ??= { total_answered: 0, total_correct: 0, by_part: {} };
    byStudent[sid].total_answered += 1;
    if (isCorrect) byStudent[sid].total_correct += 1;
    byStudent[sid].by_part[part] ??= { correct: 0, total: 0 };
    if (isCorrect) byStudent[sid].by_part[part].correct += 1;
    byStudent[sid].by_part[part].total += 1;
  }

  return students.map((s) => {
    const stats = byStudent[s.student_id] ?? { total_answered: 0, total_correct: 0, by_part: {} };
    const accuracy = stats.total_answered > 0 ? stats.total_correct / stats.total_answered : 0;
    // ponytail: weak_parts = parts with accuracy below 0.6, worst-first
    const weak_parts = Object.entries(stats.by_part)
      .map(([part, p]) => ({ part, rate: p.total > 0 ? p.correct / p.total : 1 }))
      .filter((p) => p.rate < 0.6)
      .sort((a, b) => a.rate - b.rate)
      .map((p) => p.part);
    return {
      student_id: s.student_id,
      student_name: s.unified_profiles?.display_name ?? 'Unknown',
      total_answered: stats.total_answered,
      total_correct: stats.total_correct,
      accuracy,
      weak_parts,
      by_part: stats.by_part,
    };
  });
}

// ============================================================
// Practice sessions — student interactive practice
// ============================================================

/** Get a shuffled set of questions for a practice session. */
export async function getPracticeSession(
  env: Env,
  packageId: string,
  count: number = 20
): Promise<{ questions: Array<Record<string, unknown>>; session_id: string }> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('exam_questions')
    .select('id, exam_type, product_line, part, question_number, question_type, section, question_text, options, cefr_level, skill_tags, topic')
    .eq('package_id', packageId)
    .limit(count * 2);
  if (error) throw new Error(`Practice session failed: ${error.message}`);
  const all = (data ?? []) as Array<Record<string, unknown>>;
  if (all.length === 0) throw new Error('No questions found for this package');
  // Shuffle + take N
  const shuffled = [...all].sort(() => Math.random() - 0.5).slice(0, Math.min(count, all.length));
  // Strip correct_answer so student can't cheat
  const clean = shuffled.map(({ ...q }) => {
    delete (q as Record<string, unknown>).correct_answer;
    delete (q as Record<string, unknown>).explanation;
    return q;
  });
  return { questions: clean, session_id: `practice_${Date.now()}_${Math.random().toString(36).slice(2, 8)}` };
}

/** Submit a practice session — batch score answers. */
export async function submitPracticeSession(
  env: Env,
  studentId: string,
  answers: Array<{ question_id: string; student_answer: string }>,
  classroomId?: string
): Promise<{
  score: number;
  total: number;
  correct: number;
  by_part: Record<string, { correct: number; total: number; accuracy: number }>;
  weak_areas: string[];
  details: Array<{ question_id: string; student_answer: string; correct_answer: string; is_correct: boolean; explanation: string | null }>;
}> {
  const supabase = getSupabase(env);
  // Fetch correct answers
  const questionIds = answers.map((a) => a.question_id);
  const { data: questions, error } = await supabase
    .from('exam_questions')
    .select('id, correct_answer, explanation, part')
    .in('id', questionIds);
  if (error) throw new Error(`Submit failed: ${error.message}`);

  const qMap = new Map((questions ?? []).map((q: Record<string, unknown>) => [q.id as string, q]));
  let correct = 0;
  const byPart: Record<string, { correct: number; total: number; accuracy: number }> = {};
  const details: Array<{ question_id: string; student_answer: string; correct_answer: string; is_correct: boolean; explanation: string | null }> = [];
  const answerRows: Array<{ student_id: string; question_id: string; student_answer: string; is_correct: boolean; classroom_id: string | null }> = [];

  for (const ans of answers) {
    const q = qMap.get(ans.question_id);
    if (!q) continue;
    const correctAnswer = (q.correct_answer as string) ?? '';
    const isCorrect = ans.student_answer.trim().toUpperCase() === correctAnswer.trim().toUpperCase();
    if (isCorrect) correct++;
    const part = (q.part as string) ?? 'unknown';
    byPart[part] ??= { correct: 0, total: 0, accuracy: 0 };
    byPart[part].total += 1;
    if (isCorrect) byPart[part].correct += 1;
    details.push({
      question_id: ans.question_id,
      student_answer: ans.student_answer,
      correct_answer: correctAnswer,
      is_correct: isCorrect,
      explanation: (q.explanation as string) ?? null,
    });
    answerRows.push({
      student_id: studentId,
      question_id: ans.question_id,
      student_answer: ans.student_answer,
      is_correct: isCorrect,
      classroom_id: classroomId ?? null,
    });
  }

  // Finalize accuracy
  for (const part of Object.keys(byPart)) {
    byPart[part].accuracy = byPart[part].total > 0 ? Math.round((byPart[part].correct / byPart[part].total) * 1000) / 10 : 0;
  }

  // Weak areas: parts with < 60% accuracy
  const weak_areas = Object.entries(byPart)
    .filter(([, v]) => v.total >= 3 && v.accuracy < 60)
    .map(([k]) => k);

  // Batch insert answers
  if (answerRows.length > 0) {
    // ponytail: chunk 50 at a time to avoid payload limits
    for (let i = 0; i < answerRows.length; i += 50) {
      await supabase.from('student_question_answers').insert(answerRows.slice(i, i + 50));
    }
  }

  return {
    score: answers.length > 0 ? Math.round((correct / answers.length) * 1000) / 10 : 0,
    total: answers.length,
    correct,
    by_part: byPart,
    weak_areas,
    details,
  };
}

/** Get practice session history for a student. */
export async function getPracticeHistory(
  env: Env,
  studentId: string
): Promise<Array<{
  date: string;
  total: number;
  correct: number;
  score: number;
}>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('student_question_answers')
    .select('is_correct, created_at')
    .eq('student_id', studentId)
    .order('created_at', { ascending: false })
    .limit(500);
  if (error) throw new Error(`History failed: ${error.message}`);

  // Group by day
  const byDay: Record<string, { total: number; correct: number }> = {};
  for (const row of (data ?? []) as Array<Record<string, unknown>>) {
    const day = (row.created_at as string)?.substring(0, 10) ?? 'unknown';
    byDay[day] ??= { total: 0, correct: 0 };
    byDay[day].total += 1;
    if (row.is_correct === true) byDay[day].correct += 1;
  }

  return Object.entries(byDay).map(([date, v]) => ({
    date,
    total: v.total,
    correct: v.correct,
    score: v.total > 0 ? Math.round((v.correct / v.total) * 1000) / 10 : 0,
  }));
}