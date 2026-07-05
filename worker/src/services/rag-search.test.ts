import { describe, it, expect, vi, beforeEach } from 'vitest';

// Mock fetch for OpenAI API calls
const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

// Mock Supabase
const mockRpc = vi.fn();
vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => ({ rpc: mockRpc })),
}));

import { generateQueryEmbedding, searchDocuments } from './rag-search';
import type { Env } from '../types';

const mockEnv = {
  OPENAI_API_KEY: 'test-openai-key',
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('rag-search service', () => {
  beforeEach(() => {
    mockFetch.mockClear();
    mockRpc.mockClear();
  });

  it('generates embedding via OpenAI API', async () => {
    const fakeEmbedding = new Array(1536).fill(0.1);
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [{ embedding: fakeEmbedding }] }),
    } as Response);

    const embedding = await generateQueryEmbedding(mockEnv, 'CEFR B1 writing assessment');
    expect(embedding).toHaveLength(1536);
    expect(mockFetch).toHaveBeenCalledOnce();
    const call = mockFetch.mock.calls[0];
    expect(call[0]).toBe('https://api.openai.com/v1/embeddings');
    const opts = call[1] as RequestInit;
    expect(opts.method).toBe('POST');
    const headers = opts.headers as Record<string, string>;
    expect(headers.Authorization).toBe('Bearer test-openai-key');
    const body = JSON.parse(opts.body as string);
    expect(body.model).toBe('text-embedding-3-small');
    expect(body.input).toBe('CEFR B1 writing assessment');
  });

  it('throws on empty query', async () => {
    await expect(generateQueryEmbedding(mockEnv, '')).rejects.toThrow(/Query required/);
    await expect(generateQueryEmbedding(mockEnv, '   ')).rejects.toThrow(/Query required/);
  });

  it('throws when OpenAI API returns error', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: false,
      status: 401,
      text: async () => 'Unauthorized',
    } as Response);

    await expect(generateQueryEmbedding(mockEnv, 'test query')).rejects.toThrow(/OpenAI embeddings API error/);
  });

  it('throws on invalid OpenAI response', async () => {
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [] }),
    } as Response);

    await expect(generateQueryEmbedding(mockEnv, 'test query')).rejects.toThrow(/Invalid OpenAI embeddings response/);
  });

  it('searchDocuments calls match_documents RPC with embedding + filter', async () => {
    const fakeEmbedding = new Array(1536).fill(0.2);
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [{ embedding: fakeEmbedding }] }),
    } as Response);

    const fakeResults = [
      {
        id: 'chunk-1',
        document_id: 'doc-1',
        chunk_index: 0,
        chunk_text: 'CEFR B1 writing descriptors...',
        metadata: { tier: '1', source: 'CEFR' },
        similarity: 0.92,
      },
    ];
    mockRpc.mockResolvedValueOnce({ data: fakeResults, error: null });

    const results = await searchDocuments(mockEnv, 'CEFR B1 writing', {
      matchCount: 5,
      filter: { tier: '1' },
    });

    expect(results).toHaveLength(1);
    expect(results[0].chunk_text).toContain('CEFR B1');
    expect(mockRpc).toHaveBeenCalledOnce();
    const rpcCall = mockRpc.mock.calls[0];
    expect(rpcCall[0]).toBe('match_documents');
    expect(rpcCall[1].match_count).toBe(5);
    expect(rpcCall[1].filter).toEqual({ tier: '1' });
    expect(rpcCall[1].query_embedding).toHaveLength(1536);
  });

  it('searchDocuments throws when RPC fails', async () => {
    const fakeEmbedding = new Array(1536).fill(0.3);
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [{ embedding: fakeEmbedding }] }),
    } as Response);
    mockRpc.mockResolvedValueOnce({ data: null, error: { message: 'RPC failed' } });

    await expect(searchDocuments(mockEnv, 'test')).rejects.toThrow(/Vector search failed/);
  });

  it('searchDocuments returns empty array when no matches', async () => {
    const fakeEmbedding = new Array(1536).fill(0.4);
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [{ embedding: fakeEmbedding }] }),
    } as Response);
    mockRpc.mockResolvedValueOnce({ data: [], error: null });

    const results = await searchDocuments(mockEnv, 'obscure query with no matches');
    expect(results).toEqual([]);
  });

  it('truncates very long queries to 8000 chars', async () => {
    const longQuery = 'a'.repeat(10000);
    mockFetch.mockResolvedValueOnce({
      ok: true,
      json: async () => ({ data: [{ embedding: new Array(1536).fill(0) }] }),
    } as Response);

    await generateQueryEmbedding(mockEnv, longQuery);
    const call = mockFetch.mock.calls[0];
    const body = JSON.parse((call[1] as RequestInit).body as string);
    expect(body.input.length).toBe(8000);
  });
});