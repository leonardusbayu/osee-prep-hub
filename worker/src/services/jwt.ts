import type { Env, JwtPayload, UserRole } from '../types';

/**
 * JWT utilities using Web Crypto API (available in Cloudflare Workers).
 * No external JWT library needed — uses HMAC-SHA256.
 */

const encoder = new TextEncoder();
const decoder = new TextDecoder();

/** Base64Url encode bytes. */
function base64UrlEncode(bytes: Uint8Array): string {
  let binary = '';
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** Base64Url decode to bytes. */
function base64UrlDecode(s: string): Uint8Array {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const binary = atob(s);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

/** Import HMAC key from secret. */
async function getHmacKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify']
  );
}

/** Parse JWT expiry string like "7d" into seconds. */
function parseExpiry(expiry: string): number {
  const match = /^(\d+)([smhd])$/.exec(expiry);
  if (!match) throw new Error(`Invalid JWT expiry: ${expiry}`);
  const num = parseInt(match[1], 10);
  const unit = match[2];
  const multipliers: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };
  return num * multipliers[unit];
}

/** Sign a JWT. */
export async function signJwt(
  env: Env,
  payload: Omit<JwtPayload, 'exp' | 'iat'>,
  expiryStr?: string
): Promise<string> {
  const expirySeconds = parseExpiry(expiryStr ?? env.JWT_EXPIRY ?? '7d');
  const now = Math.floor(Date.now() / 1000);
  const fullPayload: JwtPayload = {
    ...payload,
    iat: now,
    exp: now + expirySeconds,
  };

  const header = { alg: 'HS256', typ: 'JWT' };
  const headerB64 = base64UrlEncode(encoder.encode(JSON.stringify(header)));
  const payloadB64 = base64UrlEncode(encoder.encode(JSON.stringify(fullPayload)));
  const signingInput = `${headerB64}.${payloadB64}`;

  const key = await getHmacKey(env.JWT_SECRET);
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(signingInput));
  const signatureB64 = base64UrlEncode(new Uint8Array(signature));

  return `${signingInput}.${signatureB64}`;
}

/** Verify a JWT and return the payload. Throws on invalid. */
export async function verifyJwt(env: Env, token: string): Promise<JwtPayload> {
  const parts = token.split('.');
  if (parts.length !== 3) throw new Error('Invalid JWT format');
  const [headerB64, payloadB64, signatureB64] = parts;
  const signingInput = `${headerB64}.${payloadB64}`;

  // Verify signature
  const key = await getHmacKey(env.JWT_SECRET);
  const signatureBytes = base64UrlDecode(signatureB64);
  const valid = await crypto.subtle.verify('HMAC', key, signatureBytes, encoder.encode(signingInput));
  if (!valid) throw new Error('Invalid JWT signature');

  // Decode payload
  const payloadJson = decoder.decode(base64UrlDecode(payloadB64));
  const payload = JSON.parse(payloadJson) as JwtPayload;

  // Check expiry
  const now = Math.floor(Date.now() / 1000);
  if (payload.exp < now) throw new Error('JWT expired');

  return payload;
}

/** Extract Bearer token from Authorization header. Returns null if absent or malformed. */
export function extractBearerToken(authHeader: string | undefined | null): string | null {
  if (!authHeader) return null;
  const match = /^Bearer\s+(.+)$/i.exec(authHeader);
  if (!match) return null;
  const token = match[1].trim();
  return token.length > 0 ? token : null;
}

/** Generate a random refresh token (opaque). */
export function generateRefreshToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return base64UrlEncode(bytes);
}

/** Validate that a role string is a valid UserRole.
 *  Accepts 'institution' as an alias for 'partner' (Blueprint line 359 uses
 *  'institution'; implementation uses 'partner' for the same concept). */
export function isValidRole(role: string): role is UserRole {
  return role === 'student' || role === 'teacher' || role === 'partner' || role === 'admin' || role === 'institution';
}