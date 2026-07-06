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

// ============================================================
// Per-node AI generation (remalt-style multi-node pipeline)
// Each output type is generated independently so the teacher can
// regenerate or refine one node without re-running the whole recipe.
// ============================================================

export type NodeType = 'theory' | 'exercises' | 'vocabulary' | 'practice' | 'examples';

export interface LinkedNodeContent {
  nodeId: string;
  type: string;
  title: string;
  content: Record<string, unknown>;
}

export interface NodeGenInput {
  topic: string;
  notes: string;
  exam?: string;
  level?: string;
  item_type?: string;
  context?: string; // output from other nodes, passed as context
  difficulty?: string; // 'easy' | 'medium' | 'hard' | 'expert' — adjusts generated content difficulty
  kp_tags?: Array<{ code: string; label: string }>; // Kurikulum Merdeka competency tags
  linked_nodes?: LinkedNodeContent[]; // upstream node contents for edge-aware pipeline
}

/** Generate a single output node. Returns the node's content as JSON. */
export async function generateNode(
  env: Env,
  type: NodeType,
  input: NodeGenInput
): Promise<Record<string, unknown>> {
  if (!input.topic?.trim()) throw new Error('Topic required');
  const exam = input.exam ?? 'GENERAL';
  const level = input.level ?? 'B1';
  const itemType = input.item_type ?? 'grammar';
  const difficulty = input.difficulty ?? 'medium';
  const kpLine = input.kp_tags && input.kp_tags.length > 0
    ? `Align to Kurikulum Merdeka competencies: ${input.kp_tags.map((k) => `${k.code} (${k.label})`).join(', ')}.`
    : '';
  const linkedLine = input.linked_nodes && input.linked_nodes.length > 0
    ? `Upstream node outputs (use as source material, do not repeat verbatim):\n${input.linked_nodes.map((n) => `- ${n.title} (${n.type}): ${JSON.stringify(n.content).slice(0, 400)}`).join('\n')}`
    : '';
  const difficultyLine = `Difficulty: ${difficulty}. Adjust vocabulary complexity, sentence length, and cognitive demand to match.`;

  const prompts: Record<NodeType, string> = {
    theory: `Generate a theory explanation for ${itemType} on "${input.topic}" at ${level} level for ${exam}.
Teacher's notes: ${input.notes}
${difficultyLine}
${kpLine}
${input.context ? `Context from other nodes: ${input.context}` : ''}
${linkedLine}
Return JSON: {"title": "...", "summary": "...", "theory": "<3-5 paragraphs markdown explanation>", "key_points": ["...", "..."]}`,
    examples: `Generate worked examples for ${itemType} on "${input.topic}" at ${level} level.
Teacher's notes: ${input.notes}
${difficultyLine}
${kpLine}
${input.context ? `Theory context: ${input.context.slice(0, 800)}` : ''}
${linkedLine}
Return JSON: {"examples": [{"input": "...", "output": "...", "explanation": "..."}]}`,
    exercises: `Generate practice exercises for ${itemType} on "${input.topic}" at ${level} level for ${exam}.
Teacher's notes: ${input.notes}
${difficultyLine}
${kpLine}
${input.context ? `Theory context: ${input.context.slice(0, 800)}` : ''}
${linkedLine}
Return JSON: {"exercises": [{"type": "multiple_choice|fill_blank|rewrite|short_answer", "question": "...", "options": ["A","B","C","D"], "answer": "...", "explanation": "..."}]}
Include 6-8 exercises mixing types. Use Indonesian-context scenarios where natural.`,
    vocabulary: `Generate a vocabulary list for "${input.topic}" at ${level} level.
Teacher's notes: ${input.notes}
${difficultyLine}
${kpLine}
${linkedLine}
Return JSON: {"vocabulary": [{"word": "...", "definition": "...", "example": "..."}]}
Include 5-8 key terms relevant to the topic.`,
    practice: `Generate a free-form practice task for "${input.topic}" at ${level} level.
Teacher's notes: ${input.notes}
${difficultyLine}
${kpLine}
${input.context ? `Context: ${input.context.slice(0, 500)}` : ''}
${linkedLine}
Return JSON: {"practice_prompt": "...", "practice_type": "writing|speaking|reading|research"}`,
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
        { role: 'system', content: `You are an expert English teaching material creator for Indonesian students. CEFR ${level}. Return ONLY valid JSON. No prose. No markdown fences.` },
        { role: 'user', content: prompts[type] },
      ],
      temperature: 0.7,
      max_tokens: type === 'theory' ? 1800 : 1200,
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
    throw new Error('OpenAI did not return valid JSON');
  }
}

// ============================================================
// Specialist agent chat — refine a generated node via conversation.
// Like remalt's platform-specific agents (LinkedIn, Instagram, YouTube),
// we have skill-specific agents (reading, speaking, writing) that can
// refine the generated material.
// ============================================================

export type AgentType = 'reading' | 'speaking' | 'writing' | 'general';

export interface AgentChatInput {
  agent: AgentType;
  message: string;
  context: string; // the current node content being refined
  topic: string;
  exam?: string;
  level?: string;
  history?: Array<{ role: 'user' | 'assistant'; content: string }>;
}

const AGENT_PERSONAS: Record<AgentType, string> = {
  reading: `You are a reading comprehension specialist. You help teachers refine reading materials — passages, questions, inference drills. Focus on text difficulty, question quality, and CEFR alignment.`,
  speaking: `You are a speaking practice specialist. You help teachers refine speaking prompts, pronunciation drills, and conversation activities. Focus on fluency, accuracy, and natural speech patterns.`,
  writing: `You are a writing instruction specialist. You help teachers refine writing prompts, essay rubrics, and feedback frameworks. Focus on structure, coherence, and exam-specific writing criteria.`,
  general: `You are an expert English teaching assistant. Help the teacher refine their material — suggest improvements, add examples, adjust difficulty, fix errors.`,
};

export async function agentChat(
  env: Env,
  input: AgentChatInput
): Promise<{ reply: string; suggestions?: string[] }> {
  if (!input.message?.trim()) throw new Error('Message required');

  const systemPrompt = `${AGENT_PERSONAS[input.agent]}

Topic: ${input.topic}
CEFR level: ${input.level ?? 'B1'}
Exam: ${input.exam ?? 'GENERAL'}

Current material being refined:
${input.context.slice(0, 1500)}

Help the teacher improve this material. Be specific and practical. If they ask for changes, show the revised version. If they ask a question, answer concisely.`;

  const messages: Array<{ role: string; content: string }> = [
    { role: 'system', content: systemPrompt },
    ...(input.history ?? []).map((h) => ({ role: h.role, content: h.content })),
    { role: 'user', content: input.message },
  ];

  const response = await fetch(OPENAI_CHAT_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: GENERATION_MODEL,
      messages,
      temperature: 0.7,
      max_tokens: 1000,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI API error: ${response.status} ${errorText}`);
  }

  const json = (await response.json()) as { choices: Array<{ message: { content: string } }> };
  if (!json.choices?.[0]) throw new Error('Invalid OpenAI response: no choices');

  return { reply: json.choices[0].message.content };
}

// ============================================================
// Image generation — DALL-E 3 for lesson illustrations
// ============================================================

const OPENAI_IMAGES_URL = 'https://api.openai.com/v1/images/generations';
const IMAGE_MODEL = 'gpt-image-1';
const ALLOWED_IMAGE_SIZES = ['1024x1024', '1024x1792', '1792x1024'] as const;
type ImageSize = (typeof ALLOWED_IMAGE_SIZES)[number];

export type ImageType = 'illustration' | 'cover' | 'infographic' | 'vocabulary' | 'icon' | 'scene';

export interface GenerateImageInput {
  type: ImageType;
  topic: string;
  description?: string;  // detailed description of what to draw
  exam?: string;
  level?: string;
  size?: ImageSize;
}

export interface GeneratedImage {
  type: ImageType;
  url: string;        // public URL of the generated image (expires in ~1hr)
  revised_prompt: string;
  size: ImageSize;
  metadata: Record<string, unknown>;
}

export async function generateImage(env: Env, input: GenerateImageInput): Promise<GeneratedImage> {
  if (!input.topic?.trim()) throw new Error('Topic required');
  const size: ImageSize = (input.size && ALLOWED_IMAGE_SIZES.includes(input.size)) ? input.size : '1024x1024';

  // Build a detailed prompt based on the image type
  const prompt = buildImagePrompt(input);

  let response: Response;
  try {
    response = await fetch(OPENAI_IMAGES_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
    body: JSON.stringify({
      model: IMAGE_MODEL,
      prompt,
      n: 1,
      size,
    }),
    });
  } catch (err) {
    throw new Error(`Fetch failed: ${err instanceof Error ? err.message : 'unknown'}`);
  }

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`OpenAI images API error: ${response.status} ${errText}`);
  }

  const json = (await response.json()) as {
    data: Array<{ url?: string; b64_json?: string; revised_prompt?: string }>;
  };

  if (!json.data?.[0]) {
    throw new Error('Invalid OpenAI images response: no data');
  }

  const item = json.data[0];
  // gpt-image-1 returns b64_json, dall-e-3 returns url
  let url = item.url ?? '';
  if (!url && item.b64_json) {
    url = `data:image/png;base64,${item.b64_json}`;
  }
  if (!url) {
    throw new Error('Invalid OpenAI images response: no URL');
  }

  return {
    type: input.type,
    url,
    revised_prompt: item.revised_prompt ?? prompt,
    size,
    metadata: {
      topic: input.topic,
      exam: input.exam,
      level: input.level,
      description: input.description,
    },
  };
}

/** Build a detailed DALL-E prompt based on the image type and topic. */
function buildImagePrompt(input: GenerateImageInput): string {
  const level = input.level ?? 'B2';
  const exam = input.exam ?? 'English language learning';
  const baseContext = `Educational illustration for ${level} level ${exam} students.`;
  const userDesc = input.description ? ` ${input.description}` : '';

  switch (input.type) {
    case 'cover':
      return `${baseContext} Magazine-quality cover image for a lesson on "${input.topic}". ${userDesc} Style: clean, editorial, vibrant colors, bold typography-safe composition with space for a title. Professional, eye-catching, suitable for a modern education platform.`;
    case 'illustration':
      return `${baseContext} Flat illustration depicting "${input.topic}". ${userDesc} Style: modern, clean lines, vibrant but harmonious color palette, suitable for an educational app. Friendly, approachable, no text in the image.`;
    case 'infographic':
      return `${baseContext} Infographic-style visual showing the key concept of "${input.topic}". ${userDesc} Style: organized layout with visual elements, icons, and clear sections. Modern flat design, good for teaching, no actual text or labels.`;
    case 'vocabulary':
      return `${baseContext} Visual aid for teaching vocabulary related to "${input.topic}". ${userDesc} Style: clean, colorful, with space for a word to be added later. Educational, friendly, suitable for a flashcard.`;
    case 'icon':
      return `${baseContext} Icon representing "${input.topic}". ${userDesc} Style: simple, bold, single-color icon on a clean white background. Modern, recognizable, suitable for a button or category label.`;
    case 'scene':
      return `${baseContext} Illustrative scene showing "${input.topic}" in a real-life context. ${userDesc} Style: warm, inclusive, depicting students or teachers in action. Warm lighting, modern classroom or everyday setting, no text in the image.`;
    default:
      return `${baseContext} Visual for "${input.topic}". ${userDesc}`;
  }
}