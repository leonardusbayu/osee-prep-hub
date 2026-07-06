import type { Env } from '../types';
import { getSupabase } from './supabase';
import { generateQueryEmbedding } from './rag-search';
import { ingestSource } from './content-ingestion';
import type { IngestSourceInput, IngestedSource } from './content-ingestion';

/**
 * Knowledge cluster service — teaching-focused source management.
 *
 * Unlike remalt's flat "dump everything" approach, this system:
 *  1. Batch-ingests multiple sources (URLs, YouTube, PDFs, text) in one call
 *  2. Auto-embeds each source into knowledge_base_embeddings (RAG) so the AI
 *     can do semantic search across all sources instead of cramming them
 *     into one prompt (handles 50+ sources without token overflow)
 *  3. Supports source clusters — labeled groups of sources (e.g. "Textbook ch3",
 *     "YouTube tutorials") that the AI uses as metadata context
 *  4. Uses RAG search to pull only the relevant chunks for each topic
 *
 * The mind-map nodes call searchKnowledge() to find relevant source chunks
 * for the topic being generated, instead of receiving all sources as raw text.
 */

const OPENAI_EMBEDDINGS_URL = 'https://api.openai.com/v1/embeddings';
const EMBEDDING_MODEL = 'text-embedding-3-small';
const MAX_CHUNK_CHARS = 2000;
const CHUNK_OVERLAP = 200;

// ============================================================
// Types
// ============================================================

export interface BatchIngestInput {
  sources: IngestSourceInput[];
  cluster_label?: string;  // e.g. "Textbook chapter 3", "YouTube tutorials"
  teacher_id: string;
}

export interface BatchIngestResult {
  ingested: IngestedSource[];
  embedded_count: number;
  cluster_id?: string;
  errors: Array<{ index: number; error: string }>;
}

// ============================================================
// Source clusters — labeled groups of sources
// ============================================================

/**
 * Create a source cluster — a labeled group of ingested sources.
 * Clusters help the AI understand *why* sources are grouped together.
 */
export async function createCluster(
  env: Env,
  teacherId: string,
  label: string,
  description?: string
): Promise<string> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('knowledge_base_documents')
    .insert({
      title: label,
      source: 'teacher_cluster',
      source_author: null,
      source_publisher: null,
      source_url: null,
      source_license: null,
      category: 'cluster',
      subcategory: description ?? null,
      cefr_level: null,
      content: description ?? '',
      content_chunk_count: 0,
      metadata: { teacher_id: teacherId, is_cluster: true },
      uploaded_by: teacherId,
      is_active: true,
    })
    .select()
    .single();

  if (error || !data) {
    throw new Error(`Failed to create cluster: ${error?.message ?? 'unknown'}`);
  }
  return (data as Record<string, unknown>).id as string;
}

// ============================================================
// Batch ingest — multiple sources in one call
// ============================================================

export async function batchIngest(env: Env, input: BatchIngestInput): Promise<BatchIngestResult> {
  const ingested: IngestedSource[] = [];
  const errors: Array<{ index: number; error: string }> = [];
  let embeddedCount = 0;

  // Create cluster if label provided
  let clusterId: string | undefined;
  if (input.cluster_label?.trim()) {
    try {
      clusterId = await createCluster(env, input.teacher_id, input.cluster_label);
    } catch (e) {
      // Non-fatal — sources still get ingested without a cluster
      console.error('Cluster creation failed (non-fatal):', e);
    }
  }

  // Ingest each source in parallel (but limit concurrency to 5)
  const batchSize = 5;
  for (let i = 0; i < input.sources.length; i += batchSize) {
    const batch = input.sources.slice(i, i + batchSize);
    const results = await Promise.allSettled(
      batch.map((src) => ingestSource(env, src))
    );

    for (let j = 0; j < results.length; j++) {
      const result = results[j];
      const sourceIndex = i + j;
      if (result.status === 'fulfilled') {
        ingested.push(result.value);
        // Auto-embed into RAG
        try {
          await embedSource(env, result.value, input.teacher_id, clusterId);
          embeddedCount++;
        } catch (e) {
          console.error(`Embedding failed for source ${sourceIndex} (non-fatal):`, e);
        }
      } else {
        errors.push({
          index: sourceIndex,
          error: result.reason instanceof Error ? result.reason.message : 'Unknown error',
        });
      }
    }
  }

  return {
    ingested,
    embedded_count: embeddedCount,
    cluster_id: clusterId,
    errors,
  };
}

// ============================================================
// Auto-embed — chunk + embed a source into knowledge_base_embeddings
// ============================================================

export async function embedSource(
  env: Env,
  source: IngestedSource,
  teacherId: string,
  clusterId?: string
): Promise<void> {
  const supabase = getSupabase(env);

  // 1. Create a knowledge_base_documents record
  const docInsert: Record<string, unknown> = {
    title: source.title,
    source: source.type,
    source_url: source.source_url ?? null,
    category: 'teacher_upload',
    subcategory: null,
    cefr_level: null,
    content: source.text,
    content_chunk_count: 0,
    metadata: {
      teacher_id: teacherId,
      cluster_id: clusterId,
      source_type: source.type,
      ...source.metadata,
    },
    uploaded_by: teacherId,
    is_active: true,
  };

  const { data: doc, error: docError } = await supabase
    .from('knowledge_base_documents')
    .insert(docInsert)
    .select()
    .single();

  if (docError || !doc) {
    throw new Error(`Failed to create KB document: ${docError?.message ?? 'unknown'}`);
  }

  const docId = (doc as Record<string, unknown>).id as string;

  // 2. Chunk the text
  const chunks = chunkText(source.text, MAX_CHUNK_CHARS, CHUNK_OVERLAP);

  // 3. Generate embeddings for all chunks (batch call to OpenAI)
  if (chunks.length === 0) return;

  const embedResponse = await fetch(OPENAI_EMBEDDINGS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: EMBEDDING_MODEL,
      input: chunks.map((c) => c.slice(0, 8000)),
    }),
  });

  if (!embedResponse.ok) {
    const errText = await embedResponse.text();
    throw new Error(`OpenAI embeddings error: ${embedResponse.status} ${errText}`);
  }

  const embedJson = (await embedResponse.json()) as {
    data: Array<{ embedding: number[] }>;
  };

  if (!embedJson.data || embedJson.data.length !== chunks.length) {
    throw new Error('Embedding count mismatch');
  }

  // 4. Insert embeddings into knowledge_base_embeddings
  const embedRows = chunks.map((chunkText, i) => ({
    document_id: docId,
    chunk_index: i,
    chunk_text: chunkText,
    embedding: JSON.stringify(embedJson.data[i].embedding),
    metadata: {
      teacher_id: teacherId,
      cluster_id: clusterId,
      source_type: source.type,
      source_title: source.title,
    },
  }));

  const { error: embedError } = await supabase
    .from('knowledge_base_embeddings')
    .insert(embedRows);

  if (embedError) {
    throw new Error(`Failed to insert embeddings: ${embedError.message}`);
  }

  // 5. Update chunk count on the document
  await supabase
    .from('knowledge_base_documents')
    .update({ content_chunk_count: chunks.length })
    .eq('id', docId);
}

// ============================================================
// Chunk text — split into overlapping chunks for embedding
// ============================================================

export function chunkText(text: string, maxChars: number, overlap: number): string[] {
  if (text.length <= maxChars) return [text];

  const chunks: string[] = [];
  let start = 0;
  while (start < text.length) {
    let end = start + maxChars;
    // Try to break at a sentence or paragraph boundary
    if (end < text.length) {
      const lastPeriod = text.lastIndexOf('.', end);
      const lastNewline = text.lastIndexOf('\n', end);
      const breakPoint = Math.max(lastPeriod, lastNewline);
      if (breakPoint > start + maxChars * 0.5) {
        end = breakPoint + 1;
      }
    }
    chunks.push(text.slice(start, Math.min(end, text.length)).trim());
    start = end - overlap;
    if (start < 0) start = 0;
  }
  return chunks.filter((c) => c.length > 50); // skip tiny chunks
}

// ============================================================
// Search knowledge — RAG search across all teacher's sources
// ============================================================

export interface KnowledgeSearchResult {
  chunk_text: string;
  source_title: string;
  source_type: string;
  cluster_id?: string;
  similarity: number;
}

/**
 * Search across all ingested sources for a teacher. Uses RAG (vector search)
 * to find the most relevant chunks for the given query.
 *
 * This replaces the "dump all sources into the prompt" approach — instead,
 * the AI gets only the relevant snippets, allowing unlimited sources.
 */
export async function searchKnowledge(
  env: Env,
  query: string,
  teacherId: string,
  options: { matchCount?: number; clusterId?: string } = {}
): Promise<KnowledgeSearchResult[]> {
  const matchCount = options.matchCount ?? 8;
  const embedding = await generateQueryEmbedding(env, query);
  const supabase = getSupabase(env);

  // Search with metadata filter for this teacher's sources
  const filter: Record<string, unknown> = { teacher_id: teacherId };
  if (options.clusterId) {
    filter.cluster_id = options.clusterId;
  }

  const { data, error } = await supabase.rpc('match_documents', {
    query_embedding: embedding,
    match_count: matchCount,
    filter,
  });

  if (error) {
    // Fallback: try without filter (if match_documents doesn't support metadata filtering)
    console.error('RAG search with filter failed, trying without:', error.message);
    const { data: fallbackData, error: fallbackError } = await supabase.rpc('match_documents', {
      query_embedding: embedding,
      match_count: matchCount,
      filter: {},
    });
    if (fallbackError || !fallbackData) return [];
    // Filter client-side by teacher_id
    return ((fallbackData as Array<Record<string, unknown>>)
      .filter((row) => {
        const meta = row.metadata as Record<string, unknown> | undefined;
        return meta?.teacher_id === teacherId;
      })
      .map((row) => ({
        chunk_text: row.chunk_text as string,
        source_title: (row.metadata as Record<string, unknown>)?.source_title as string ?? 'Unknown',
        source_type: (row.metadata as Record<string, unknown>)?.source_type as string ?? 'unknown',
        cluster_id: (row.metadata as Record<string, unknown>)?.cluster_id as string | undefined,
        similarity: row.similarity as number,
      })));
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map((row) => ({
    chunk_text: row.chunk_text as string,
    source_title: (row.metadata as Record<string, unknown>)?.source_title as string ?? 'Unknown',
    source_type: (row.metadata as Record<string, unknown>)?.source_type as string ?? 'unknown',
    cluster_id: (row.metadata as Record<string, unknown>)?.cluster_id as string | undefined,
    similarity: row.similarity as number,
  }));
}

// ============================================================
// Assemble knowledge context from RAG search results
// ============================================================

export function assembleKnowledgeContext(results: KnowledgeSearchResult[]): string {
  if (results.length === 0) return '';
  return results.map((r, i) => {
    return `[Source ${i + 1}: ${r.source_title} (${r.source_type}, ${Math.round(r.similarity * 100)}% match)]\n${r.chunk_text}`;
  }).join('\n\n---\n\n');
}