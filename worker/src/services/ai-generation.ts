import type { Env } from '../types';
import { searchDocuments } from './rag-search';

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

  // RAG search for reference materials
  const ragQuery = `${input.exam} ${input.level} ${input.type} ${input.topic}`;
  const ragResults = await searchDocuments(env, ragQuery, {
    matchCount: 5,
    filter: { tier: '1' },
  }).catch(() => []);

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

  return {
    type: input.type,
    exam: input.exam,
    level: input.level,
    topic: input.topic,
    content,
    rag_context_used: ragResults.length,
  };
}

// ============================================================
// Mind-Map Recipe — teacher dumps topic + notes, AI generates a
// structured workbook unit (theory + examples + exercises + answers).
// Inspired by remalt.com's "dump ideas → AI generates" pattern.
// ============================================================

export interface MindMapRecipeInput {
  topic: string;
  notes: string;            // free-form teacher notes / ideas / bullets
  exam?: string;            // TOEFL_IBT | IELTS | GENERAL | ...
  level?: string;           // A1..C2
  item_type?: string;       // reading | grammar | vocab | ... (defaults to 'grammar')
  estimated_minutes?: number;
}

export interface MindMapRecipe {
  title: string;
  summary: string;
  theory: string;            // markdown-formatted explanation
  key_points: string[];      // bullet points
  examples: Array<{ input: string; output: string; explanation: string }>;
  exercises: Array<{
    question: string;
    options?: string[];
    answer: string;
    explanation: string;
    type: 'multiple_choice' | 'fill_blank' | 'short_answer' | 'rewrite';
  }>;
  vocabulary: Array<{ word: string; definition: string; example: string }>;
  practice_prompt: string;   // a free-form practice task for the student
  ai_generated_content: Record<string, unknown>; // full payload for syllabus_items
}

export async function generateMindMapRecipe(
  env: Env,
  input: MindMapRecipeInput
): Promise<MindMapRecipe> {
  if (!input.topic?.trim()) throw new Error('Topic required');
  if (!input.notes?.trim()) throw new Error('Notes required');

  const exam = input.exam ?? 'GENERAL';
  const level = input.level ?? 'B1';
  const itemType = input.item_type ?? 'grammar';

  // RAG search for reference materials
  const ragResults = await searchDocuments(env, `${exam} ${level} ${itemType} ${input.topic}`, {
    matchCount: 4,
    filter: { tier: '1' },
  }).catch(() => []);

  const ragContext = ragResults.map((r) => `- ${r.chunk_text.slice(0, 400)}`).join('\n');

  const systemPrompt = `You are an expert English teaching material creator for Indonesian students preparing for ${exam}.
CEFR level: ${level}
Material type: ${itemType}
Topic: ${input.topic}

Teacher's notes / ideas (use these as the seed — expand, structure, and enrich them):
${input.notes}

${ragContext ? `Reference materials:\n${ragContext}` : ''}

Generate a structured workbook unit as JSON with this exact shape:
{
  "title": "<concise title>",
  "summary": "<1-2 sentence summary of what the student will learn>",
  "theory": "<3-5 paragraphs of explanation in markdown. Include rules, patterns, and clear teaching points. Write in simple ${level}-level English.>",
  "key_points": ["<bullet 1>", "<bullet 2>", "..."],
  "examples": [{"input": "<example sentence or problem>", "output": "<correct form or answer>", "explanation": "<why>"}],
  "exercises": [
    {"type": "multiple_choice", "question": "...", "options": ["A","B","C","D"], "answer": "B", "explanation": "..."},
    {"type": "fill_blank", "question": "Fill in: ___", "answer": "...", "explanation": "..."},
    {"type": "rewrite", "question": "Rewrite this sentence using X: ...", "answer": "...", "explanation": "..."},
    {"type": "short_answer", "question": "...", "answer": "...", "explanation": "..."}
  ],
  "vocabulary": [{"word": "...", "definition": "...", "example": "..."}],
  "practice_prompt": "<a free-form practice task the student can do on their own>"
}

Include 5-8 exercises mixing the types. Make the theory practical, not academic. Use Indonesian-context examples where natural (e.g. names, places, scenarios familiar to Indonesian students). Return ONLY the JSON. No prose. No markdown fences.`;

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
        { role: 'user', content: `Generate the workbook unit for: ${input.topic}` },
      ],
      temperature: 0.7,
      max_tokens: 2500,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} ${errorText}`);
  }

  const json = (await response.json()) as { choices: Array<{ message: { content: string } }> };
  if (!json.choices?.[0]) throw new Error('Invalid OpenAI response: no choices');

  let parsed: Record<string, unknown>;
  try {
    parsed = JSON.parse(json.choices[0].message.content);
  } catch {
    throw new Error('OpenAI did not return valid JSON');
  }

  const recipe: MindMapRecipe = {
    title: (parsed.title as string) ?? input.topic,
    summary: (parsed.summary as string) ?? '',
    theory: (parsed.theory as string) ?? '',
    key_points: (parsed.key_points as string[]) ?? [],
    examples: (parsed.examples as MindMapRecipe['examples']) ?? [],
    exercises: (parsed.exercises as MindMapRecipe['exercises']) ?? [],
    vocabulary: (parsed.vocabulary as MindMapRecipe['vocabulary']) ?? [],
    practice_prompt: (parsed.practice_prompt as string) ?? '',
    ai_generated_content: parsed,
  };
  return recipe;
}