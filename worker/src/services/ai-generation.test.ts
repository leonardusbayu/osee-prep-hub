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
      chunk_text: 'IELTS reading passage about technology and society.',
      metadata: { tier: '1' },
      similarity: 0.89,
    },
  ]),
}));

import { generateMaterial } from './ai-generation';
import type { Env } from '../types';

const mockEnv = {
  OPENAI_API_KEY: 'test-openai-key',
} as unknown as Env;

describe('ai-generation service', () => {
  beforeEach(() => {
    mockFetch.mockClear();
  });

  it('generates material and returns structured result', async () => {
    const fakeResponse = {
      title: 'Technology and Society',
      passage: 'In recent years, technology has transformed...',
      questions: [
        { question: 'What is the main idea?', options: ['A', 'B', 'C', 'D'], correct: 'B', explanation: 'Because B' },
      ],
    };
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ choices: [{ message: { content: JSON.stringify(fakeResponse) } }] }),
    } as Response);

    const result = await generateMaterial(mockEnv, {
      type: 'reading',
      exam: 'IELTS',
      level: 'B2',
      topic: 'technology and society',
    });

    expect(result.type).toBe('reading');
    expect(result.exam).toBe('IELTS');
    expect(result.level).toBe('B2');
    expect(result.rag_context_used).toBe(1);
    expect(result.content.title).toBe('Technology and Society');
  });

  it('throws on empty topic', async () => {
    await expect(
      generateMaterial(mockEnv, { type: 'reading', exam: 'IELTS', level: 'B2', topic: '' })
    ).rejects.toThrow(/Topic required/);
  });

  it('throws on missing fields', async () => {
    await expect(
      generateMaterial(mockEnv, { type: 'reading' as never, exam: '', level: 'B2', topic: 'test' })
    ).rejects.toThrow(/type, exam, and level required/);
  });

  it('throws when OpenAI API fails', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 500,
      text: async () => 'Internal error',
    } as Response);

    await expect(
      generateMaterial(mockEnv, { type: 'reading', exam: 'IELTS', level: 'B2', topic: 'test' })
    ).rejects.toThrow(/OpenAI API error/);
  });

  it('throws when OpenAI returns invalid JSON', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ choices: [{ message: { content: 'not json {' } }] }),
    } as Response);

    await expect(
      generateMaterial(mockEnv, { type: 'reading', exam: 'IELTS', level: 'B2', topic: 'test' })
    ).rejects.toThrow(/valid JSON/);
  });

  it('proceeds even if RAG search fails (graceful degradation)', async () => {
    const ragSearch = (await import('../services/rag-search')).searchDocuments as ReturnType<typeof vi.fn>;
    ragSearch.mockImplementationOnce(async () => {
      throw new Error('RAG unavailable');
    });

    const fakeResponse = { title: 'Test', questions: [] };
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ choices: [{ message: { content: JSON.stringify(fakeResponse) } }] }),
    } as Response);

    const result = await generateMaterial(mockEnv, {
      type: 'vocabulary',
      exam: 'TOEFL_IBT',
      level: 'B1',
      topic: 'test',
    });
    expect(result.rag_context_used).toBe(0);
  });
});