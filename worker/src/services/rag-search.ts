import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * RAG search service — vector search over knowledge_base_embeddings.
 *
 * Task 4.6: RAG search API endpoint.
 * Uses OpenAI text-embedding-3-small (1536 dimensions) to embed the query,
 * then calls the match_documents PostgreSQL function to find similar chunks.
 */

const OPENAI_EMBEDDINGS_URL = 'https://api.openai.com/v1/embeddings';
const EMBEDDING_MODEL = 'text-embedding-3-small';

export interface RagSearchResult {
  id: string;
  document_id: string;
  chunk_index: number;
  chunk_text: string;
  metadata: Record<string, unknown>;
  similarity: number;
}

/** Generate an embedding vector for a query string via OpenAI. */
export async function generateQueryEmbedding(env: Env, query: string): Promise<number[]> {
  if (!query || query.trim().length === 0) {
    throw new Error('Query required');
  }

  const response = await fetch(OPENAI_EMBEDDINGS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: query.trim().slice(0, 8000), // OpenAI token limit safeguard
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`OpenAI embeddings API error: ${response.status} ${errorText}`);
  }

  const json = (await response.json()) as {
    data: Array<{ embedding: number[] }>;
  };

  if (!json.data || !json.data[0] || !Array.isArray(json.data[0].embedding)) {
    throw new Error('Invalid OpenAI embeddings response');
  }

  return json.data[0].embedding;
}

/** Vector search — find chunks similar to the query. */
export async function searchDocuments(
  env: Env,
  query: string,
  options: { matchCount?: number; filter?: Record<string, unknown> } = {}
): Promise<RagSearchResult[]> {
  const matchCount = options.matchCount ?? 10;
  const filter = options.filter ?? {};

  // Generate embedding for the query
  const embedding = await generateQueryEmbedding(env, query);

  // Call match_documents function in Supabase
  const supabase = getSupabase(env);
  const { data, error } = await supabase.rpc('match_documents', {
    query_embedding: embedding,
    match_count: matchCount,
    filter: filter,
  });

  if (error) {
    throw new Error(`Vector search failed: ${error.message}`);
  }

  return (data ?? []) as RagSearchResult[];
}