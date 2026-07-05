import type { Env } from '../types';
import { searchDocuments } from './rag-search';

/**
 * AI grading service — evaluates essays using GPT-4o-mini with RAG context.
 *
 * Task 5.1: gradeWriting service
 * Task 5.2: Grading queue system (uses ai_grading_queue table)
 */

const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';
const GRADING_MODEL = 'gpt-4o-mini';

export interface GradeWritingInput {
  essay: string;
  rubric: string; // 'ielts_task1' | 'ielts_task2' | 'toefl_ibt' | 'toefl_itp' | 'toeic'
  examType: string; // 'IELTS' | 'TOEFL_IBT' | 'TOEFL_ITP' | 'TOEIC'
  level?: string; // CEFR level: A1-C2
}

export interface CriteriaScore {
  criterion: string;
  score: number;
  max_score: number;
  feedback: string;
}

export interface GradeWritingResult {
  score: number;
  band: string;
  feedback: string;
  criteria_scores: CriteriaScore[];
  improvements: string[];
  rag_context_used: number;
}

/** Grade an essay using GPT-4o-mini + RAG context. */
export async function gradeWriting(env: Env, input: GradeWritingInput): Promise<GradeWritingResult> {
  // Validate input
  if (!input.essay || input.essay.trim().length === 0) {
    throw new Error('Essay required');
  }
  if (input.essay.length > 20_000) {
    throw new Error('Essay too long (max 20,000 chars)');
  }
  if (!input.rubric || !input.examType) {
    throw new Error('rubric and examType required');
  }

  // RAG search for relevant rubric/assessment criteria
  const ragQuery = `${input.examType} ${input.rubric} writing assessment criteria ${input.level ?? ''}`;
  const ragResults = await searchDocuments(env, ragQuery, {
    matchCount: 5,
    filter: { tier: '1' },
  }).catch((err) => {
    console.warn('RAG search failed, proceeding without context:', err);
    return [];
  });

  // Build prompt with RAG context
  const ragContext = ragResults
    .map((r) => `- ${r.chunk_text.slice(0, 500)}`)
    .join('\n');

  const systemPrompt = `You are an expert English language assessor for ${input.examType}.
Rubric: ${input.rubric}
Target CEFR level: ${input.level ?? 'B2'}

Reference assessment criteria:
${ragContext || '(no RAG context available — use standard assessment criteria)'}

Evaluate the essay and return JSON with this exact structure:
{
  "score": <number — overall score>,
  "band": "<string — e.g. '6.5' for IELTS, '24' for TOEFL iBT>",
  "feedback": "<2-3 sentence overall feedback>",
  "criteria_scores": [
    { "criterion": "task_achievement", "score": <number>, "max_score": <number>, "feedback": "<string>" },
    { "criterion": "coherence_cohesion", "score": <number>, "max_score": <number>, "feedback": "<string>" },
    { "criterion": "lexical_resource", "score": <number>, "max_score": <number>, "feedback": "<string>" },
    { "criterion": "grammatical_range", "score": <number>, "max_score": <number>, "feedback": "<string>" }
  ],
  "improvements": ["<specific improvement suggestion 1>", "<suggestion 2>", "<suggestion 3>"]
}

Return ONLY the JSON. No prose. No markdown fences.`;

  const userPrompt = `Essay to evaluate:\n\n${input.essay}`;

  // Call OpenAI
  const response = await fetch(OPENAI_CHAT_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: GRADING_MODEL,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.3,
      max_tokens: 1500,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} ${errorText}`);
  }

  const json = (await response.json()) as {
    choices: Array<{ message: { content: string } }>;
  };

  if (!json.choices || !json.choices[0]) {
    throw new Error('Invalid OpenAI response: no choices');
  }

  // Parse the JSON content
  let result: Omit<GradeWritingResult, 'rag_context_used'>;
  try {
    result = JSON.parse(json.choices[0].message.content);
  } catch {
    throw new Error('OpenAI did not return valid JSON');
  }

  return {
    ...result,
    rag_context_used: ragResults.length,
  };
}