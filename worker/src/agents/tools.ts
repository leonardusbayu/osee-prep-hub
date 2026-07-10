/**
 * Built-in agent tools — Task 1 (Wave 1).
 *
 * Each tool handler has the signature (args, ctx, env) => Promise<unknown>.
 * Tools are registered into a ToolBus by the route handler (see routes/agents.ts).
 *
 * Tools:
 * - rag_search(query, topK=5): vector search over knowledge base
 * - fetch_user_profile(userId): unified_profiles row
 * - fetch_syllabus(syllabusId): syllabus + items
 * - fetch_student_progress(studentId): student_progress_unified row
 */

import type { AgentContext, ToolHandler } from './runtime';
import { searchDocuments } from '../services/rag-search';
import { getSupabase } from '../services/supabase';

/** rag_search(query: string, topK?: number) → RagSearchResult[] */
export const ragSearchTool: ToolHandler = async (args, _ctx, env) => {
  const query = String(args.query ?? '').trim();
  const topK = Math.min(Math.max(Number(args.topK ?? 5), 1), 20);
  if (!query) throw new Error('query required');
  return searchDocuments(env, query, { matchCount: topK });
};

/** fetch_user_profile(userId: string) → unified_profiles row */
export const fetchUserProfileTool: ToolHandler = async (args, _ctx, env) => {
  const userId = String(args.userId ?? '').trim();
  if (!userId) throw new Error('userId required');
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('unified_profiles')
    .select('id, email, display_name, role, target_exam, target_score, current_level')
    .eq('id', userId)
    .single();
  if (error) throw new Error(`fetch_user_profile failed: ${error.message}`);
  return data;
};

/** fetch_syllabus(syllabusId: string) → {syllabus, items} */
export const fetchSyllabusTool: ToolHandler = async (args, _ctx, env) => {
  const syllabusId = String(args.syllabusId ?? '').trim();
  if (!syllabusId) throw new Error('syllabusId required');
  const supabase = getSupabase(env);
  const { data: syllabus, error: sErr } = await supabase
    .from('syllabi')
    .select('*')
    .eq('id', syllabusId)
    .single();
  if (sErr) throw new Error(`fetch_syllabus failed: ${sErr.message}`);
  const { data: items, error: iErr } = await supabase
    .from('syllabus_items')
    .select('id, sort_order, title, source_type, source_material_id, source_platform_url')
    .eq('syllabus_id', syllabusId)
    .order('sort_order', { ascending: true });
  if (iErr) throw new Error(`fetch_syllabus items failed: ${iErr.message}`);
  return { syllabus, items: items ?? [] };
};

/** fetch_student_progress(studentId: string) → student_progress_unified row */
export const fetchStudentProgressTool: ToolHandler = async (args, _ctx, env) => {
  const studentId = String(args.studentId ?? '').trim();
  if (!studentId) throw new Error('studentId required');
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', studentId)
    .single();
  if (error) throw new Error(`fetch_student_progress failed: ${error.message}`);
  return data;
};

/** Register all built-in tools onto a ToolBus. */
export function registerBuiltinTools(
  bus: import('./runtime').ToolBus,
  _ctx: AgentContext
): void {
  bus.register('rag_search', ragSearchTool);
  bus.register('fetch_user_profile', fetchUserProfileTool);
  bus.register('fetch_syllabus', fetchSyllabusTool);
  bus.register('fetch_student_progress', fetchStudentProgressTool);
}