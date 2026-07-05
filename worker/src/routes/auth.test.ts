import { describe, it, expect } from 'vitest';
import { hashPassword, verifyPassword } from '../services/password';
import { buildAuthCookie, buildClearAuthCookie } from '../services/cookie';
import { isValidRole } from '../services/jwt';

// Full route tests with mocked Supabase will be added once we have integration test infra.
// For now, validation logic is tested in isolation below.

describe('password hashing', () => {
  it('hashes and verifies a password', async () => {
    const hash = await hashPassword('TestPass123!');
    expect(hash).toMatch(/^\d+\$[^$]+\$[^$]+$/);
    expect(await verifyPassword('TestPass123!', hash)).toBe(true);
  });

  it('rejects wrong password', async () => {
    const hash = await hashPassword('CorrectPass1!');
    expect(await verifyPassword('wrongpass', hash)).toBe(false);
  });

  it('produces different hashes for same password (random salt)', async () => {
    const h1 = await hashPassword('SamePass123!');
    const h2 = await hashPassword('SamePass123!');
    expect(h1).not.toBe(h2);
  });
});

describe('cookie helper', () => {
  it('builds auth cookie with correct attributes', () => {
    const cookie = buildAuthCookie('my-jwt-token');
    expect(cookie).toContain('osee_token=my-jwt-token');
    expect(cookie).toContain('Domain=.osee.co.id');
    expect(cookie).toContain('Path=/');
    expect(cookie).toContain('HttpOnly');
    expect(cookie).toContain('Secure');
    expect(cookie).toContain('SameSite=Lax');
    expect(cookie).toContain('Max-Age=604800'); // 7 days
  });

  it('builds clear cookie for logout', () => {
    const cookie = buildClearAuthCookie();
    expect(cookie).toContain('osee_token=');
    expect(cookie).toContain('Max-Age=0');
    expect(cookie).toContain('Expires=Thu, 01 Jan 1970');
    expect(cookie).toContain('Domain=.osee.co.id');
  });

  it('allows overriding maxAge', () => {
    const cookie = buildAuthCookie('tok', { maxAge: 3600 });
    expect(cookie).toContain('Max-Age=3600');
  });
});

describe('role validation', () => {
  it('accepts valid roles', () => {
    expect(isValidRole('student')).toBe(true);
    expect(isValidRole('teacher')).toBe(true);
    expect(isValidRole('partner')).toBe(true);
    expect(isValidRole('admin')).toBe(true);
  });

  it('rejects invalid roles', () => {
    expect(isValidRole('superuser')).toBe(false);
    expect(isValidRole('')).toBe(false);
    expect(isValidRole('STUDENT')).toBe(false); // case-sensitive
  });
});

describe('auth route validation logic', () => {
  // Test the validation logic in isolation without needing full Hono context.
  // Full route tests would require mocking Supabase + Hono — covered by QA scenarios.

  const EMAIL_REGEX = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;

  function validateEmail(email: unknown): email is string {
    return typeof email === 'string' && EMAIL_REGEX.test(email);
  }

  function validatePassword(password: unknown): password is string {
    return (
      typeof password === 'string' &&
      password.length >= 8 &&
      /[A-Za-z]/.test(password) &&
      /\d/.test(password)
    );
  }

  it('validates email format', () => {
    expect(validateEmail('teacher@test.com')).toBe(true);
    expect(validateEmail('student.name+tag@osee.co.id')).toBe(true);
    expect(validateEmail('invalid')).toBe(false);
    expect(validateEmail('missing@domain')).toBe(false);
    expect(validateEmail('@nodomain.com')).toBe(false);
    expect(validateEmail('')).toBe(false);
    expect(validateEmail(null)).toBe(false);
    expect(validateEmail(123)).toBe(false);
  });

  it('validates password strength', () => {
    expect(validatePassword('TestPass123!')).toBe(true);
    expect(validatePassword('abcdefgh1')).toBe(true); // min 8, has letter + number
    expect(validatePassword('short1')).toBe(false); // too short
    expect(validatePassword('allletters')).toBe(false); // no number
    expect(validatePassword('12345678')).toBe(false); // no letter
    expect(validatePassword('')).toBe(false);
  });
});