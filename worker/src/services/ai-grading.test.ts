import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock fetch for OpenAI
const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

// Mock RAG search
vi.mock('../services/rag-search', () => ({
  searchDocuments: vi.fn(async () => [
    {
      id: 'chunk-1',
      document_id: 'doc-1',
      chunk_index: 0,
      chunk_text: 'IELTS Task 2 assessment criteria: Task Achievement, Coherence, Lexical Resource, Grammatical Range.',
      metadata: { tier: '1' },
      similarity: 0.91,
    },
  ]),
}));

import { gradeWriting } from './ai-grading';
import type { Env } from '../types';

const mockEnv = {
  OPENAI_API_KEY: 'test-openai-key',
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('ai-grading service', () => {
  beforeEach(() => {
    mockFetch.mockClear();
  });

  it('grades an essay and returns structured result', async () => {
    const fakeResponse = {
      score: 6.5,
      band: '6.5',
      feedback: 'Good essay with clear structure.',
      criteria_scores: [
        { criterion: 'task_achievement', score: 7, max_score: 9, feedback: 'Addresses task well.' },
        { criterion: 'coherence_cohesion', score: 6, max_score: 9, feedback: 'Logical organization.' },
      ],
      improvements: ['Use more varied vocabulary', 'Check article usage'],
    };
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        choices: [{ message: { content: JSON.stringify(fakeResponse) } }],
      }),
    } as Response);

    const result = await gradeWriting(mockEnv, {
      essay: 'Some essay about technology...',
      rubric: 'ielts_task2',
      examType: 'IELTS',
      level: 'B2',
    });

    expect(result.score).toBe(6.5);
    expect(result.band).toBe('6.5');
    expect(result.criteria_scores).toHaveLength(2);
    expect(result.improvements).toHaveLength(2);
    expect(result.rag_context_used).toBe(1);
  });

  it('throws on empty essay', async () => {
    await expect(
      gradeWriting(mockEnv, { essay: '', rubric: 'ielts_task2', examType: 'IELTS' })
    ).rejects.toThrow(/Essay required/);
  });

  it('throws on essay over 20,000 chars', async () => {
    const longEssay = 'a'.repeat(20001);
    await expect(
      gradeWriting(mockEnv, { essay: longEssay, rubric: 'ielts_task2', examType: 'IELTS' })
    ).rejects.toThrow(/Essay too long/);
  });

  it('throws when OpenAI API fails', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 401,
      text: async () => 'Unauthorized',
    } as Response);

    await expect(
      gradeWriting(mockEnv, { essay: 'test', rubric: 'ielts_task2', examType: 'IELTS' })
    ).rejects.toThrow(/OpenAI API error/);
  });

  it('throws when OpenAI returns invalid JSON', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({
        choices: [{ message: { content: 'not valid json {' } }],
      }),
    } as Response);

    await expect(
      gradeWriting(mockEnv, { essay: 'test', rubric: 'ielts_task2', examType: 'IELTS' })
    ).rejects.toThrow(/valid JSON/);
  });

  it('proceeds even if RAG search fails (graceful degradation)', async () => {
    // Re-mock RAG search to throw
    const ragSearch = (await import('../services/rag-search')).searchDocuments as ReturnType<typeof vi.fn>;
    ragSearch.mockImplementationOnce(async () => {
      throw new Error('RAG unavailable');
    });

    const fakeResponse = { score: 5, band: '5', feedback: 'ok', criteria_scores: [], improvements: [] };
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ choices: [{ message: { content: JSON.stringify(fakeResponse) } }] }),
    } as Response);

    const result = await gradeWriting(mockEnv, {
      essay: 'test essay',
      rubric: 'ielts_task2',
      examType: 'IELTS',
    });
    expect(result.rag_context_used).toBe(0);
  });
});