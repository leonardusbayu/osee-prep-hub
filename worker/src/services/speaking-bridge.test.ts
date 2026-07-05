import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock fetch for EduBot API calls
const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

import { evaluateSpeaking } from './speaking-bridge';
import type { Env } from '../types';

const mockEnv = {
  EDUBOT_API_URL: 'https://edubot.test.com',
  EDUBOT_INTERNAL_SECRET: 'test-secret',
} as unknown as Env;

describe('speaking-bridge service', () => {
  beforeEach(() => {
    mockFetch.mockClear();
  });

  it('calls EduBot speaking evaluate endpoint with audio_url + secret', async () => {
    const fakeResult = {
      transcription: 'I think technology is important...',
      pronunciation_score: 7,
      fluency_score: 6,
      coherence_score: 7,
      vocabulary_score: 6,
      grammar_score: 7,
      overall_band: '6.5',
      feedback: 'Good attempt with clear structure.',
      improvements: ['Work on intonation', 'Use more varied vocabulary'],
    };
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => fakeResult,
    } as Response);

    const result = await evaluateSpeaking(mockEnv, {
      audioUrl: 'https://audio.osee.co.id/audio/user1/test.webm',
      examType: 'IELTS',
      prompt: 'Describe a technology you use daily',
      level: 'B2',
    });

    expect(result.transcription).toContain('technology');
    expect(result.overall_band).toBe('6.5');
    expect(result.improvements).toHaveLength(2);

    // Verify the fetch call
    expect(mockFetch).toHaveBeenCalledOnce();
    const call = mockFetch.mock.calls[0];
    expect(call[0]).toBe('https://edubot.test.com/api/speaking/evaluate');
    const opts = call[1] as RequestInit;
    const headers = opts.headers as Record<string, string>;
    expect(headers['X-Internal-Secret']).toBe('test-secret');
    const body = JSON.parse(opts.body as string);
    expect(body.audio_url).toContain('audio.osee.co.id');
    expect(body.source).toBe('hub-bridge');
  });

  it('throws on empty audio_url', async () => {
    await expect(evaluateSpeaking(mockEnv, { audioUrl: '' })).rejects.toThrow(/audioUrl required/);
  });

  it('throws when EduBot API fails', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
      text: async () => 'Internal error',
    } as Response);

    await expect(
      evaluateSpeaking(mockEnv, { audioUrl: 'https://test.com/audio.webm' })
    ).rejects.toThrow(/EduBot speaking API error/);
  });

  it('throws when EduBot returns error in response body', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ error: { code: 'PREMIUM_REQUIRED', message: 'Premium required' } }),
    } as Response);

    await expect(
      evaluateSpeaking(mockEnv, { audioUrl: 'https://test.com/audio.webm' })
    ).rejects.toThrow(/Premium required/);
  });

  it('provides default values for missing fields', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({}), // empty response
    } as Response);

    const result = await evaluateSpeaking(mockEnv, { audioUrl: 'https://test.com/audio.webm' });
    expect(result.transcription).toBe('');
    expect(result.pronunciation_score).toBe(0);
    expect(result.improvements).toEqual([]);
    expect(result.overall_band).toBe('N/A');
  });
});