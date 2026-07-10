/**
 * Studio service — T9 (Wave 2).
 *
 * Real-time collaborative syllabus builder. The full implementation
 * uses Yjs + Supabase Realtime for low-latency CRDT sync (handled on the
 * Flutter client). The worker provides:
 * - Snapshot persistence: every 30s, persist Yjs doc state to syllabus_collaborators
 *   + a new syllabus_snapshots table for catch-up on rejoin.
 * - Share links: read-only link generates a public, anonymous-friendly view.
 *
 * T9 skeleton: snapshot table + endpoint stubs.
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface StudioSnapshot {
  id: string;
  syllabus_id: string;
  state_json: Record<string, unknown>;
  created_at: string;
  created_by: string;
}

/** Persist a Yjs state snapshot for a syllabus. */
export async function saveSnapshot(
  env: Env,
  syllabusId: string,
  userId: string,
  state: Record<string, unknown>
): Promise<StudioSnapshot> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('syllabus_snapshots')
    .insert({
      syllabus_id: syllabusId,
      state_json: state,
      created_by: userId,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`saveSnapshot failed: ${error?.message ?? 'no row'}`);
  return data as StudioSnapshot;
}

/** Get the latest snapshot for a syllabus. */
export async function getLatestSnapshot(
  env: Env,
  syllabusId: string
): Promise<StudioSnapshot | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('syllabus_snapshots')
    .select('*')
    .eq('syllabus_id', syllabusId)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();
  return (data as StudioSnapshot) ?? null;
}

/** Generate a read-only share token for a syllabus. */
export function generateShareToken(syllabusId: string): string {
  // 32-char URL-safe token: {syllabusId_short}-{timestamp_hex}
  const timestamp = Date.now().toString(36);
  const idShort = syllabusId.replace(/-/g, '').slice(0, 8);
  return `${idShort}-${timestamp}-readonly`;
}