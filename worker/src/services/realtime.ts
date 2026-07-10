/**
 * Realtime service — Task 2 (Wave 1).
 *
 * Collaborator authorization + invite/list endpoints for syllabus real-time editing.
 *
 * Realtime transport itself is handled by Supabase Realtime (broadcast + presence +
 * postgres_changes on the `syllabus_items` table). The worker just authorizes
 * collaborators and exposes presence via the `syllabus_collaborators` table.
 *
 * The Flutter client (flutter/lib/core/realtime_client.dart) connects directly
 * to Supabase Realtime via y-supabase — the worker is NOT a relay.
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface Collaborator {
  user_id: string;
  syllabus_id: string;
  role: 'owner' | 'editor' | 'viewer';
  joined_at: string;
  display_name?: string;
  avatar_url?: string | null;
}

/** Check if a user can access a syllabus (as owner or collaborator). */
export async function canAccessSyllabus(
  env: Env,
  userId: string,
  syllabusId: string
): Promise<{ allowed: boolean; role?: 'owner' | 'editor' | 'viewer' }> {
  const supabase = getSupabase(env);

  // Owner?
  const { data: syllabus } = await supabase
    .from('syllabi')
    .select('teacher_id')
    .eq('id', syllabusId)
    .single();
  if (syllabus && syllabus.teacher_id === userId) {
    return { allowed: true, role: 'owner' };
  }

  // Collaborator?
  const { data: collab } = await supabase
    .from('syllabus_collaborators')
    .select('role')
    .eq('syllabus_id', syllabusId)
    .eq('user_id', userId)
    .single();
  if (collab) {
    return { allowed: true, role: collab.role as 'owner' | 'editor' | 'viewer' };
  }

  return { allowed: false };
}

/** Invite a collaborator by email. Returns the new collaborator row or throws. */
export async function inviteCollaborator(
  env: Env,
  syllabusId: string,
  inviterId: string,
  inviteeEmail: string,
  role: 'editor' | 'viewer' = 'editor'
): Promise<Collaborator> {
  const supabase = getSupabase(env);

  // Verify inviter is owner.
  const { data: syllabus } = await supabase
    .from('syllabi')
    .select('teacher_id')
    .eq('id', syllabusId)
    .single();
  if (!syllabus || syllabus.teacher_id !== inviterId) {
    throw new Error('Only the syllabus owner can invite collaborators');
  }

  // Look up invitee by email.
  const { data: invitee, error: inviteeErr } = await supabase
    .from('unified_profiles')
    .select('id, display_name, avatar_url')
    .eq('email', inviteeEmail)
    .single();
  if (inviteeErr || !invitee) {
    throw new Error(`User not found: ${inviteeEmail}`);
  }

  // Insert collaborator (upsert to handle re-invite).
  const { data, error } = await supabase
    .from('syllabus_collaborators')
    .upsert(
      {
        syllabus_id: syllabusId,
        user_id: invitee.id,
        role,
        joined_at: new Date().toISOString(),
      },
      { onConflict: 'syllabus_id,user_id' }
    )
    .select()
    .single();
  if (error) throw new Error(`Invite failed: ${error.message}`);

  return {
    user_id: invitee.id,
    syllabus_id: syllabusId,
    role,
    joined_at: data.joined_at,
    display_name: invitee.display_name,
    avatar_url: invitee.avatar_url,
  };
}

/** List collaborators with profile info for presence display. */
export async function listCollaborators(
  env: Env,
  syllabusId: string
): Promise<Collaborator[]> {
  const supabase = getSupabase(env);

  // Owner first.
  const { data: syllabus } = await supabase
    .from('syllabi')
    .select('teacher_id, unified_profiles!syllabi_teacher_id_fkey(display_name, avatar_url)')
    .eq('id', syllabusId)
    .single();
  const ownerProfile = syllabus?.unified_profiles as unknown as { display_name: string; avatar_url: string | null } | null;

  const owner: Collaborator = {
    user_id: syllabus?.teacher_id ?? '',
    syllabus_id: syllabusId,
    role: 'owner',
    joined_at: new Date(0).toISOString(),
    display_name: ownerProfile?.display_name,
    avatar_url: ownerProfile?.avatar_url,
  };

  // Additional collaborators.
  const { data, error } = await supabase
    .from('syllabus_collaborators')
    .select(`
      user_id,
      syllabus_id,
      role,
      joined_at,
      unified_profiles!syllabus_collaborators_user_id_fkey(display_name, avatar_url)
    `)
    .eq('syllabus_id', syllabusId);
  if (error) throw new Error(`List collaborators failed: ${error.message}`);

  const others: Collaborator[] = (data ?? []).map((row: any) => ({
    user_id: row.user_id,
    syllabus_id: row.syllabus_id,
    role: row.role,
    joined_at: row.joined_at,
    display_name: row.unified_profiles?.display_name,
    avatar_url: row.unified_profiles?.avatar_url,
  }));

  return [owner, ...others];
}