import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Hono } from 'hono';
import type { Env, ContextVars, UserRole } from '../types';
import { signJwt } from '../services/jwt';
import { hashPassword } from '../services/password';
import { resetRateLimits } from '../middleware/rate-limit';

// Each chain call returns the chain itself so builders compose.
function chainReturning(finalValue: { data?: unknown; error?: unknown } = { data: null, error: null }) {
  const chain = {
    select: vi.fn(() => chain),
    eq: vi.fn(() => chain),
    neq: vi.fn(() => chain),
    insert: vi.fn(() => chain),
    update: vi.fn(() => chain),
    maybeSingle: vi.fn(async () => finalValue),
    single: vi.fn(async () => finalValue),
  };
  return chain;
}

const supabaseMock = {
  from: vi.fn(() => chainReturning()),
};
vi.mock('../services/supabase', () => ({
  getSupabase: () => supabaseMock,
}));

// Quota bonus import is dynamic in auth.ts; stub it via module mock.
vi.mock('../services/quota', () => ({ awardQuotaBonus: vi.fn(async () => {}) }));

// Import after mocks are registered.
import { authRoutes } from './auth';

interface ErrorBody {
  error: { code: string; message: string };
}
interface JsonBody {
  jwt?: string;
  user?: { email: string; role: string; id: string };
  valid?: boolean;
  success?: boolean;
  user_id?: string;
  telegram_id?: string;
  error?: { code: string; message: string };
}
async function errCode(res: Response): Promise<string> {
  const body = (await res.json()) as ErrorBody;
  return body.error.code;
}
async function bodyJson(res: Response): Promise<JsonBody> {
  return (await res.json()) as JsonBody;
}

function makeEnv(): Env {
  return {
    SUPABASE_URL: 'https://test.supabase.co',
    SUPABASE_ANON_KEY: 'anon',
    SUPABASE_SERVICE_KEY: 'service',
    JWT_SECRET: 'test-secret-do-not-use-in-production-xxxxxxxxxxxx',
    JWT_EXPIRY: '1h',
    OPENAI_API_KEY: 'sk-test',
    WEBAPP_URL: 'http://localhost:8787',
  } as Env;
}

function makeApp(): Hono<{ Bindings: Env; Variables: ContextVars }> {
  const app = new Hono<{ Bindings: Env; Variables: ContextVars }>();
  app.route('/api/auth', authRoutes);
  return app;
}

async function setupNewUser() {
  const hashed = await hashPassword('TestPass123!');
  return {
    id: 'usr-1',
    email: 'teacher@test.com',
    password_hash: hashed,
    display_name: 'Teacher One',
    role: 'teacher' as UserRole,
    avatar_url: null,
    telegram_id: null,
    target_exam: null,
    target_score: null,
    current_level: null,
    teacher_institution: null,
    created_at: '2024-01-01T00:00:00Z',
    updated_at: '2024-01-01T00:00:00Z',
  };
}

describe('auth routes', () => {
  let app: Hono<{ Bindings: Env; Variables: ContextVars }>;
  let env: Env;

  beforeEach(() => {
    vi.clearAllMocks();
    resetRateLimits();
    app = makeApp();
    env = makeEnv();
  });

  describe('POST /register', () => {
    it('rejects invalid JSON', async () => {
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'not-json',
      });
      expect(res.status).toBe(400);
      const json = await bodyJson(res);
      expect(json.error!.code).toBe('BAD_REQUEST');
    });

    it('rejects invalid email', async () => {
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'bad', password: 'TestPass123!', name: 'A', role: 'teacher' }),
      });
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INVALID_EMAIL');
    });

    it('rejects weak password', async () => {
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@b.com', password: 'short', name: 'A', role: 'teacher' }),
      });
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('WEAK_PASSWORD');
    });

    it('rejects missing name', async () => {
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@b.com', password: 'TestPass123!', name: '', role: 'teacher' }),
      });
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INVALID_NAME');
    });

    it('rejects invalid role', async () => {
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@b.com', password: 'TestPass123!', name: 'A', role: 'superuser' }),
      });
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INVALID_ROLE');
    });

    it('rejects partner without institution_name', async () => {
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@b.com', password: 'TestPass123!', name: 'A', role: 'partner' }),
      });
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INSTITUTION_NAME_REQUIRED');
    });

    it('returns 409 when email already exists', async () => {
      supabaseMock.from.mockReturnValueOnce(
        chainReturning({ data: { id: 'existing' }, error: null })
      );
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'teacher@test.com', password: 'TestPass123!', name: 'A', role: 'teacher' }),
      }, env);
      expect(res.status).toBe(409);
      expect(await errCode(res)).toBe('EMAIL_EXISTS');
    });

    it('rejects invalid referral code', async () => {
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      supabaseMock.from.mockReturnValueOnce(
        chainReturning({ data: null, error: null })
      );
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          email: 'a@b.com', password: 'TestPass123!', name: 'A', role: 'student',
          referral_code: 'INVALID',
        }),
      }, env);
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INVALID_REFERRAL');
    });

    it('registers a teacher and returns 201 with jwt + cookie', async () => {
      const newUser = await setupNewUser();
      // existing-check
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      // insert -> single
      supabaseMock.from.mockReturnValueOnce(
        chainReturning({ data: newUser, error: null })
      );
      // referral-code uniqueness check (generateUniqueReferralCode)
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      // teacher_profiles insert
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));

      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'teacher@test.com', password: 'TestPass123!', name: 'Teacher One', role: 'teacher' }),
      }, env);

      expect(res.status).toBe(201);
      const json = await bodyJson(res);
      expect(json.jwt).toEqual(expect.any(String));
      expect(json.user!.email).toBe('teacher@test.com');
      expect(json.user!.role).toBe('teacher');
      const cookie = res.headers.get('Set-Cookie');
      expect(cookie).toContain('osee_token=');
      expect(cookie).toContain('HttpOnly');
    });

    it('returns 500 on insert error', async () => {
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      supabaseMock.from.mockReturnValueOnce(
        chainReturning({ data: null, error: { message: 'db down' } })
      );
      const res = await app.request('/api/auth/register', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@b.com', password: 'TestPass123!', name: 'A', role: 'student' }),
      }, env);
      expect(res.status).toBe(500);
      expect(await errCode(res)).toBe('REGISTER_FAILED');
    });
  });

  describe('POST /login', () => {
    it('rejects invalid JSON', async () => {
      const res = await app.request('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'bad',
      });
      expect(res.status).toBe(400);
    });

    it('rejects malformed credentials', async () => {
      const res = await app.request('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'not-email', password: 'x' }),
      });
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INVALID_CREDENTIALS');
    });

    it('returns 401 when user not found', async () => {
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      const res = await app.request('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'a@b.com', password: 'TestPass123!' }),
      }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('INVALID_CREDENTIALS');
    });

    it('returns 401 on wrong password', async () => {
      const user = await setupNewUser();
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: user, error: null }));
      const res = await app.request('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'teacher@test.com', password: 'WrongPass1' }),
      }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('INVALID_CREDENTIALS');
    });

    it('logs in successfully with correct password + sets cookie', async () => {
      const user = await setupNewUser();
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: user, error: null }));
      const res = await app.request('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'teacher@test.com', password: 'TestPass123!' }),
      }, env);
      expect(res.status).toBe(200);
      const json = await bodyJson(res);
      expect(json.jwt).toEqual(expect.any(String));
      expect(json.user!.email).toBe('teacher@test.com');
      expect(res.headers.get('Set-Cookie')).toContain('osee_token=');
    });
  });

  describe('POST /verify', () => {
    it('returns 401 when no token provided', async () => {
      const res = await app.request('/api/auth/verify', { method: 'POST' }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('NO_TOKEN');
    });

    it('returns valid:true for a good token (header)', async () => {
      const user = await setupNewUser();
      const token = await signJwt(env, { sub: user.id, email: user.email, role: user.role });
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: user, error: null }));
      const res = await app.request('/api/auth/verify', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      }, env);
      expect(res.status).toBe(200);
      const json = await bodyJson(res);
      expect(json.valid).toBe(true);
      expect(json.user!.email).toBe('teacher@test.com');
    });

    it('accepts token via cookie', async () => {
      const user = await setupNewUser();
      const token = await signJwt(env, { sub: user.id, email: user.email, role: user.role });
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: user, error: null }));
      const res = await app.request('/api/auth/verify', {
        method: 'POST',
        headers: { Cookie: `osee_token=${token}` },
      }, env);
      expect(res.status).toBe(200);
      expect((await bodyJson(res)).valid).toBe(true);
    });

    it('returns 401 on tampered token', async () => {
      const res = await app.request('/api/auth/verify', {
        method: 'POST',
        headers: { Authorization: 'Bearer not.a.jwt' },
      }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('INVALID_TOKEN');
    });

    it('returns 401 when user no longer exists', async () => {
      const user = await setupNewUser();
      const token = await signJwt(env, { sub: user.id, email: user.email, role: user.role });
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      const res = await app.request('/api/auth/verify', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('USER_NOT_FOUND');
    });
  });

  describe('POST /refresh', () => {
    it('returns 401 without token', async () => {
      const res = await app.request('/api/auth/refresh', { method: 'POST' }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('NO_TOKEN');
    });

    it('issues a new jwt for a valid token', async () => {
      const user = await setupNewUser();
      const token = await signJwt(env, { sub: user.id, email: user.email, role: user.role });
      supabaseMock.from.mockReturnValueOnce(
        chainReturning({ data: { id: user.id, email: user.email, role: user.role }, error: null })
      );
      const res = await app.request('/api/auth/refresh', {
        method: 'POST',
        headers: { Authorization: `Bearer ${token}` },
      }, env);
      expect(res.status).toBe(200);
      const json = await bodyJson(res);
      expect(json.jwt).toEqual(expect.any(String));
      expect(json.jwt!.split('.').length).toBe(3);
      expect(res.headers.get('Set-Cookie')).toContain('osee_token=');
    });
  });

  describe('POST /link-telegram', () => {
    it('rejects missing telegram_id', async () => {
      const res = await app.request('/api/auth/link-telegram', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      }, env);
      expect(res.status).toBe(400);
      expect(await errCode(res)).toBe('INVALID_INPUT');
    });

    it('returns 401 without token', async () => {
      const res = await app.request('/api/auth/link-telegram', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ telegram_id: '12345' }),
      }, env);
      expect(res.status).toBe(401);
      expect(await errCode(res)).toBe('NO_TOKEN');
    });

    it('rejects when telegram_id linked to another account', async () => {
      const user = await setupNewUser();
      const token = await signJwt(env, { sub: user.id, email: user.email, role: user.role });
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: { id: 'other' }, error: null }));
      const res = await app.request('/api/auth/link-telegram', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ telegram_id: '12345' }),
      }, env);
      expect(res.status).toBe(409);
      expect(await errCode(res)).toBe('TELEGRAM_LINKED');
    });

    it('links telegram id successfully', async () => {
      const user = await setupNewUser();
      const token = await signJwt(env, { sub: user.id, email: user.email, role: user.role });
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      supabaseMock.from.mockReturnValueOnce(chainReturning({ data: null, error: null }));
      const res = await app.request('/api/auth/link-telegram', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
        body: JSON.stringify({ telegram_id: '12345' }),
      }, env);
      expect(res.status).toBe(200);
      const json = await bodyJson(res);
      expect(json.success).toBe(true);
      expect(json.telegram_id).toBe('12345');
    });
  });

  describe('POST /logout', () => {
    it('clears cookie and returns success', async () => {
      const res = await app.request('/api/auth/logout', { method: 'POST' }, env);
      expect(res.status).toBe(200);
      expect((await bodyJson(res)).success).toBe(true);
      const cookie = res.headers.get('Set-Cookie');
      expect(cookie).toContain('osee_token=');
      expect(cookie).toContain('Max-Age=0');
    });
  });
});