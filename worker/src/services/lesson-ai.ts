import type { Env } from '../types';

/**
 * AI critic + assessment generation service.
 *
 * - reviewLesson: an AI "critic" agent that reviews a board's generated content
 *   for factual errors, grade-level mismatch, bias, missing objectives, etc.
 * - generateAssessment: produces answer keys, rubrics, exit tickets, and
 *   auto-grade configs from a board's node content.
 */

const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';
const GENERATION_MODEL = 'gpt-4o-mini';

export type CriticSeverity = 'info' | 'warning' | 'error' | 'critical';

export interface CriticFinding {
  node_id: string;
  severity: CriticSeverity;
  category: string; // 'factual_error' | 'grade_mismatch' | 'bias' | 'missing_objective' | 'other'
  message: string;
  suggestion?: string;
}

export interface CriticReview {
  overall_score: number; // 0-100
  findings: CriticFinding[];
  summary: string;
}

export interface ReviewLessonInput {
  board_id: string;
  nodes: Array<{ id: string; type: string; title: string; content: Record<string, unknown> }>;
  target_exam?: string;
  cefr_level?: string;
  kp_tags?: Array<{ code: string; label: string }>;
}

/** Review a lesson board's generated content for quality issues. */
export async function reviewLesson(env: Env, input: ReviewLessonInput): Promise<CriticReview> {
  const level = input.cefr_level ?? 'B1';
  const exam = input.target_exam ?? 'GENERAL';
  const kpLine = input.kp_tags && input.kp_tags.length > 0
    ? `Target competencies: ${input.kp_tags.map((k) => `${k.code} (${k.label})`).join(', ')}.`
    : '';

  const nodesJson = input.nodes
    .map((n) => `Node "${n.title}" (id=${n.id}, type=${n.type}):\n${JSON.stringify(n.content).slice(0, 800)}`)
    .join('\n\n');

  const systemPrompt = `You are an expert English teaching material critic for Indonesian students.
Target CEFR level: ${level}
Exam: ${exam}
${kpLine}

Review the following lesson board nodes for:
1. Factual errors (incorrect grammar rules, wrong definitions, misleading examples)
2. Grade-level mismatch (content too easy/hard for ${level})
3. Bias or cultural insensitivity
4. Missing learning objectives or alignment to competencies
5. Pedagogical issues (unclear instructions, missing answer keys, poor question quality)

Return ONLY valid JSON (no markdown fences):
{
  "overall_score": <number 0-100>,
  "findings": [
    {"node_id": "...", "severity": "info|warning|error|critical", "category": "factual_error|grade_mismatch|bias|missing_objective|other", "message": "...", "suggestion": "..."}
  ],
  "summary": "<2-3 sentence overall assessment>"
}`;

  const response = await fetch(OPENAI_CHAT_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: GENERATION_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: nodesJson },
      ],
      temperature: 0.3,
      max_tokens: 2000,
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
    return JSON.parse(json.choices[0].message.content) as CriticReview;
  } catch {
    throw new Error('OpenAI did not return valid JSON for critic review');
  }
}

// ============================================================
// Assessment generation
// ============================================================

export type AssessmentType = 'answer_key' | 'rubric' | 'exit_ticket' | 'auto_grade_config' | 'quiz';

export interface GenerateAssessmentInput {
  type: AssessmentType;
  node_id?: string;
  topic: string;
  level?: string;
  exam?: string;
  node_content?: Record<string, unknown>; // the source node's content (e.g. exercises)
}

/** Generate an assessment artifact (answer key, rubric, exit ticket, etc.) from a node's content. */
export async function generateAssessment(
  env: Env,
  input: GenerateAssessmentInput
): Promise<Record<string, unknown>> {
  const level = input.level ?? 'B1';
  const exam = input.exam ?? 'GENERAL';

  const prompts: Record<AssessmentType, string> = {
    answer_key: `Generate a complete answer key for the following exercises on "${input.topic}" at ${level} level for ${exam}.
${input.node_content ? `Exercises: ${JSON.stringify(input.node_content).slice(0, 1200)}` : '(no exercises provided — generate 5 typical exercises with answers)'}
Return JSON: {"answers": [{"question_number": 1, "answer": "...", "explanation": "..."}]}`,
    rubric: `Generate a grading rubric for a writing/speaking task on "${input.topic}" at ${level} level for ${exam}.
${input.node_content ? `Task context: ${JSON.stringify(input.node_content).slice(0, 600)}` : ''}
Return JSON: {"rubric": [{"criterion": "...", "weight": 25, "excellent": "...", "good": "...", "fair": "...", "poor": "..."}], "total_points": 100}`,
    exit_ticket: `Generate a 3-5 question exit ticket to check understanding of "${input.topic}" at ${level} level for ${exam}.
${input.node_content ? `Lesson content: ${JSON.stringify(input.node_content).slice(0, 800)}` : ''}
Return JSON: {"exit_ticket": [{"question": "...", "type": "multiple_choice|short_answer|true_false", "options": ["A","B","C","D"], "answer": "..."}]}`,
    auto_grade_config: `Generate an auto-grade configuration for exercises on "${input.topic}" at ${level} level for ${exam}.
${input.node_content ? `Exercises: ${JSON.stringify(input.node_content).slice(0, 1200)}` : ''}
Return JSON: {"gradable_items": [{"id": "q1", "type": "multiple_choice", "correct_answer": "B", "points": 1, "feedback_correct": "...", "feedback_incorrect": "..."}], "total_points": 10, "passing_score": 7}`,
    quiz: `Generate a 10-question quiz on "${input.topic}" at ${level} level for ${exam}, mixing question types.
Return JSON: {"quiz": [{"id": "q1", "type": "multiple_choice|fill_blank|true_false|short_answer", "question": "...", "options": ["A","B","C","D"], "answer": "...", "points": 1}], "total_points": 10}`,
  };

  const response = await fetch(OPENAI_CHAT_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: GENERATION_MODEL,
      messages: [
        { role: 'system', content: 'You are an expert English assessment creator for Indonesian students. Return ONLY valid JSON. No prose. No markdown fences.' },
        { role: 'user', content: prompts[input.type] },
      ],
      temperature: 0.5,
      max_tokens: 1500,
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
    return JSON.parse(json.choices[0].message.content);
  } catch {
    throw new Error('OpenAI did not return valid JSON for assessment');
  }
}