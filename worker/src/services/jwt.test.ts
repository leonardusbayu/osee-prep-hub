import { describe, it, expect } from 'vitest';
import { signJwt, verifyJwt, extractBearerToken, isValidRole, generateRefreshToken } from './jwt';
import type { Env } from '../types';

const mockEnv: Pick<Env, 'JWT_SECRET' | 'JWT_EXPIRY'> = {
  JWT_SECRET: 'test-secret-do-not-use-in-production-xxxxxxxxxxxx',
  JWT_EXPIRY: '1h',
} as Env;

const fullMockEnv = mockEnv as Env;

describe('jwt service', () => {
  it('signs and verifies a valid JWT', async () => {
    const token = await signJwt(fullMockEnv, {
      sub: 'user-123',
      email: 'teacher@test.com',
      role: 'teacher',
    });
    expect(typeof token).toBe('string');
    expect(token.split('.').length).toBe(3);

    const payload = await verifyJwt(fullMockEnv, token);
    expect(payload.sub).toBe('user-123');
    expect(payload.email).toBe('teacher@test.com');
    expect(payload.role).toBe('teacher');
    expect(payload.exp).toBeGreaterThan(payload.iat);
  });

  it('rejects tampered token', async () => {
    const token = await signJwt(fullMockEnv, {
      sub: 'user-456',
      email: 'student@test.com',
      role: 'student',
    });
    const tampered = token.slice(0, -5) + 'XXXXX';
    await expect(verifyJwt(fullMockEnv, tampered)).rejects.toThrow();
  });

  it('rejects expired token', async () => {
    // Manually craft an expired token by signing with exp in the past.
    // We bypass signJwt and build the JWT directly.
    const encoder2 = new TextEncoder();
    const now = Math.floor(Date.now() / 1000);
    const payload = {
      sub: 'user-789',
      email: 'admin@test.com',
      role: 'admin' as const,
      iat: now - 3600,
      exp: now - 60, // expired 60s ago
    };
    const header = { alg: 'HS256', typ: 'JWT' };
    const b64 = (bytes: Uint8Array) => {
      let binary = '';
      for (const b of bytes) binary += String.fromCharCode(b);
      return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    };
    const headerB64 = b64(encoder2.encode(JSON.stringify(header)));
    const payloadB64 = b64(encoder2.encode(JSON.stringify(payload)));
    const signingInput = `${headerB64}.${payloadB64}`;
    const key = await crypto.subtle.importKey(
      'raw',
      encoder2.encode(fullMockEnv.JWT_SECRET),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign']
    );
    const sig = await crypto.subtle.sign('HMAC', key, encoder2.encode(signingInput));
    const token = `${signingInput}.${b64(new Uint8Array(sig))}`;
    await expect(verifyJwt(fullMockEnv, token)).rejects.toThrow(/expired/i);
  });

  it('extracts bearer token from header', () => {
    expect(extractBearerToken('Bearer abc123')).toBe('abc123');
    expect(extractBearerToken('bearer abc123')).toBe('abc123');
    expect(extractBearerToken('Bearer  ')).toBeNull();
    expect(extractBearerToken(null)).toBeNull();
    expect(extractBearerToken(undefined)).toBeNull();
    expect(extractBearerToken('Basic abc123')).toBeNull();
  });

  it('validates user roles', () => {
    expect(isValidRole('student')).toBe(true);
    expect(isValidRole('teacher')).toBe(true);
    expect(isValidRole('partner')).toBe(true);
    expect(isValidRole('admin')).toBe(true);
    expect(isValidRole('superuser')).toBe(false);
    expect(isValidRole('')).toBe(false);
  });

  it('generates unique refresh tokens', () => {
    const a = generateRefreshToken();
    const b = generateRefreshToken();
    expect(a).not.toBe(b);
    expect(a.length).toBeGreaterThan(20);
  });
});