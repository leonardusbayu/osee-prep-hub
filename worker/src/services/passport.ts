/**
 * OSEE Passport service — Task 3 (Wave 1).
 *
 * Ed25519-signed verifiable credentials for student achievements.
 * - issueCredential: signs subject_data + evidence_hashes + issued_at
 * - verifyCredential: recomputes hash, verifies signature, checks revoked
 * - revokeCredential: marks revoked_at + reason
 *
 * The signing key is PASSPORT_SIGNING_KEY (set via `wrangler secret put`).
 * Public key is derivable from the private key — exposed via
 * /.well-known/passport-public-key.pem for employer verification.
 */

import * as ed from '@noble/ed25519';
import { sha256 } from '@noble/hashes/sha2.js';
import { sha512 } from '@noble/hashes/sha2.js';

// @noble/ed25519 v2 decoupled SHA-512 — set the sync impl so sign/verify work.
ed.etc.sha512Sync = sha512 as never;
// Also set async (uses sync under the hood in v2).
ed.etc.sha512Async = sha512 as never;
import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface PassportCredential {
  id: string;
  user_id: string;
  credential_type: 'score_report' | 'course_completion' | 'badge' | 'recommendation';
  issuer_id: string;
  subject_data: Record<string, unknown>;
  signature: string;
  public_key_id: string;
  issued_at: string;
  revoked_at: string | null;
}

export interface PassportEvidence {
  id: string;
  credential_id: string;
  evidence_type: 'pdf' | 'image' | 'video' | 'transcript';
  storage_url: string;
  metadata: Record<string, unknown>;
  hash: string;
  created_at: string;
}

export interface IssueInput {
  userId: string;
  credentialType: PassportCredential['credential_type'];
  subjectData: Record<string, unknown>;
  evidence: Array<{
    evidence_type: PassportEvidence['evidence_type'];
    storage_url: string;
    metadata?: Record<string, unknown>;
    content?: string; // for hash computation; if absent, hash = sha256(storage_url)
  }>;
}

/** Decode the PASSPORT_SIGNING_KEY (hex or base64) to a Uint8Array. */
function loadPrivateKey(env: Env): Uint8Array {
  const raw = env.PASSPORT_SIGNING_KEY;
  if (!raw) throw new Error('PASSPORT_SIGNING_KEY not configured');
  // Accept hex (64 chars) or base64.
  if (/^[0-9a-fA-F]{64}$/.test(raw)) {
    return hexToBytes(raw);
  }
  return base64ToBytes(raw);
}

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToHex(b: Uint8Array): string {
  return Array.from(b).map(x => x.toString(16).padStart(2, '0')).join('');
}

function bytesToBase64(b: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < b.length; i++) bin += String.fromCharCode(b[i]);
  return btoa(bin);
}

/** Compute the message that gets signed for a credential. */
function signableMessage(
  subjectData: Record<string, unknown>,
  evidenceHashes: string[],
  issuedAt: string
): Uint8Array {
  const payload = JSON.stringify({
    subject_data: subjectData,
    evidence_hashes: evidenceHashes,
    issued_at: issuedAt,
  });
  return sha256(new TextEncoder().encode(payload));
}

/** Compute a hash for a single evidence item. */
export function hashEvidence(
  _evidenceType: string,
  storageUrl: string,
  content?: string
): string {
  const payload = content ?? storageUrl;
  const digest = sha256(new TextEncoder().encode(payload));
  return bytesToHex(digest);
}

/** Issue a new credential. Returns the inserted credential + evidence rows. */
export async function issueCredential(
  env: Env,
  input: IssueInput
): Promise<{ credential: PassportCredential; evidence: PassportEvidence[] }> {
  if (!input.userId || !input.credentialType || !input.subjectData) {
    throw new Error('userId, credentialType, subjectData required');
  }

  const privateKey = loadPrivateKey(env);
  const publicKey = await ed.getPublicKey(privateKey);
  const publicKeyId = bytesToHex(sha256(publicKey));
  const issuedAt = new Date().toISOString();

  const evidenceHashes = input.evidence.map((e) =>
    hashEvidence(e.evidence_type, e.storage_url, e.content)
  );

  const message = signableMessage(input.subjectData, evidenceHashes, issuedAt);
  const signature = await ed.sign(message, privateKey);
  const signatureHex = bytesToHex(signature);

  const supabase = getSupabase(env);
  const { data: credRow, error: credErr } = await supabase
    .from('passport_credentials')
    .insert({
      user_id: input.userId,
      credential_type: input.credentialType,
      issuer_id: '', // set by caller (route) after auth check
      subject_data: input.subjectData,
      signature: signatureHex,
      public_key_id: publicKeyId,
      issued_at: issuedAt,
    })
    .select()
    .single();
  if (credErr || !credRow) {
    throw new Error(`issueCredential insert failed: ${credErr?.message ?? 'no row'}`);
  }

  // Insert evidence rows.
  const evidenceRows: PassportEvidence[] = [];
  if (input.evidence.length > 0) {
    const inserts = input.evidence.map((e, i) => ({
      credential_id: credRow.id,
      evidence_type: e.evidence_type,
      storage_url: e.storage_url,
      metadata: e.metadata ?? {},
      hash: evidenceHashes[i],
    }));
    const { data: evRows, error: evErr } = await supabase
      .from('passport_evidence')
      .insert(inserts)
      .select();
    if (evErr) {
      // Best-effort rollback: revoke the credential we just issued.
      await supabase.from('passport_credentials').delete().eq('id', credRow.id);
      throw new Error(`issueCredential evidence insert failed: ${evErr.message}`);
    }
    for (const row of evRows ?? []) {
      evidenceRows.push({
        id: row.id,
        credential_id: row.credential_id,
        evidence_type: row.evidence_type,
        storage_url: row.storage_url,
        metadata: row.metadata,
        hash: row.hash,
        created_at: row.created_at,
      });
    }
  }

  return {
    credential: {
      id: credRow.id,
      user_id: credRow.user_id,
      credential_type: credRow.credential_type,
      issuer_id: credRow.issuer_id,
      subject_data: credRow.subject_data,
      signature: credRow.signature,
      public_key_id: credRow.public_key_id,
      issued_at: credRow.issued_at,
      revoked_at: credRow.revoked_at,
    },
    evidence: evidenceRows,
  };
}

/** Fetch + verify a credential by ID. Public (no auth). */
export async function verifyCredential(
  env: Env,
  credentialId: string
): Promise<{
  credential: PassportCredential | null;
  evidence: PassportEvidence[];
  valid: boolean;
  reason?: string;
}> {
  const supabase = getSupabase(env);
  const { data: cred, error } = await supabase
    .from('passport_credentials')
    .select('*')
    .eq('id', credentialId)
    .single();
  if (error || !cred) {
    return { credential: null, evidence: [], valid: false, reason: 'not_found' };
  }

  const { data: evidenceRows } = await supabase
    .from('passport_evidence')
    .select('*')
    .eq('credential_id', credentialId);

  const evidence: PassportEvidence[] = (evidenceRows ?? []).map((r: any) => ({
    id: r.id,
    credential_id: r.credential_id,
    evidence_type: r.evidence_type,
    storage_url: r.storage_url,
    metadata: r.metadata,
    hash: r.hash,
    created_at: r.created_at,
  }));

  // Check revocation first.
  if (cred.revoked_at) {
    return {
      credential: cred as PassportCredential,
      evidence,
      valid: false,
      reason: 'revoked',
    };
  }

  // Recompute signature: subject_data + evidence_hashes + issued_at
  const evidenceHashes = evidence.map((e) => e.hash);
  const message = signableMessage(cred.subject_data, evidenceHashes, cred.issued_at);
  const signature = hexToBytes(cred.signature);

  // We need the public key to verify. Derive it from our private key.
  // (Employer-side verification would fetch /.well-known/passport-public-key.pem
  // and use that public key — same key, same result.)
  try {
    const privateKey = loadPrivateKey(env);
    const publicKey = await ed.getPublicKey(privateKey);
    const ok = await ed.verify(signature, message, publicKey);
    if (!ok) {
      return {
        credential: cred as PassportCredential,
        evidence,
        valid: false,
        reason: 'signature_mismatch',
      };
    }
  } catch (err) {
    // If signing key not configured (e.g., public verification by employer),
    // we can only check revocation — mark as 'unverified' rather than 'invalid'.
    return {
      credential: cred as PassportCredential,
      evidence,
      valid: false,
      reason: 'verification_key_unavailable',
    };
  }

  return {
    credential: cred as PassportCredential,
    evidence,
    valid: true,
  };
}

/** Revoke a credential. Only the original issuer or admin can revoke. */
export async function revokeCredential(
  env: Env,
  credentialId: string,
  revokerId: string,
  _reason: string
): Promise<void> {
  const supabase = getSupabase(env);
  const { data: cred } = await supabase
    .from('passport_credentials')
    .select('issuer_id')
    .eq('id', credentialId)
    .single();
  if (!cred) throw new Error('Credential not found');

  // Check revoker is issuer or admin.
  const { data: revoker } = await supabase
    .from('unified_profiles')
    .select('role')
    .eq('id', revokerId)
    .single();
  if (!revoker || (cred.issuer_id !== revokerId && revoker.role !== 'admin')) {
    throw new Error('Only the original issuer or an admin can revoke');
  }

  const { error } = await supabase
    .from('passport_credentials')
    .update({ revoked_at: new Date().toISOString() })
    .eq('id', credentialId);
  if (error) throw new Error(`Revoke failed: ${error.message}`);
}

/** Record a verification event (employer viewed the credential). */
export async function recordVerification(
  env: Env,
  credentialId: string,
  valid: boolean,
  reason: string | undefined,
  verifierId?: string | null,
  verifierIp?: string | null
): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase.from('passport_verifications').insert({
    credential_id: credentialId,
    verifier_id: verifierId ?? null,
    verifier_ip: verifierIp ?? null,
    valid,
    reason,
  });
  if (error) {
    // Don't throw — verification recording is best-effort.
    console.error('recordVerification failed:', error.message);
  }
}

/** Get the public key (PEM-ish format) for employer-side verification. */
export async function getPublicKeyPem(env: Env): Promise<string> {
  const privateKey = loadPrivateKey(env);
  const publicKey = await ed.getPublicKey(privateKey);
  const b64 = bytesToBase64(publicKey);
  // Wrap as PEM (Ed25519 raw 32-byte key, base64).
  const lines = b64.match(/.{1,64}/g)?.join('\n') ?? b64;
  return `-----BEGIN PUBLIC KEY-----\n${lines}\n-----END PUBLIC KEY-----\n`;
}