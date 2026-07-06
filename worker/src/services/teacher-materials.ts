import type { Env } from '../types';
import { getSupabase } from './supabase';
import { ingestSource } from './content-ingestion';
import type { IngestedSource, SourceType } from './content-ingestion';
import { embedSource, chunkText } from './knowledge-cluster';

/**
 * Teacher materials service — persistent material library.
 *
 * Manages the teacher_materials table. Materials are reusable text assets
 * (URLs, YouTube transcripts, PDFs, pasted text) that a teacher can attach
 * to lesson boards, syllabi, or ingest into the RAG knowledge base.
 *
 * Relationship to other services:
 *  - addMaterialFromSource reuses ingestSource() from content-ingestion
 *    to extract text, then persists the result here.
 *  - ingestMaterialToRag reuses embedSource() from knowledge-cluster to
 *    chunk + embed the material's extracted_text into knowledge_base_documents
 *    + knowledge_base_embeddings.
 */

const MAX_CHUNK_CHARS = 2000;
const CHUNK_OVERLAP = 200;

export interface TeacherMaterial {
  id: string;
  teacher_id: string;
  name: string;
  type: string;
  source_url: string | null;
  storage_key: string | null;
  storage_url: string | null;
  extracted_text: string | null;
  metadata: Record<string, unknown> | null;
  tags: string[] | null;
  size_bytes: number | null;
  cluster_id: string | null;
  created_at: string;
  updated_at: string;
}

/** List a teacher's materials, newest-updated first. Optional filter by type. */
export async function listMaterials(
  env: Env,
  teacherId: string,
  opts?: { type?: string }
): Promise<Array<{
  id: string;
  name: string;
  type: string;
  source_url: string | null;
  storage_url: string | null;
  tags: string[] | null;
  size_bytes: number | null;
  created_at: string;
  updated_at: string;
}>> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('teacher_materials')
    .select('id, name, type, source_url, storage_url, tags, size_bytes, created_at, updated_at')
    .eq('teacher_id', teacherId);
  if (opts?.type) {
    query = query.eq('type', opts.type);
  }
  const { data, error } = await query.order('updated_at', { ascending: false });
  if (error) throw new Error(`List materials failed: ${error.message}`);
  return (data ?? []) as Array<{
    id: string;
    name: string;
    type: string;
    source_url: string | null;
    storage_url: string | null;
    tags: string[] | null;
    size_bytes: number | null;
    created_at: string;
    updated_at: string;
  }>;
}

/** Get a single material (including extracted_text). Verifies ownership. */
export async function getMaterial(
  env: Env,
  teacherId: string,
  materialId: string
): Promise<TeacherMaterial | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('teacher_materials')
    .select('*')
    .eq('id', materialId)
    .eq('teacher_id', teacherId)
    .maybeSingle();
  return (data as TeacherMaterial) ?? null;
}

/** Insert a new material row. */
export async function addMaterial(
  env: Env,
  teacherId: string,
  input: {
    name: string;
    type: string;
    source_url?: string;
    storage_key?: string;
    storage_url?: string;
    extracted_text?: string;
    metadata?: Record<string, unknown>;
    tags?: string[];
    size_bytes?: number;
    cluster_id?: string;
  }
): Promise<TeacherMaterial> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('teacher_materials')
    .insert({
      teacher_id: teacherId,
      name: input.name,
      type: input.type,
      source_url: input.source_url ?? null,
      storage_key: input.storage_key ?? null,
      storage_url: input.storage_url ?? null,
      extracted_text: input.extracted_text ?? null,
      metadata: input.metadata ?? {},
      tags: input.tags ?? [],
      size_bytes: input.size_bytes ?? null,
      cluster_id: input.cluster_id ?? null,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Add material failed: ${error?.message}`);
  return data as TeacherMaterial;
}

/**
 * Convenience: ingest a source (URL, YouTube, PDF, text) and persist it
 * as a teacher material with the extracted text.
 *
 * For 'url'/'youtube' types the source URL is used; for 'pdf'/'text'
 * types the raw content/filename is used.
 */
export async function addMaterialFromSource(
  env: Env,
  teacherId: string,
  input: { name: string; type: SourceType; url?: string; content?: string; filename?: string }
): Promise<TeacherMaterial> {
  const ingested: IngestedSource = await ingestSource(env, {
    type: input.type,
    url: input.url,
    content: input.content,
    filename: input.filename,
  });

  return addMaterial(env, teacherId, {
    name: input.name,
    type: input.type,
    source_url: ingested.source_url ?? input.url,
    extracted_text: ingested.text,
    metadata: {
      ingested_title: ingested.title,
      ingested_type: ingested.type,
      ...ingested.metadata,
    },
    size_bytes: ingested.text ? ingested.text.length : undefined,
  });
}

/** Update a material's metadata. Verifies ownership. */
export async function updateMaterial(
  env: Env,
  teacherId: string,
  materialId: string,
  patch: { name?: string; tags?: string[]; metadata?: Record<string, unknown> }
): Promise<TeacherMaterial> {
  const supabase = getSupabase(env);

  const { data: existing } = await supabase
    .from('teacher_materials')
    .select('id, teacher_id')
    .eq('id', materialId)
    .maybeSingle();
  if (!existing) throw new Error('Material not found');
  if ((existing as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Material not owned by teacher');
  }

  const updatePayload: Record<string, unknown> = {};
  if (patch.name !== undefined) updatePayload.name = patch.name;
  if (patch.tags !== undefined) updatePayload.tags = patch.tags;
  if (patch.metadata !== undefined) updatePayload.metadata = patch.metadata;

  if (Object.keys(updatePayload).length === 0) {
    const { data: current } = await supabase
      .from('teacher_materials')
      .select('*')
      .eq('id', materialId)
      .single();
    return current as TeacherMaterial;
  }

  const { data, error } = await supabase
    .from('teacher_materials')
    .update(updatePayload)
    .eq('id', materialId)
    .select()
    .single();
  if (error || !data) throw new Error(`Update material failed: ${error?.message}`);
  return data as TeacherMaterial;
}

/** Delete a material. Verifies ownership. */
export async function deleteMaterial(
  env: Env,
  teacherId: string,
  materialId: string
): Promise<void> {
  const supabase = getSupabase(env);
  const { data: existing } = await supabase
    .from('teacher_materials')
    .select('id, teacher_id')
    .eq('id', materialId)
    .maybeSingle();
  if (!existing) throw new Error('Material not found');
  if ((existing as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Material not owned by teacher');
  }
  const { error } = await supabase.from('teacher_materials').delete().eq('id', materialId);
  if (error) throw new Error(`Delete material failed: ${error.message}`);
}

/**
 * Ingest a material's extracted_text into the RAG knowledge base.
 *
 * Chunks + embeds the text into knowledge_base_documents +
 * knowledge_base_embeddings via embedSource(). Returns the number of
 * chunks embedded and the cluster_id (if the material has one).
 */
export async function ingestMaterialToRag(
  env: Env,
  teacherId: string,
  materialId: string
): Promise<{ embedded_chunks: number; cluster_id?: string }> {
  const material = await getMaterial(env, teacherId, materialId);
  if (!material) throw new Error('Material not found');
  if (!material.extracted_text || material.extracted_text.trim().length === 0) {
    throw new Error('Material has no extracted text to embed');
  }

  const chunks = chunkText(material.extracted_text, MAX_CHUNK_CHARS, CHUNK_OVERLAP);
  const embeddedChunks = Math.max(chunks.length, 0);

  const source: IngestedSource = {
    type: material.type as SourceType,
    title: material.name,
    text: material.extracted_text,
    source_url: material.source_url ?? undefined,
    metadata: { ...(material.metadata ?? {}), material_id: material.id },
  };

  await embedSource(env, source, teacherId, material.cluster_id ?? undefined);

  return {
    embedded_chunks: embeddedChunks,
    cluster_id: material.cluster_id ?? undefined,
  };
}