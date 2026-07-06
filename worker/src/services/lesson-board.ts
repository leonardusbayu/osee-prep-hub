import type { Env } from '../types';
import { getSupabase } from './supabase';

/**
 * Lesson board service — interactive lesson canvas management.
 *
 * Manages the lesson_boards, lesson_board_versions, and lesson_shares tables.
 * Boards are persistent canvases (Remalt-style) where teachers assemble
 * lessons from syllabus items, AI-generated content, and ingested sources.
 *
 * Versioning:
 *  - Explicit saves (autosave=false) or labelled saves bump board.version
 *    and snapshot the previous canvas_state into lesson_board_versions.
 *  - Pure autosaves (autosave=true, no label) update only canvas_state +
 *    last_saved_at without bumping the version, so undo history stays clean.
 */

export interface LessonBoard {
  id: string;
  teacher_id: string;
  title: string;
  description: string | null;
  syllabus_id: string | null;
  target_exam: string | null;
  cefr_level: string | null;
  tags: string[] | null;
  kp_tags: unknown;
  canvas_state: Record<string, unknown>;
  status: string;
  thumbnail_url: string | null;
  version: number;
  last_saved_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface LessonBoardVersion {
  id: string;
  board_id: string;
  version: number;
  label: string | null;
  canvas_state: Record<string, unknown>;
  saved_by: string;
  created_at: string;
}

export interface LessonShare {
  id: string;
  board_id: string;
  shared_with_email: string | null;
  shared_with_id: string | null;
  shared_by: string;
  permission: string;
  status: string;
  created_at: string;
}

// ============================================================
// Boards
// ============================================================

/** Create a new lesson board with an empty canvas (`{}`). */
export async function createBoard(
  env: Env,
  teacherId: string,
  input: {
    title: string;
    description?: string;
    syllabus_id?: string;
    target_exam?: string;
    cefr_level?: string;
    tags?: string[];
    kp_tags?: unknown;
  }
): Promise<LessonBoard> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('lesson_boards')
    .insert({
      teacher_id: teacherId,
      title: input.title,
      description: input.description ?? null,
      syllabus_id: input.syllabus_id ?? null,
      target_exam: input.target_exam ?? null,
      cefr_level: input.cefr_level ?? null,
      tags: input.tags ?? [],
      kp_tags: input.kp_tags ?? [],
      canvas_state: {},
      status: 'draft',
      thumbnail_url: null,
      version: 1,
      last_saved_at: null,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Create board failed: ${error?.message}`);
  return data as LessonBoard;
}

/** List a teacher's lesson boards, newest-updated first. */
export async function listBoards(
  env: Env,
  teacherId: string,
  opts?: { includeArchived?: boolean }
): Promise<Array<{
  id: string;
  title: string;
  description: string | null;
  status: string;
  thumbnail_url: string | null;
  tags: string[] | null;
  target_exam: string | null;
  cefr_level: string | null;
  version: number;
  last_saved_at: string | null;
  created_at: string;
  updated_at: string;
}>> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('lesson_boards')
    .select('id, title, description, status, thumbnail_url, tags, target_exam, cefr_level, version, last_saved_at, created_at, updated_at')
    .eq('teacher_id', teacherId);
  if (!opts?.includeArchived) {
    query = query.neq('status', 'archived');
  }
  const { data, error } = await query.order('updated_at', { ascending: false });
  if (error) throw new Error(`List boards failed: ${error.message}`);
  return (data ?? []) as Array<{
    id: string;
    title: string;
    description: string | null;
    status: string;
    thumbnail_url: string | null;
    tags: string[] | null;
    target_exam: string | null;
    cefr_level: string | null;
    version: number;
    last_saved_at: string | null;
    created_at: string;
    updated_at: string;
  }>;
}

/** Get a board by ID. Verifies ownership or shared access via lesson_shares. */
export async function getBoard(
  env: Env,
  teacherId: string,
  boardId: string
): Promise<LessonBoard | null> {
  const supabase = getSupabase(env);
  const { data: board } = await supabase
    .from('lesson_boards')
    .select('*')
    .eq('id', boardId)
    .maybeSingle();
  if (!board) return null;
  const b = board as LessonBoard;

  // Owner — full access
  if (b.teacher_id === teacherId) return b;

  // Otherwise, check for an active share (pending or accepted)
  const email = await resolveUserEmail(env, teacherId);
  if (email) {
    const { data: share } = await supabase
      .from('lesson_shares')
      .select('id')
      .eq('board_id', boardId)
      .eq('shared_with_email', email)
      .in('status', ['pending', 'accepted'])
      .maybeSingle();
    if (share) return b;
  }
  const { data: shareById } = await supabase
    .from('lesson_shares')
    .select('id')
    .eq('board_id', boardId)
    .eq('shared_with_id', teacherId)
    .in('status', ['pending', 'accepted'])
    .maybeSingle();
  if (shareById) return b;

  return null;
}

/** Update board metadata. Does NOT touch canvas_state (use saveBoardState). */
export async function updateBoard(
  env: Env,
  teacherId: string,
  boardId: string,
  patch: {
    title?: string;
    description?: string;
    tags?: string[];
    kp_tags?: unknown;
    target_exam?: string;
    cefr_level?: string;
    status?: string;
  }
): Promise<LessonBoard> {
  const supabase = getSupabase(env);

  const { data: existing } = await supabase
    .from('lesson_boards')
    .select('id, teacher_id')
    .eq('id', boardId)
    .maybeSingle();
  if (!existing) throw new Error('Board not found');
  if ((existing as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Board not owned by teacher');
  }

  const updatePayload: Record<string, unknown> = {};
  if (patch.title !== undefined) updatePayload.title = patch.title;
  if (patch.description !== undefined) updatePayload.description = patch.description;
  if (patch.tags !== undefined) updatePayload.tags = patch.tags;
  if (patch.kp_tags !== undefined) updatePayload.kp_tags = patch.kp_tags;
  if (patch.target_exam !== undefined) updatePayload.target_exam = patch.target_exam;
  if (patch.cefr_level !== undefined) updatePayload.cefr_level = patch.cefr_level;
  if (patch.status !== undefined) updatePayload.status = patch.status;

  if (Object.keys(updatePayload).length === 0) {
    const { data: current } = await supabase
      .from('lesson_boards')
      .select('*')
      .eq('id', boardId)
      .single();
    return current as LessonBoard;
  }

  const { data, error } = await supabase
    .from('lesson_boards')
    .update(updatePayload)
    .eq('id', boardId)
    .select()
    .single();
  if (error || !data) throw new Error(`Update board failed: ${error?.message}`);
  return data as LessonBoard;
}

/**
 * Save the board canvas state.
 *
 * - Explicit save (autosave=false) or any labelled save → bump board.version
 *   and insert a version snapshot of the PREVIOUS canvas_state (undo history).
 * - Silent autosave (autosave=true, no label) → update canvas_state +
 *   last_saved_at only, without bumping the version or inserting a snapshot.
 */
export async function saveBoardState(
  env: Env,
  teacherId: string,
  boardId: string,
  canvasState: Record<string, unknown>,
  opts?: { autosave?: boolean; label?: string }
): Promise<{ id: string; version: number; last_saved_at: string }> {
  const supabase = getSupabase(env);

  const { data: existing } = await supabase
    .from('lesson_boards')
    .select('id, teacher_id, canvas_state, version')
    .eq('id', boardId)
    .maybeSingle();
  if (!existing) throw new Error('Board not found');
  const row = existing as { id: string; teacher_id: string; canvas_state: Record<string, unknown>; version: number };
  if (row.teacher_id !== teacherId) {
    throw new Error('Board not owned by teacher');
  }

  const isVersioned = !opts?.autosave || (opts?.label !== undefined && opts.label.trim().length > 0);
  const now = new Date().toISOString();

  if (isVersioned) {
    const { error: verErr } = await supabase.from('lesson_board_versions').insert({
      board_id: boardId,
      version: row.version,
      label: opts?.label ?? null,
      canvas_state: row.canvas_state,
      saved_by: teacherId,
    });
    if (verErr) throw new Error(`Snapshot version failed: ${verErr.message}`);

    const { data, error } = await supabase
      .from('lesson_boards')
      .update({ canvas_state: canvasState, version: row.version + 1, last_saved_at: now })
      .eq('id', boardId)
      .select('id, version, last_saved_at')
      .single();
    if (error || !data) throw new Error(`Save board failed: ${error?.message}`);
    return data as { id: string; version: number; last_saved_at: string };
  }

  const { data, error } = await supabase
    .from('lesson_boards')
    .update({ canvas_state: canvasState, last_saved_at: now })
    .eq('id', boardId)
    .select('id, version, last_saved_at')
    .single();
  if (error || !data) throw new Error(`Autosave board failed: ${error?.message}`);
  return data as { id: string; version: number; last_saved_at: string };
}

// ============================================================
// Versions (undo history)
// ============================================================

/** List version snapshots for a board (newest first). Verifies ownership. */
export async function listBoardVersions(
  env: Env,
  teacherId: string,
  boardId: string
): Promise<Array<{ id: string; version: number; label: string | null; created_at: string; saved_by: string }>> {
  const supabase = getSupabase(env);
  await assertBoardOwned(env, teacherId, boardId);
  const { data, error } = await supabase
    .from('lesson_board_versions')
    .select('id, version, label, created_at, saved_by')
    .eq('board_id', boardId)
    .order('version', { ascending: false });
  if (error) throw new Error(`List versions failed: ${error.message}`);
  return (data ?? []) as Array<{ id: string; version: number; label: string | null; created_at: string; saved_by: string }>;
}

/** Get a single version snapshot (including canvas_state) for restore. Verifies ownership. */
export async function getBoardVersion(
  env: Env,
  teacherId: string,
  boardId: string,
  versionId: string
): Promise<LessonBoardVersion | null> {
  const supabase = getSupabase(env);
  await assertBoardOwned(env, teacherId, boardId);
  const { data } = await supabase
    .from('lesson_board_versions')
    .select('*')
    .eq('id', versionId)
    .eq('board_id', boardId)
    .maybeSingle();
  return (data as LessonBoardVersion) ?? null;
}

/**
 * Restore a board to a previous version.
 * Snapshots the CURRENT canvas_state first (so the restore itself is undoable),
 * then applies the target version's canvas_state to the board and bumps the version.
 */
export async function restoreBoardVersion(
  env: Env,
  teacherId: string,
  boardId: string,
  versionId: string
): Promise<LessonBoard> {
  const supabase = getSupabase(env);

  const { data: board } = await supabase
    .from('lesson_boards')
    .select('id, teacher_id, canvas_state, version')
    .eq('id', boardId)
    .maybeSingle();
  if (!board) throw new Error('Board not found');
  const b = board as { id: string; teacher_id: string; canvas_state: Record<string, unknown>; version: number };
  if (b.teacher_id !== teacherId) {
    throw new Error('Board not owned by teacher');
  }

  const { data: versionRow } = await supabase
    .from('lesson_board_versions')
    .select('*')
    .eq('id', versionId)
    .eq('board_id', boardId)
    .maybeSingle();
  if (!versionRow) throw new Error('Version not found for this board');
  const target = versionRow as LessonBoardVersion;

  const now = new Date().toISOString();

  const { error: snapErr } = await supabase.from('lesson_board_versions').insert({
    board_id: boardId,
    version: b.version,
    label: `Before restore to v${target.version}`,
    canvas_state: b.canvas_state,
    saved_by: teacherId,
  });
  if (snapErr) throw new Error(`Snapshot before restore failed: ${snapErr.message}`);

  const { data, error } = await supabase
    .from('lesson_boards')
    .update({ canvas_state: target.canvas_state, version: b.version + 1, last_saved_at: now })
    .eq('id', boardId)
    .select('*')
    .single();
  if (error || !data) throw new Error(`Restore board failed: ${error?.message}`);
  return data as LessonBoard;
}

/** Delete a board (cascade deletes its versions). Verifies ownership. */
export async function deleteBoard(
  env: Env,
  teacherId: string,
  boardId: string
): Promise<void> {
  const supabase = getSupabase(env);
  const { data: existing } = await supabase
    .from('lesson_boards')
    .select('id, teacher_id')
    .eq('id', boardId)
    .maybeSingle();
  if (!existing) throw new Error('Board not found');
  if ((existing as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Board not owned by teacher');
  }
  const { error } = await supabase.from('lesson_boards').delete().eq('id', boardId);
  if (error) throw new Error(`Delete board failed: ${error.message}`);
}

// ============================================================
// Sharing
// ============================================================

/** Share a board with another user (by email). Status starts as 'pending'. */
export async function shareBoard(
  env: Env,
  teacherId: string,
  boardId: string,
  input: { shared_with_email: string; permission: string }
): Promise<LessonShare> {
  const supabase = getSupabase(env);
  await assertBoardOwned(env, teacherId, boardId);
  const { data, error } = await supabase
    .from('lesson_shares')
    .insert({
      board_id: boardId,
      shared_with_email: input.shared_with_email.toLowerCase(),
      shared_with_id: null,
      shared_by: teacherId,
      permission: input.permission,
      status: 'pending',
    })
    .select()
    .single();
  if (error || !data) throw new Error(`Share board failed: ${error?.message}`);
  return data as LessonShare;
}

/** List shares for a board. Verifies ownership. */
export async function listBoardShares(
  env: Env,
  teacherId: string,
  boardId: string
): Promise<LessonShare[]> {
  const supabase = getSupabase(env);
  await assertBoardOwned(env, teacherId, boardId);
  const { data, error } = await supabase
    .from('lesson_shares')
    .select('*')
    .eq('board_id', boardId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(`List shares failed: ${error.message}`);
  return (data ?? []) as LessonShare[];
}

/** Revoke a share (sets status='revoked'). Verifies board ownership. */
export async function revokeShare(
  env: Env,
  teacherId: string,
  boardId: string,
  shareId: string
): Promise<void> {
  const supabase = getSupabase(env);
  await assertBoardOwned(env, teacherId, boardId);
  const { error } = await supabase
    .from('lesson_shares')
    .update({ status: 'revoked' })
    .eq('id', shareId)
    .eq('board_id', boardId);
  if (error) throw new Error(`Revoke share failed: ${error.message}`);
}

/** List boards shared with this user (by email or id match), accepted or pending. */
export async function listSharedWithMe(
  env: Env,
  userId: string
): Promise<Array<{ board_id: string; title: string; shared_by_email: string; permission: string; status: string }>> {
  const supabase = getSupabase(env);
  const email = await resolveUserEmail(env, userId);

  let query = supabase
    .from('lesson_shares')
    .select('id, board_id, shared_by, permission, status')
    .in('status', ['pending', 'accepted']);

  if (email) {
    query = query.or(`shared_with_email.eq.${email},shared_with_id.eq.${userId}`);
  } else {
    query = query.eq('shared_with_id', userId);
  }
  const { data: shares, error } = await query.order('created_at', { ascending: false });
  if (error) throw new Error(`List shared with me failed: ${error.message}`);
  const shareRows = (shares ?? []) as Array<{ id: string; board_id: string; shared_by: string; permission: string; status: string }>;
  if (shareRows.length === 0) return [];

  const boardIds = Array.from(new Set(shareRows.map((s) => s.board_id)));
  const { data: boards } = await supabase
    .from('lesson_boards')
    .select('id, title')
    .in('id', boardIds);
  const boardMap = new Map<string, string>();
  for (const b of (boards ?? []) as Array<{ id: string; title: string }>) {
    boardMap.set(b.id, b.title);
  }

  const sharedByIds = Array.from(new Set(shareRows.map((s) => s.shared_by)));
  const { data: sharers } = await supabase
    .from('unified_profiles')
    .select('id, email')
    .in('id', sharedByIds);
  const sharerMap = new Map<string, string>();
  for (const u of (sharers ?? []) as Array<{ id: string; email: string }>) {
    sharerMap.set(u.id, u.email);
  }

  return shareRows.map((s) => ({
    board_id: s.board_id,
    title: boardMap.get(s.board_id) ?? 'Untitled board',
    shared_by_email: sharerMap.get(s.shared_by) ?? '',
    permission: s.permission,
    status: s.status,
  }));
}

// ============================================================
// Helpers
// ============================================================

/** Resolve a user's email from unified_profiles. Returns null if not found. */
async function resolveUserEmail(env: Env, userId: string): Promise<string | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('unified_profiles')
    .select('email')
    .eq('id', userId)
    .maybeSingle();
  return ((data as Record<string, unknown> | null)?.email as string) ?? null;
}

/** Throw if the board does not exist or is not owned by teacherId. */
async function assertBoardOwned(env: Env, teacherId: string, boardId: string): Promise<void> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('lesson_boards')
    .select('id, teacher_id')
    .eq('id', boardId)
    .maybeSingle();
  if (!data) throw new Error('Board not found');
  if ((data as Record<string, unknown>).teacher_id !== teacherId) {
    throw new Error('Board not owned by teacher');
  }
}