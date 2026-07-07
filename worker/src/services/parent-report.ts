import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Parent report service — generates progress reports for parents.
 *
 * Aggregates a student's question answers (joined with exam_questions for
 * part/skill info), computes accuracy breakdowns, and produces an AI-written
 * Bahasa Indonesia summary with home-practice recommendations. Reports are
 * stored in parent_reports with status 'draft' until sent.
 */

const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';
const AI_MODEL = 'gpt-4o-mini';

export interface ParentReportRow {
  id: string;
  student_id: string;
  classroom_id: string | null;
  teacher_id: string;
  report_type: string;
  period_start: string | null;
  period_end: string | null;
  content: Record<string, unknown>;
  parent_email: string | null;
  parent_name: string | null;
  status: string;
  sent_at: string | null;
  created_at: string;
}

export interface GenerateReportInput {
  student_id: string;
  classroom_id?: string;
  report_type?: 'progress' | 'weakness' | 'summary' | 'recommendation';
  period_start?: string;
  period_end?: string;
}

interface PartStat {
  correct: number;
  total: number;
  accuracy: number;
}

interface StudentStats {
  total_answered: number;
  total_correct: number;
  accuracy: number;
  by_part: Record<string, PartStat>;
  by_skill: Record<string, PartStat>;
  weak_areas: string[];
  strong_areas: string[];
  syllabus_items_completed: number;
  syllabus_items_total: number;
  syllabus_completion_pct: number;
}

// ponytail: MIN_SAMPLE avoids noisy 0%/100% on parts/skills with 1-2 answers
const MIN_SAMPLE = 3;
const WEAK_THRESHOLD = 60;
const STRONG_THRESHOLD = 80;

/** Verify the teacher owns the student via classroom_enrollments. Throws if not. */
async function verifyTeacherOwnsStudent(env: Env, teacherId: string, studentId: string): Promise<void> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('classroom_enrollments')
    .select('classroom:classrooms!classroom_enrollments_classroom_id_fkey(teacher_id)')
    .eq('student_id', studentId)
    .eq('is_active', true);
  const rows = (data ?? []) as unknown as Array<{ classroom: { teacher_id: string } | null }>;
  if (!rows.some((r) => r.classroom?.teacher_id === teacherId)) {
    throw new Error('Not authorized: student is not in your classroom');
  }
}

/** Generate a parent report for a student. */
export async function generateReport(
  env: Env,
  teacherId: string,
  input: GenerateReportInput
): Promise<ParentReportRow> {
  await verifyTeacherOwnsStudent(env, teacherId, input.student_id);
  const supabase = getSupabase(env);

  // 1. Student profile
  const { data: student, error: studentErr } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email, target_exam, current_level')
    .eq('id', input.student_id)
    .maybeSingle();
  if (studentErr || !student) throw new Error('Student not found');

  // 2. Answers joined with exam_questions for part + skill_tags
  let answersQuery = supabase
    .from('student_question_answers')
    .select('is_correct, question:exam_questions(part, skill_tags)')
    .eq('student_id', input.student_id);
  if (input.classroom_id) answersQuery = answersQuery.eq('classroom_id', input.classroom_id);
  if (input.period_start) answersQuery = answersQuery.gte('created_at', input.period_start);
  if (input.period_end) answersQuery = answersQuery.lte('created_at', input.period_end);
  const { data: answers, error: answersErr } = await answersQuery;
  if (answersErr) throw new Error(`Fetch answers failed: ${answersErr.message}`);

  // 3. Compute stats
  const stats = computeStats(
    (answers ?? []) as Array<{
      is_correct: boolean | null;
      question: { part: string; skill_tags: string[] | null }[] | null;
    }>
  );

  // 4. Syllabus progress (ponytail: uses student_progress_unified rollup)
  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('syllabus_items_completed, syllabus_items_total, syllabus_completion_pct')
    .eq('student_id', input.student_id)
    .maybeSingle();
  const p = (progress as Record<string, unknown> | null) ?? {};
  stats.syllabus_items_completed = (p.syllabus_items_completed as number) ?? 0;
  stats.syllabus_items_total = (p.syllabus_items_total as number) ?? 0;
  stats.syllabus_completion_pct = (p.syllabus_completion_pct as number) ?? 0;

  // 5. AI summary + recommendations
  const { ai_summary, recommendations } = await generateAiSummary(env, {
    student_name: student.display_name as string,
    target_exam: (student.target_exam as string) ?? null,
    current_level: (student.current_level as string) ?? null,
    stats,
  });

  // 6. Insert
  const content = {
    student: {
      id: student.id as string,
      name: student.display_name as string,
      email: student.email as string,
      target_exam: (student.target_exam as string) ?? null,
      current_level: (student.current_level as string) ?? null,
    },
    stats: {
      total_answered: stats.total_answered,
      total_correct: stats.total_correct,
      accuracy: stats.accuracy,
      syllabus_items_completed: stats.syllabus_items_completed,
      syllabus_items_total: stats.syllabus_items_total,
      syllabus_completion_pct: stats.syllabus_completion_pct,
    },
    by_part: stats.by_part,
    by_skill: stats.by_skill,
    weak_areas: stats.weak_areas,
    strong_areas: stats.strong_areas,
    ai_summary,
    recommendations,
  };

  const { data: row, error: insErr } = await supabase
    .from('parent_reports')
    .insert({
      student_id: input.student_id,
      classroom_id: input.classroom_id ?? null,
      teacher_id: teacherId,
      report_type: input.report_type ?? 'progress',
      period_start: input.period_start ?? null,
      period_end: input.period_end ?? null,
      content,
      status: 'draft',
    })
    .select()
    .single();
  if (insErr || !row) throw new Error(`Insert report failed: ${insErr?.message}`);
  return row as ParentReportRow;
}

/** Aggregate answers into overall + per-part + per-skill accuracy. */
function computeStats(
  answers: Array<{
    is_correct: boolean | null;
    question: { part: string; skill_tags: string[] | null }[] | null;
  }>
): StudentStats {
  let total = 0;
  let correct = 0;
  const partMap: Record<string, { correct: number; total: number }> = {};
  const skillMap: Record<string, { correct: number; total: number }> = {};

  for (const a of answers) {
    if (a.is_correct === null) continue;
    total += 1;
    if (a.is_correct) correct += 1;
    // Join returns array — take first element
    const q = Array.isArray(a.question) && a.question.length > 0 ? a.question[0] : null;
    const part = q?.part;
    if (part) {
      partMap[part] ??= { correct: 0, total: 0 };
      partMap[part].total += 1;
      if (a.is_correct) partMap[part].correct += 1;
    }
    for (const skill of q?.skill_tags ?? []) {
      skillMap[skill] ??= { correct: 0, total: 0 };
      skillMap[skill].total += 1;
      if (a.is_correct) skillMap[skill].correct += 1;
    }
  }

  const finalize = (
    map: Record<string, { correct: number; total: number }>
  ): Record<string, PartStat> => {
    const out: Record<string, PartStat> = {};
    for (const [k, v] of Object.entries(map)) {
      out[k] = {
        correct: v.correct,
        total: v.total,
        accuracy: v.total ? Math.round((v.correct / v.total) * 1000) / 10 : 0,
      };
    }
    return out;
  };

  const by_part = finalize(partMap);
  const by_skill = finalize(skillMap);

  const weak: string[] = [];
  const strong: string[] = [];
  const classify = (map: Record<string, PartStat>) => {
    for (const [k, v] of Object.entries(map)) {
      if (v.total < MIN_SAMPLE) continue;
      if (v.accuracy < WEAK_THRESHOLD) weak.push(k);
      else if (v.accuracy > STRONG_THRESHOLD) strong.push(k);
    }
  };
  classify(by_part);
  classify(by_skill);

  return {
    total_answered: total,
    total_correct: correct,
    accuracy: total ? Math.round((correct / total) * 1000) / 10 : 0,
    by_part,
    by_skill,
    weak_areas: weak,
    strong_areas: strong,
    syllabus_items_completed: 0,
    syllabus_items_total: 0,
    syllabus_completion_pct: 0,
  };
}

/** Ask OpenAI for a Bahasa Indonesia summary + parent recommendations. */
async function generateAiSummary(
  env: Env,
  ctx: {
    student_name: string;
    target_exam: string | null;
    current_level: string | null;
    stats: StudentStats;
  }
): Promise<{ ai_summary: string; recommendations: string[] }> {
  const systemPrompt =
    'You are an English teacher writing a progress report for a student\'s parent in Indonesia. ' +
    'Write in Bahasa Indonesia. Be encouraging but honest. Include specific recommendations.';
  const userPrompt = `Siswa: ${ctx.student_name}
Target exam: ${ctx.target_exam ?? 'belum ditentukan'}
Level saat ini: ${ctx.current_level ?? 'belum dinilai'}

Statistik:
- Total soal dijawab: ${ctx.stats.total_answered}
- Benar: ${ctx.stats.total_correct}
- Akurasi: ${ctx.stats.accuracy}%
- Per part: ${JSON.stringify(ctx.stats.by_part)}
- Per skill: ${JSON.stringify(ctx.stats.by_skill)}
- Area lemah: ${ctx.stats.weak_areas.join(', ') || 'tidak ada'}
- Area kuat: ${ctx.stats.strong_areas.join(', ') || 'tidak ada'}
- Silabus: ${ctx.stats.syllabus_items_completed}/${ctx.stats.syllabus_items_total} selesai (${ctx.stats.syllabus_completion_pct}%)

Tulis laporan untuk orang tua. Return JSON: {"summary": "2-3 paragraf", "recommendations": ["rekomendasi 1", "rekomendasi 2", ...]}`;

  const response = await fetch(OPENAI_CHAT_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: AI_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.5,
      max_tokens: 1200,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} ${errorText}`);
  }
  const json = (await response.json()) as { choices: Array<{ message: { content: string } }> };
  if (!json.choices?.[0]) throw new Error('Invalid OpenAI response: no choices');
  try {
    const parsed = JSON.parse(json.choices[0].message.content) as {
      summary?: string;
      recommendations?: string[];
    };
    return {
      ai_summary: parsed.summary ?? '',
      recommendations: Array.isArray(parsed.recommendations) ? parsed.recommendations : [],
    };
  } catch {
    // ponytail: fallback — if JSON parse fails, use raw text as summary
    return { ai_summary: json.choices[0].message.content, recommendations: [] };
  }
}

/** List reports for a teacher's students. */
export async function listReports(
  env: Env,
  teacherId: string,
  opts?: { studentId?: string; classroomId?: string }
): Promise<Array<Omit<ParentReportRow, 'content'>>> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('parent_reports')
    .select('id, student_id, classroom_id, teacher_id, report_type, period_start, period_end, parent_email, parent_name, status, sent_at, created_at')
    .eq('teacher_id', teacherId);
  if (opts?.studentId) query = query.eq('student_id', opts.studentId);
  if (opts?.classroomId) query = query.eq('classroom_id', opts.classroomId);
  const { data, error } = await query.order('created_at', { ascending: false });
  if (error) throw new Error(`List reports failed: ${error.message}`);
  return (data ?? []) as Array<Omit<ParentReportRow, 'content'>>;
}

/** Get a single report with full content. Teacher (own) or student (own) only. */
export async function getReport(
  env: Env,
  actorId: string,
  reportId: string
): Promise<ParentReportRow | null> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('parent_reports')
    .select('*')
    .eq('id', reportId)
    .maybeSingle();
  if (error || !data) return null;
  const row = data as ParentReportRow;
  if (row.teacher_id !== actorId && row.student_id !== actorId) return null;
  return row;
}

/** Mark a report as sent to a parent. Email delivery itself is a future feature. */
export async function sendReport(
  env: Env,
  teacherId: string,
  reportId: string,
  input: { parent_email: string; parent_name?: string }
): Promise<ParentReportRow> {
  const supabase = getSupabase(env);
  const { data: existing } = await supabase
    .from('parent_reports')
    .select('id, teacher_id')
    .eq('id', reportId)
    .maybeSingle();
  if (!existing) throw new Error('Report not found');
  if ((existing as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Report not owned by teacher');
  }
  const { data, error } = await supabase
    .from('parent_reports')
    .update({
      status: 'sent',
      parent_email: input.parent_email,
      parent_name: input.parent_name ?? null,
      sent_at: new Date().toISOString(),
    })
    .eq('id', reportId)
    .select()
    .single();
  if (error || !data) throw new Error(`Send report failed: ${error?.message}`);
  return data as ParentReportRow;
}

/** List reports for a student (student sees their own). */
export async function listReportsForStudent(
  env: Env,
  studentId: string
): Promise<Array<Omit<ParentReportRow, 'content'>>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('parent_reports')
    .select('id, student_id, classroom_id, teacher_id, report_type, period_start, period_end, parent_email, parent_name, status, sent_at, created_at')
    .eq('student_id', studentId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(`List student reports failed: ${error.message}`);
  return (data ?? []) as Array<Omit<ParentReportRow, 'content'>>;
}