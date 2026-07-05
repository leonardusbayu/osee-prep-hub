import type { Env } from '../types';

/**
 * Speaking evaluation bridge — Task 7.1.
 *
 * Bridges to EduBot's speaking evaluation route (Whisper + GPT).
 * EduBot route: POST /api/speaking/evaluate (FormData with audio file)
 * Returns: transcription, pronunciation score, fluency, feedback.
 *
 * Auth: EduBot uses Telegram-based auth. For Hub bridge, we use
 * EDUBOT_INTERNAL_SECRET header for service-to-service auth.
 */

export interface SpeakingEvaluationInput {
  audioUrl: string; // R2 URL of the audio recording
  examType?: string; // 'IELTS' | 'TOEFL_IBT' | 'TOEFL_ITP' | 'TOEIC'
  prompt?: string; // The speaking prompt/question
  level?: string; // CEFR level
}

export interface SpeakingEvaluationResult {
  transcription: string;
  pronunciation_score: number;
  fluency_score: number;
  coherence_score: number;
  vocabulary_score: number;
  grammar_score: number;
  overall_band: string;
  feedback: string;
  improvements: string[];
}

/** Evaluate a speaking recording via EduBot bridge. */
export async function evaluateSpeaking(
  env: Env,
  input: SpeakingEvaluationInput
): Promise<SpeakingEvaluationResult> {
  if (!input.audioUrl?.trim()) {
    throw new Error('audioUrl required');
  }

  // Call EduBot's speaking evaluation endpoint
  // EduBot expects FormData with audio file, but for Hub bridge we send
  // the R2 URL and let EduBot fetch it (or we send audio bytes directly).
  // For simplicity, we send the audio URL and EduBot fetches it.
  const edubotUrl = `${env.EDUBOT_API_URL}/api/speaking/evaluate`;

  const response = await fetch(edubotUrl, {
    method: 'POST',
    headers: {
      'X-Internal-Secret': env.EDUBOT_INTERNAL_SECRET,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      audio_url: input.audioUrl,
      exam_type: input.examType,
      prompt: input.prompt,
      level: input.level,
      source: 'hub-bridge',
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`EduBot speaking API error: ${response.status} ${errorText}`);
  }

  const result = (await response.json()) as Partial<SpeakingEvaluationResult> & {
    error?: { code: string; message: string };
  };

  if (result.error) {
    throw new Error(`EduBot error: ${result.error.message}`);
  }

  // Map EduBot response to Hub's SpeakingEvaluationResult shape
  return {
    transcription: result.transcription ?? '',
    pronunciation_score: result.pronunciation_score ?? 0,
    fluency_score: result.fluency_score ?? 0,
    coherence_score: result.coherence_score ?? 0,
    vocabulary_score: result.vocabulary_score ?? 0,
    grammar_score: result.grammar_score ?? 0,
    overall_band: result.overall_band ?? 'N/A',
    feedback: result.feedback ?? '',
    improvements: result.improvements ?? [],
  };
}