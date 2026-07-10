/**
 * Passport service tests — Task 3 (Wave 1).
 *
 * Tests the Ed25519 sign + verify flow without Supabase (mocked).
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import * as ed from '@noble/ed25519';
import { sha256 } from '@noble/hashes/sha2.js';
import { issueCredential, verifyCredential, hashEvidence, getPublicKeyPem } from './passport';

vi.mock('./supabase', () => ({
  getSupabase: vi.fn(() => ({
    from: vi.fn(() => {
      const c: any = {
        insert: vi.fn(() => c),
        select: vi.fn(() => c),
        eq: vi.fn(() => c),
        single: vi.fn(async () => ({ data: null, error: null })),
        update: vi.fn(() => c),
        delete: vi.fn(() => c),
      };
      return c;
    }),
  })),
}));

// Test private key (32 bytes hex) — DO NOT use in production.
const TEST_PRIVATE_KEY_HEX = 'a'.repeat(64);
const TEST_ENV = {
  PASSPORT_SIGNING_KEY: TEST_PRIVATE_KEY_HEX,
  PASSPORT_KEY_ID: 'test-key',
} as never;

function hexToBytes(hex: string): Uint8Array {
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i++) {
    out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

describe('passport service', () => {
  beforeEach(() => vi.clearAllMocks());

  it('hashEvidence is deterministic', () => {
    const h1 = hashEvidence('pdf', 'https://example.com/a.pdf');
    const h2 = hashEvidence('pdf', 'https://example.com/a.pdf');
    expect(h1).toBe(h2);
    expect(h1).toHaveLength(64); // SHA-256 hex
  });

  it('hashEvidence differs by content', () => {
    const h1 = hashEvidence('pdf', 'url', 'content-a');
    const h2 = hashEvidence('pdf', 'url', 'content-b');
    expect(h1).not.toBe(h2);
  });

  it('issue + verify round-trip: signature matches', async () => {
    // Test the crypto flow directly without Supabase.
    const { getSupabase } = await import('./supabase');
    const chain: any = {
      insert: vi.fn((row: any) => {
        return {
          select: vi.fn(() => ({
            single: vi.fn(async () => ({
              data: {
                id: 'cred-1',
                user_id: row.user_id,
                credential_type: row.credential_type,
                issuer_id: '',
                subject_data: row.subject_data,
                signature: row.signature,
                public_key_id: row.public_key_id,
                issued_at: row.issued_at,
                revoked_at: null,
              },
              error: null,
            })),
          })),
        };
      }),
    };
    // Evidence insert returns rows with hashes.
    chain.insert = vi.fn((row: any) => {
      if (Array.isArray(row)) {
        return {
          select: vi.fn(() => ({
            data: row.map((r: any, i: number) => ({ ...r, id: `ev-${i}`, created_at: '2025-01-01' })),
            error: null,
          })),
        };
      }
      // Credential insert.
      return {
        select: vi.fn(() => ({
          single: vi.fn(async () => ({
            data: {
              id: 'cred-1',
              user_id: row.user_id,
              credential_type: row.credential_type,
              issuer_id: '',
              subject_data: row.subject_data,
              signature: row.signature,
              public_key_id: row.public_key_id,
              issued_at: row.issued_at,
              revoked_at: null,
            },
            error: null,
          })),
        })),
      };
    });
    (getSupabase as any).mockReturnValue({ from: vi.fn(() => chain) });

    const issueResult = await issueCredential(TEST_ENV, {
      userId: 'student-1',
      credentialType: 'score_report',
      subjectData: { exam: 'IELTS', score: 7.0, date: '2025-01-01' },
      evidence: [
        { evidence_type: 'pdf', storage_url: 'https://example.com/report.pdf' },
      ],
    });

    expect(issueResult.credential.signature).toHaveLength(128); // Ed25519 sig hex
    expect(issueResult.credential.public_key_id).toHaveLength(64);
    expect(issueResult.evidence).toHaveLength(1);

    // Manually verify the signature using the same private key.
    const priv = hexToBytes(TEST_PRIVATE_KEY_HEX);
    const pub = await ed.getPublicKey(priv);
    const evidenceHash = hashEvidence('pdf', 'https://example.com/report.pdf');
    const message = sha256(
      new TextEncoder().encode(
        JSON.stringify({
          subject_data: { exam: 'IELTS', score: 7.0, date: '2025-01-01' },
          evidence_hashes: [evidenceHash],
          issued_at: issueResult.credential.issued_at,
        })
      )
    );
    const sigBytes = hexToBytes(issueResult.credential.signature);
    const isValid = await ed.verify(sigBytes, message, pub);
    expect(isValid).toBe(true);
  });

  it('verifyCredential returns invalid when signature tampered', async () => {
    const { getSupabase } = await import('./supabase');
    const verifyChain: any = {
      from: vi.fn((table: string) => {
        if (table === 'passport_credentials') {
          const c: any = {
            select: () => c,
            eq: () => c,
            single: async () => ({
              data: {
                id: 'cred-1',
                user_id: 'student-1',
                credential_type: 'score_report',
                issuer_id: 'teacher-1',
                subject_data: { exam: 'IELTS', score: 7.5 }, // TAMPERED (was 7.0)
                signature: 'b'.repeat(128), // wrong sig
                public_key_id: 'x'.repeat(64),
                issued_at: '2025-01-01T00:00:00.000Z',
                revoked_at: null,
              },
              error: null,
            }),
          };
          return c;
        }
        if (table === 'passport_evidence') {
          const c: any = { select: () => c, eq: () => ({ data: [], error: null }) };
          return c;
        }
        return {};
      }),
    };
    (getSupabase as any).mockReturnValue(verifyChain);

    const result = await verifyCredential(TEST_ENV, 'cred-1');
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('signature_mismatch');
  });

  it('verifyCredential returns invalid when revoked', async () => {
    const { getSupabase } = await import('./supabase');
    const verifyChain: any = {
      from: vi.fn((table: string) => {
        if (table === 'passport_credentials') {
          const c: any = {
            select: () => c,
            eq: () => c,
            single: async () => ({
              data: {
                id: 'cred-1',
                user_id: 'student-1',
                credential_type: 'score_report',
                issuer_id: 'teacher-1',
                subject_data: { exam: 'IELTS', score: 7.0 },
                signature: 'a'.repeat(128),
                public_key_id: 'x'.repeat(64),
                issued_at: '2025-01-01T00:00:00.000Z',
                revoked_at: '2025-02-01T00:00:00.000Z', // REVOKED
              },
              error: null,
            }),
          };
          return c;
        }
        if (table === 'passport_evidence') {
          const c: any = { select: () => c, eq: () => ({ data: [], error: null }) };
          return c;
        }
        return {};
      }),
    };
    (getSupabase as any).mockReturnValue(verifyChain);

    const result = await verifyCredential(TEST_ENV, 'cred-1');
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('revoked');
  });

  it('getPublicKeyPem returns PEM with correct headers', async () => {
    const pem = await getPublicKeyPem(TEST_ENV);
    expect(pem).toContain('-----BEGIN PUBLIC KEY-----');
    expect(pem).toContain('-----END PUBLIC KEY-----');
    // Public key is 32 bytes → 44 chars base64 (with padding)
    const body = pem.replace(/-----[A-Z ]+-----/g, '').trim();
    expect(body.length).toBeGreaterThan(40);
  });

  it('verifyCredential returns not_found when credential missing', async () => {
    const { getSupabase } = await import('./supabase');
    const verifyChain: any = {
      from: vi.fn(() => {
        const c: any = { select: () => c, eq: () => c, single: async () => ({ data: null, error: 'not found' }) };
        return c;
      }),
    };
    (getSupabase as any).mockReturnValue(verifyChain);

    const result = await verifyCredential(TEST_ENV, 'missing-id');
    expect(result.credential).toBeNull();
    expect(result.valid).toBe(false);
    expect(result.reason).toBe('not_found');
  });
});

// Sanity: confirm @noble/ed25519 itself works.
describe('ed25519 sanity', () => {
  it('sign + verify round-trip', async () => {
    const priv = new Uint8Array(32).fill(0xab);
    const pub = await ed.getPublicKey(priv);
    const msg = sha256(new TextEncoder().encode('hello'));
    const sig = await ed.sign(msg, priv);
    expect(await ed.verify(sig, msg, pub)).toBe(true);
  });
});