import type { Env } from '../types';
import { getSupabase } from './supabase';
import { sendTeacherInvitation, EmailError } from './email';

/**
 * Teacher invitations service — partner → teacher recruitment.
 *
 * A partner (institution) invites a teacher by email. The invitation is
 * persisted with an opaque single-use token and a 7-day expiry. The teacher
 * registers using the token-bearing invite URL to auto-link to the
 * institution. Email delivery is via the Resend service.
 *
 * Idempotency: a pending (un-expired, un-accepted) invitation for the same
 * partner + teacher_email is reused instead of creating a duplicate.
 */

const INVITATION_TTL_DAYS = 7;

export interface TeacherInvitation {
  id: string;
  partner_id: string;
  teacher_email: string;
  institution_name: string;
  token: string;
  accepted_at: string | null;
  accepted_by: string | null;
  expires_at: string;
  created_at: string;
}

export class InvitationError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = 'InvitationError';
    this.code = code;
  }
}

/** Generate a cryptographically random opaque token using Web Crypto. */
function generateToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  // hex-encode (64 chars)
  return Array.from(bytes, (b) => b.toString(16).padStart(2, '0')).join('');
}

/**
 * Create an invitation (or reuse a pending one) and send the email.
 * Returns the invitation record + the invite URL.
 * Does NOT throw on email send failure — the invitation is still persisted,
 * and the email error is surfaced via the `email_error` field.
 */
export async function createInvitation(
  env: Env,
  partnerId: string,
  teacherEmail: string
): Promise<{
  invitation: TeacherInvitation;
  inviteUrl: string;
  email_sent: boolean;
  email_error?: string;
}> {
  const supabase = getSupabase(env);
  const email = teacherEmail.toLowerCase().trim();

  if (!email || !email.includes('@')) {
    throw new InvitationError('INVALID_EMAIL', 'A valid teacher email is required');
  }

  // Resolve the partner's institution name (also confirms the partner exists)
  const { data: partner } = await supabase
    .from('unified_profiles')
    .select('display_name, teacher_institution')
    .eq('id', partnerId)
    .maybeSingle();

  const institution = (partner as Record<string, unknown> | null)?.teacher_institution as
    | string
    | null;
  const partnerName = (partner as Record<string, unknown> | null)?.display_name as
    | string
    | null;

  if (!institution) {
    throw new InvitationError('NO_INSTITUTION', 'Partner profile has no institution name');
  }

  // Idempotency: reuse an existing pending (not accepted, not expired) invitation
  const { data: existing } = await supabase
    .from('teacher_invitations')
    .select('*')
    .eq('partner_id', partnerId)
    .eq('teacher_email', email)
    .is('accepted_at', null)
    .gt('expires_at', new Date().toISOString())
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  let invitation = existing as TeacherInvitation | null;

  if (!invitation) {
    const token = generateToken();
    const expires_at = new Date(Date.now() + INVITATION_TTL_DAYS * 24 * 60 * 60 * 1000).toISOString();
    const { data: inserted, error } = await supabase
      .from('teacher_invitations')
      .insert({
        partner_id: partnerId,
        teacher_email: email,
        institution_name: institution,
        token,
        expires_at,
      })
      .select('*')
      .single();

    if (error || !inserted) {
      throw new InvitationError(
        'CREATE_FAILED',
        `Failed to create invitation: ${error?.message ?? 'unknown error'}`
      );
    }
    invitation = inserted as TeacherInvitation;
  }

  const inviteUrl = buildInviteUrl(env, invitation.token);

  // Send email — do not fail the whole operation if email delivery fails,
  // but surface the error so the caller can report it.
  let email_sent = false;
  let email_error: string | undefined;
  try {
    await sendTeacherInvitation(env, {
      to: email,
      institutionName: institution,
      inviteUrl,
      partnerName: partnerName ?? undefined,
    });
    email_sent = true;
  } catch (err) {
    email_error =
      err instanceof EmailError ? `${err.code}: ${err.message}` : (err as Error).message;
  }

  return { invitation, inviteUrl, email_sent, email_error };
}

/** Validate a token. Returns the invitation if valid, pending, and un-expired. */
export async function validateInvitation(
  env: Env,
  token: string
): Promise<TeacherInvitation> {
  if (!token || token.trim().length === 0) {
    throw new InvitationError('INVALID_TOKEN', 'An invitation token is required');
  }

  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('teacher_invitations')
    .select('*')
    .eq('token', token.trim())
    .maybeSingle();

  if (error || !data) {
    throw new InvitationError('INVITATION_NOT_FOUND', 'Invitation not found');
  }

  const invitation = data as TeacherInvitation;
  if (invitation.accepted_at !== null) {
    throw new InvitationError('INVITATION_ALREADY_USED', 'This invitation has already been used');
  }
  if (new Date(invitation.expires_at).getTime() < Date.now()) {
    throw new InvitationError('INVITATION_EXPIRED', 'This invitation has expired');
  }

  return invitation;
}

/**
 * Accept an invitation — marks it consumed and returns the institution name
 * to link to the registering teacher's profile.
 */
export async function acceptInvitation(
  env: Env,
  token: string,
  newUserId: string
): Promise<{ institution_name: string }> {
  const invitation = await validateInvitation(env, token);

  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('teacher_invitations')
    .update({
      accepted_at: new Date().toISOString(),
      accepted_by: newUserId,
    })
    .eq('id', invitation.id)
    .is('accepted_at', null); // race-safe: only update if still pending

  if (error) {
    throw new InvitationError('ACCEPT_FAILED', `Failed to accept invitation: ${error.message}`);
  }

  return { institution_name: invitation.institution_name };
}

function buildInviteUrl(env: Env, token: string): string {
  const base = env.WEBAPP_URL ?? 'https://prep.osee.co.id';
  return `${base}/register?invite=${token}`;
}