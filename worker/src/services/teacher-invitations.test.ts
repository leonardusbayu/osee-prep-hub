import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

// Mock Supabase client with chainable query builder.
type Row = Record<string, unknown>;
interface MockQuery {
  select: (cols?: string, opts?: Record<string, unknown>) => MockQuery;
  eq: (col: string, val: unknown) => MockQuery;
  is: (col: string, val: null) => MockQuery;
  gt: (col: string, val: unknown) => MockQuery;
  lt: (col: string, val: unknown) => MockQuery;
  order: (col: string, opts?: Record<string, unknown>) => MockQuery;
  limit: (n: number) => MockQuery;
  maybeSingle: () => Promise<{ data: Row | null; error: unknown }>;
  single: () => Promise<{ data: Row | null; error: unknown }>;
  insert: (row: Record<string, unknown>) => { select: (cols?: string) => { single: () => Promise<{ data: Row | null; error: unknown }> } };
  update: (patch: Record<string, unknown>) => MockQuery;
}

function buildChain(finalData: Row | null, finalError: unknown = null): MockQuery {
  const q: MockQuery = {
    select: () => q,
    eq: () => q,
    is: () => q,
    gt: () => q,
    lt: () => q,
    order: () => q,
    limit: () => q,
    maybeSingle: async () => ({ data: finalData, error: finalError }),
    single: async () => ({ data: finalData, error: finalError }),
    insert: (row: Record<string, unknown>) => ({
      select: () => ({
        single: async () => ({ data: { ...row, id: 'inv-new-id', created_at: 'now' } as Row, error: null }),
      }),
    }),
    update: () => q,
  };
  return q;
}

const mockSupabase = {
  from: vi.fn(),
};

vi.mock('../services/supabase', () => ({
  getSupabase: vi.fn(() => mockSupabase),
}));

vi.mock('../services/email', () => ({
  sendTeacherInvitation: vi.fn(async () => ({ id: 'email-id-1' })),
  EmailError: class EmailError extends Error {
    code: string;
    constructor(code: string, message: string) {
      super(message);
      this.code = code;
    }
  },
}));

import { createInvitation, validateInvitation, acceptInvitation, InvitationError } from './teacher-invitations';
import { sendTeacherInvitation } from './email';
import type { Env } from '../types';

const mockEnv = {
  WEBAPP_URL: 'https://prep.osee.co.id',
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

function isoFuture(ms: number): string {
  return new Date(Date.now() + ms).toISOString();
}
function isoPast(ms: number): string {
  return new Date(Date.now() - ms).toISOString();
}

describe('teacher-invitations service', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockSupabase.from.mockClear();
  });

  describe('createInvitation', () => {
    it('creates a new invitation, sends email, returns inviteUrl (happy path)', async () => {
      // partner lookup
      let call = 0;
      mockSupabase.from.mockImplementation((table: string) => {
        if (table === 'unified_profiles') return buildChain({ display_name: 'Pak Budi', teacher_institution: 'SMA 1 Jakarta' });
        if (table === 'teacher_invitations') {
          call++;
          if (call === 1) return buildChain(null); // no existing pending
          if (call === 2) {
            // insert: return a chain whose .insert().select().single() resolves
            return {
              select: () => ({}) as never,
              eq: () => ({}) as never,
              is: () => ({}) as never,
              gt: () => ({}) as never,
              lt: () => ({}) as never,
              order: () => ({}) as never,
              limit: () => ({}) as never,
              maybeSingle: async () => ({ data: null, error: null }),
              single: async () => ({ data: null, error: null }),
              insert: (row: Record<string, unknown>) => ({
                select: () => ({
                  single: async () => ({
                    data: {
                      id: 'inv-uuid-1',
                      partner_id: row.partner_id,
                      teacher_email: row.teacher_email,
                      institution_name: row.institution_name,
                      token: row.token,
                      accepted_at: null,
                      accepted_by: null,
                      expires_at: row.expires_at,
                      created_at: '2026-01-01T00:00:00Z',
                    },
                    error: null,
                  }),
                }),
              }),
              update: () => buildChain(null) as never,
            } as MockQuery;
          }
        }
        return buildChain(null);
      });

      const result = await createInvitation(mockEnv, 'partner-1', 'newteacher@example.com');

      expect(result.invitation.id).toBe('inv-uuid-1');
      expect(result.invitation.teacher_email).toBe('newteacher@example.com');
      expect(result.invitation.institution_name).toBe('SMA 1 Jakarta');
      expect(result.invitation.accepted_at).toBeNull();
      expect(result.inviteUrl).toContain('/register?invite=');
      expect(result.inviteUrl).toContain(result.invitation.token);
      expect(result.email_sent).toBe(true);
      expect(result.email_error).toBeUndefined();
      expect(sendTeacherInvitation).toHaveBeenCalledOnce();
    });

    it('reuses an existing pending invitation (idempotency)', async () => {
      const existingInv = {
        id: 'inv-existing',
        partner_id: 'partner-1',
        teacher_email: 't@example.com',
        institution_name: 'SMA 1',
        token: 'existingtoken',
        accepted_at: null,
        accepted_by: null,
        expires_at: isoFuture(24 * 60 * 60 * 1000),
        created_at: '2026-01-01T00:00:00Z',
      };
      let call = 0;
      mockSupabase.from.mockImplementation((table: string) => {
        if (table === 'unified_profiles') return buildChain({ teacher_institution: 'SMA 1', display_name: 'Pak' });
        if (table === 'teacher_invitations') {
          call++;
          if (call === 1) return buildChain(existingInv); // existing pending found
        }
        return buildChain(null);
      });

      const result = await createInvitation(mockEnv, 'partner-1', 't@example.com');

      expect(result.invitation.id).toBe('inv-existing');
      expect(result.invitation.token).toBe('existingtoken');
      expect(result.inviteUrl).toContain('existingtoken');
      expect(result.email_sent).toBe(true);
      // Should still have sent an email (re-notifying the invitee)
      expect(sendTeacherInvitation).toHaveBeenCalledOnce();
    });

    it('throws NO_INSTITUTION when partner has no institution_name', async () => {
      mockSupabase.from.mockImplementation(() => buildChain({ teacher_institution: null, display_name: 'x' }));

      await expect(createInvitation(mockEnv, 'partner-1', 't@example.com')).rejects.toThrow(
        /no institution/i
      );
      expect(sendTeacherInvitation).not.toHaveBeenCalled();
    });

    it('throws INVALID_EMAIL on missing or malformed email', async () => {
      mockSupabase.from.mockImplementation(() => buildChain({ teacher_institution: 'SMA 1' }));
      await expect(createInvitation(mockEnv, 'partner-1', '')).rejects.toThrow(/valid teacher email/i);
      await expect(createInvitation(mockEnv, 'partner-1', 'not-an-email')).rejects.toThrow(/valid teacher email/i);
    });

    it('surfaces email send failure without failing the create', async () => {
      vi.mocked(sendTeacherInvitation).mockRejectedValueOnce(new Error('Resend down'));
      mockSupabase.from.mockImplementation((table: string) => {
        if (table === 'unified_profiles') return buildChain({ teacher_institution: 'SMA 1', display_name: 'P' });
        if (table === 'teacher_invitations') {
          return {
            ...buildChain(null),
            insert: (row: Record<string, unknown>) => ({
              select: () => ({
                single: async () => ({
                  data: {
                    id: 'inv-2',
                    partner_id: row.partner_id,
                    teacher_email: row.teacher_email,
                    institution_name: row.institution_name,
                    token: row.token,
                    accepted_at: null,
                    accepted_by: null,
                    expires_at: row.expires_at,
                    created_at: '2026-01-01T00:00:00Z',
                  },
                  error: null,
                }),
              }),
            }),
          } as MockQuery;
        }
        return buildChain(null);
      });

      const result = await createInvitation(mockEnv, 'partner-1', 't@example.com');
      expect(result.invitation.id).toBe('inv-2');
      expect(result.email_sent).toBe(false);
      expect(result.email_error).toContain('Resend down');
    });

    it('throws CREATE_FAILED when insert errors', async () => {
      mockSupabase.from.mockImplementation((table: string) => {
        if (table === 'unified_profiles') return buildChain({ teacher_institution: 'SMA 1' });
        if (table === 'teacher_invitations') {
          return {
            ...buildChain(null),
            insert: () => ({
              select: () => ({
                single: async () => ({ data: null, error: { message: 'constraint violation' } }),
              }),
            }),
          } as MockQuery;
        }
        return buildChain(null);
      });

      await expect(createInvitation(mockEnv, 'partner-1', 't@example.com')).rejects.toThrow(
        /constraint violation/
      );
    });
  });

  describe('validateInvitation', () => {
    it('returns the invitation when token is valid, pending, un-expired', async () => {
      const validInv = {
        id: 'inv-1',
        partner_id: 'p',
        teacher_email: 't@example.com',
        institution_name: 'SMA 1',
        token: 'goodtoken',
        accepted_at: null,
        accepted_by: null,
        expires_at: isoFuture(60_000),
        created_at: '2026-01-01T00:00:00Z',
      };
      mockSupabase.from.mockImplementation(() => buildChain(validInv));

      const inv = await validateInvitation(mockEnv, 'goodtoken');
      expect(inv.id).toBe('inv-1');
      expect(inv.institution_name).toBe('SMA 1');
    });

    it('throws INVALID_TOKEN on empty token', async () => {
      await expect(validateInvitation(mockEnv, '')).rejects.toThrow(/token is required/i);
      await expect(validateInvitation(mockEnv, '   ')).rejects.toThrow(/token is required/i);
    });

    it('throws INVITATION_NOT_FOUND when token is unknown', async () => {
      mockSupabase.from.mockImplementation(() => buildChain(null));
      await expect(validateInvitation(mockEnv, 'unknowntoken')).rejects.toThrow(/not found/i);
    });

    it('throws INVITATION_ALREADY_USED when accepted_at is set', async () => {
      const usedInv = {
        id: 'inv-used',
        token: 't',
        accepted_at: isoPast(60_000),
        accepted_by: 'user-x',
        expires_at: isoFuture(60_000),
        institution_name: 'SMA 1',
        teacher_email: 't@example.com',
        partner_id: 'p',
        created_at: '2026-01-01T00:00:00Z',
      };
      mockSupabase.from.mockImplementation(() => buildChain(usedInv));
      await expect(validateInvitation(mockEnv, 't')).rejects.toThrow(/already been used/i);
    });

    it('throws INVITATION_EXPIRED when expires_at is in the past', async () => {
      const expiredInv = {
        id: 'inv-exp',
        token: 't',
        accepted_at: null,
        accepted_by: null,
        expires_at: isoPast(60_000),
        institution_name: 'SMA 1',
        teacher_email: 't@example.com',
        partner_id: 'p',
        created_at: '2026-01-01T00:00:00Z',
      };
      mockSupabase.from.mockImplementation(() => buildChain(expiredInv));
      await expect(validateInvitation(mockEnv, 't')).rejects.toThrow(/expired/i);
    });
  });

  describe('acceptInvitation', () => {
    it('marks accepted and returns institution_name', async () => {
      const validInv = {
        id: 'inv-acc',
        partner_id: 'p',
        teacher_email: 't@example.com',
        institution_name: 'SMA Negeri 2',
        token: 'good',
        accepted_at: null,
        accepted_by: null,
        expires_at: isoFuture(60_000),
        created_at: '2026-01-01T00:00:00Z',
      };
      let call = 0;
      mockSupabase.from.mockImplementation(() => {
        call++;
        if (call === 1) return buildChain(validInv); // validate
        if (call === 2) return buildChain(null); // update success
        return buildChain(null);
      });

      const result = await acceptInvitation(mockEnv, 'good', 'new-user-id');
      expect(result.institution_name).toBe('SMA Negeri 2');
    });

    it('rethrows validation errors (e.g. expired)', async () => {
      const expiredInv = {
        id: 'inv-x',
        token: 't',
        accepted_at: null,
        accepted_by: null,
        expires_at: isoPast(60_000),
        institution_name: 'SMA 1',
        teacher_email: 't@example.com',
        partner_id: 'p',
        created_at: '2026-01-01T00:00:00Z',
      };
      mockSupabase.from.mockImplementation(() => buildChain(expiredInv));
      await expect(acceptInvitation(mockEnv, 't', 'u')).rejects.toThrow(/expired/i);
    });
  });

  it('InvitationError carries a stable code', () => {
    const err = new InvitationError('INVITATION_EXPIRED', 'boom');
    expect(err.code).toBe('INVITATION_EXPIRED');
    expect(err.name).toBe('InvitationError');
    expect(err).toBeInstanceOf(Error);
  });
});