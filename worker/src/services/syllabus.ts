import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Syllabus service — Task 10.x.
 *
 * CRUD operations for syllabi and syllabus items.
 * Syllabi belong to a teacher; items belong to a syllabus.
 */

export interface Syllabus {
  id: string;
  teacher_id: string;
  classroom_id: string | null;
  name: string;
  description: string | null;
  target_exam: string | null;
  is_template: boolean;
  is_published: boolean;
  created_at: string;
  updated_at: string;
}

export interface SyllabusItem {
  id: string;
  syllabus_id: string;
  sort_order: number;
  source_type: string;
  source_material_id: string | null;
  title: string;
  description: string | null;
  item_type: string;
  section: string | null;
  difficulty: string | null;
  estimated_minutes: number | null;
  unlocked_at: string | null;
  ai_generated_content: Record<string, unknown> | null;
  created_at: string;
}

/** Create a syllabus. */
export async function createSyllabus(
  env: Env,
  teacherId: string,
  input: { name: string; description?: string; target_exam?: string; classroom_id?: string }
): Promise<Syllabus> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('syllabi')
    .insert({
      teacher_id: teacherId,
      classroom_id: input.classroom_id ?? null,
      name: input.name,
      description: input.description ?? null,
      target_exam: input.target_exam ?? null,
      is_template: false,
      is_published: false,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Create syllabus failed: ${error?.message}`);
  return data as Syllabus;
}

/** List teacher's syllabi. */
export async function listSyllabi(env: Env, teacherId: string): Promise<Syllabus[]> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('syllabi')
    .select('*')
    .eq('teacher_id', teacherId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(`List syllabi failed: ${error.message}`);
  return (data ?? []) as Syllabus[];
}

/** Get a syllabus by ID (must belong to teacher). */
export async function getSyllabus(env: Env, teacherId: string, syllabusId: string): Promise<Syllabus | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('syllabi')
    .select('*')
    .eq('id', syllabusId)
    .eq('teacher_id', teacherId)
    .maybeSingle();
  return (data as Syllabus) ?? null;
}

/** List items in a syllabus, ordered by sort_order. */
export async function listSyllabusItems(env: Env, syllabusId: string): Promise<SyllabusItem[]> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('syllabus_items')
    .select('*')
    .eq('syllabus_id', syllabusId)
    .order('sort_order', { ascending: true });
  if (error) throw new Error(`List items failed: ${error.message}`);
  return (data ?? []) as SyllabusItem[];
}

/** Batch save syllabus items (replace all items). Task 10.4. */
export async function batchSaveSyllabusItems(
  env: Env,
  syllabusId: string,
  items: Array<Omit<SyllabusItem, 'id' | 'syllabus_id' | 'created_at'>>
): Promise<void> {
  const supabase = getSupabase(env);
  // Delete existing items
  const { error: delErr } = await supabase
    .from('syllabus_items')
    .delete()
    .eq('syllabus_id', syllabusId);
  if (delErr) throw new Error(`Delete old items failed: ${delErr.message}`);

  // Insert new items
  if (items.length === 0) return;
  const insertPayload = items.map((item, index) => ({
    syllabus_id: syllabusId,
    sort_order: item.sort_order ?? index,
    source_type: item.source_type,
    source_material_id: item.source_material_id,
    title: item.title,
    description: item.description,
    item_type: item.item_type,
    section: item.section,
    difficulty: item.difficulty,
    estimated_minutes: item.estimated_minutes,
    unlocked_at: item.unlocked_at,
    ai_generated_content: item.ai_generated_content,
  }));
  const { error: insErr } = await supabase.from('syllabus_items').insert(insertPayload);
  if (insErr) throw new Error(`Insert items failed: ${insErr.message}`);
}

/** Add a single item to a syllabus. */
export async function addSyllabusItem(
  env: Env,
  syllabusId: string,
  item: Omit<SyllabusItem, 'id' | 'syllabus_id' | 'created_at'>
): Promise<SyllabusItem> {
  const supabase = getSupabase(env);
  // Get next sort_order
  const { data: existing } = await supabase
    .from('syllabus_items')
    .select('sort_order')
    .eq('syllabus_id', syllabusId)
    .order('sort_order', { ascending: false })
    .limit(1)
    .maybeSingle();
  const nextOrder = ((existing as Record<string, unknown>)?.sort_order as number ?? -1) + 1;

  const { data, error } = await supabase
    .from('syllabus_items')
    .insert({
      syllabus_id: syllabusId,
      sort_order: item.sort_order ?? nextOrder,
      source_type: item.source_type,
      source_material_id: item.source_material_id,
      title: item.title,
      description: item.description,
      item_type: item.item_type,
      section: item.section,
      difficulty: item.difficulty,
      estimated_minutes: item.estimated_minutes,
      unlocked_at: item.unlocked_at,
      ai_generated_content: item.ai_generated_content,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Add item failed: ${error?.message}`);
  return data as SyllabusItem;
}

/** Delete a syllabus item (blueprint line 1327). */
export async function deleteSyllabusItem(
  env: Env,
  syllabusId: string,
  itemId: string
): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('syllabus_items')
    .delete()
    .eq('id', itemId)
    .eq('syllabus_id', syllabusId);
  if (error) throw new Error(`Delete item failed: ${error.message}`);
}

/** Delete an entire syllabus (all items + syllabus row). */
export async function deleteSyllabus(
  env: Env,
  teacherId: string,
  syllabusId: string
): Promise<void> {
  const supabase = getSupabase(env);
  // Verify ownership
  const { data: syl } = await supabase
    .from('syllabi')
    .select('id')
    .eq('id', syllabusId)
    .eq('teacher_id', teacherId)
    .maybeSingle();
  if (!syl) throw new Error('Syllabus not found or not owned by teacher');

  // Delete (cascade will remove items)
  const { error } = await supabase.from('syllabi').delete().eq('id', syllabusId);
  if (error) throw new Error(`Delete syllabus failed: ${error.message}`);
}

/** Publish/unpublish a syllabus (toggle is_published). */
export async function togglePublishSyllabus(
  env: Env,
  teacherId: string,
  syllabusId: string,
  published: boolean
): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('syllabi')
    .update({ is_published: published, updated_at: new Date().toISOString() })
    .eq('id', syllabusId)
    .eq('teacher_id', teacherId);
  if (error) throw new Error(`Publish toggle failed: ${error.message}`);
}