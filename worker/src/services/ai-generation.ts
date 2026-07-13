import type { Env } from '../types';
import { searchDocuments } from './rag-search';
import { validateContent } from './content-validator';

/**
 * AI material generation service — Task 6.1.
 *
 * Uses GPT-4o-mini + RAG context to generate study materials:
 * reading passages, listening scripts, grammar exercises, vocabulary sets, etc.
 */

const OPENAI_CHAT_URL = 'https://api.openai.com/v1/chat/completions';
const GENERATION_MODEL = 'gpt-4o-mini';

export type MaterialType =
  | 'reading'
  | 'listening'
  | 'speaking'
  | 'writing'
  | 'grammar'
  | 'vocabulary'
  | 'mock_test';

export interface GenerateMaterialInput {
  type: MaterialType;
  exam: string; // 'TOEFL_IBT' | 'TOEFL_ITP' | 'IELTS' | 'TOEIC' | 'GENERAL'
  level: string; // 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2'
  topic: string;
  options?: {
    wordCount?: number;
    questionCount?: number;
    difficulty?: string;
  };
}

export interface GeneratedMaterial {
  type: MaterialType;
  exam: string;
  level: string;
  topic: string;
  content: Record<string, unknown>;
  rag_context_used: number;
  validation_status?: string;
  validation_warnings?: string[];
}

/** Generate study material using GPT-4o-mini + RAG context. */
export async function generateMaterial(
  env: Env,
  input: GenerateMaterialInput
): Promise<GeneratedMaterial> {
  // Validate input
  if (!input.topic || input.topic.trim().length === 0) {
    throw new Error('Topic required');
  }
  if (!input.type || !input.exam || !input.level) {
    throw new Error('type, exam, and level required');
  }

  // RAG search for reference materials — map generation_type to category (blueprint line 1998-2001)
  const categoryMap: Record<string, string> = {
    reading: 'question_templates',
    listening: 'question_templates',
    writing: 'question_templates',
    speaking: 'question_templates',
    mock_test: 'question_templates',
    grammar: 'grammar',
    vocabulary: 'vocabulary',
  };
  const ragCategory = categoryMap[input.type] ?? 'question_templates';

  const ragQuery = `${input.exam} ${input.level} ${input.type} ${input.topic}`;
  const ragResults = await searchDocuments(env, ragQuery, {
    matchCount: 5,
    filter: { tier: '1', category: ragCategory },
  }).catch(() => []);

  // Fallback: if category filter returns nothing, search without category
  let finalRagResults = ragResults;
  if (ragResults.length === 0) {
    finalRagResults = await searchDocuments(env, ragQuery, {
      matchCount: 5,
      filter: { tier: '1' },
    }).catch(() => []);
  }

  const ragContext = ragResults
    .map((r) => `- ${r.chunk_text.slice(0, 500)}`)
    .join('\n');

  const systemPrompt = `You are an expert English language teaching material creator for ${input.exam}.
Target CEFR level: ${input.level}
Material type: ${input.type}
Topic: ${input.topic}

Reference materials:
${ragContext || '(no RAG context — use standard pedagogical approach)'}

Generate the material as JSON with this structure:
{
  "title": "<string>",
  "passage": "<string — for reading/writing materials>",
  "script": "<string — for listening/speaking materials>",
  "questions": [{"question": "<string>", "options": ["A", "B", "C", "D"], "correct": "B", "explanation": "<string>"}],
  "vocabulary": [{"word": "<string>", "definition": "<string>", "example": "<string>"}],
  "answer_key": "<string — if applicable>"
}

Return ONLY the JSON. No prose. No markdown fences.`;

  const userPrompt = `Generate ${input.type} material about: ${input.topic}
${input.options?.wordCount ? `Word count: ~${input.options.wordCount}` : ''}
${input.options?.questionCount ? `Question count: ${input.options.questionCount}` : ''}
${input.options?.difficulty ? `Difficulty: ${input.options.difficulty}` : ''}`;

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
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 2000,
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

  if (!json.choices?.[0]) {
    throw new Error('Invalid OpenAI response: no choices');
  }

  let content: Record<string, unknown>;
  try {
    content = JSON.parse(json.choices[0].message.content);
  } catch {
    throw new Error('OpenAI did not return valid JSON');
  }

  // Validate generated content (Task 6.4)
  const validation = validateContent(content);
  if (!validation.valid) {
    console.warn('Content validation issues:', validation.issues);
  }

  return {
    type: input.type,
    exam: input.exam,
    level: input.level,
    topic: input.topic,
    content,
    rag_context_used: finalRagResults.length,
    validation_status: validation.valid ? 'passed' : 'needs_review',
    validation_warnings: validation.warnings,
  };
}