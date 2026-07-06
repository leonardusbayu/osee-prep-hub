import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Lesson templates service — starter board layouts.
 *
 * Templates are pre-built canvas_state graphs that a teacher can pick from
 * to bootstrap a new board. Official templates (is_official=true) are curated
 * by OSEE; teachers can also create their own templates from existing boards.
 */

export interface LessonTemplate {
  id: string;
  name: string;
  description: string | null;
  category: string;
  canvas_state: Record<string, unknown>;
  target_exam: string | null;
  cefr_level: string | null;
  kp_tags: unknown;
  is_official: boolean;
  created_by: string | null;
  created_at: string;
  updated_at: string;
}

/** List templates, optionally filtered by category. Official templates first. */
export async function listTemplates(
  env: Env,
  opts?: { category?: string; includeUnofficial?: boolean }
): Promise<Array<{
  id: string;
  name: string;
  description: string | null;
  category: string;
  target_exam: string | null;
  cefr_level: string | null;
  is_official: boolean;
}>> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('lesson_templates')
    .select('id, name, description, category, target_exam, cefr_level, is_official');
  if (opts?.category) {
    query = query.eq('category', opts.category);
  }
  if (!opts?.includeUnofficial) {
    query = query.eq('is_official', true);
  }
  const { data, error } = await query.order('is_official', { ascending: false }).order('name', { ascending: true });
  if (error) throw new Error(`List templates failed: ${error.message}`);
  return (data ?? []) as Array<{
    id: string;
    name: string;
    description: string | null;
    category: string;
    target_exam: string | null;
    cefr_level: string | null;
    is_official: boolean;
  }>;
}

/** Get a single template (including full canvas_state). */
export async function getTemplate(env: Env, templateId: string): Promise<LessonTemplate | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('lesson_templates')
    .select('*')
    .eq('id', templateId)
    .maybeSingle();
  return (data as LessonTemplate) ?? null;
}

/** Create a new template (teacher-created). */
export async function createTemplate(
  env: Env,
  userId: string,
  input: {
    name: string;
    description?: string;
    category: string;
    canvas_state: Record<string, unknown>;
    target_exam?: string;
    cefr_level?: string;
    kp_tags?: unknown;
  }
): Promise<LessonTemplate> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('lesson_templates')
    .insert({
      name: input.name,
      description: input.description ?? null,
      category: input.category,
      canvas_state: input.canvas_state,
      target_exam: input.target_exam ?? null,
      cefr_level: input.cefr_level ?? null,
      kp_tags: input.kp_tags ?? [],
      is_official: false,
      created_by: userId,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Create template failed: ${error?.message}`);
  return data as LessonTemplate;
}