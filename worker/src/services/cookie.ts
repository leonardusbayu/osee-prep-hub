/**
 * Cookie helper — builds Set-Cookie header for SSO across *.osee.co.id.
 * Per Task 1.4: domain=.osee.co.id, HttpOnly, Secure, SameSite=Lax, Path=/, Max-Age=7d.
 */

const COOKIE_NAME = 'osee_token';
const MAX_AGE_SECONDS = 7 * 24 * 60 * 60; // 7 days

/** Cookie attributes per spec. */
export interface CookieOptions {
  maxAge?: number; // seconds; default 7 days
  domain?: string; // default .osee.co.id
  path?: string; // default /
  httpOnly?: boolean; // default true
  secure?: boolean; // default true
  sameSite?: 'Lax' | 'Strict' | 'None'; // default Lax
}

/** Build a Set-Cookie header value for the auth token. */
export function buildAuthCookie(token: string, options: CookieOptions = {}): string {
  const opts: Required<CookieOptions> = {
    maxAge: options.maxAge ?? MAX_AGE_SECONDS,
    domain: options.domain ?? '.osee.co.id',
    path: options.path ?? '/',
    httpOnly: options.httpOnly ?? true,
    secure: options.secure ?? true,
    sameSite: options.sameSite ?? 'Lax',
  };
  const parts = [
    `${COOKIE_NAME}=${token}`,
    `Domain=${opts.domain}`,
    `Path=${opts.path}`,
    `Max-Age=${opts.maxAge}`,
    `SameSite=${opts.sameSite}`,
  ];
  if (opts.httpOnly) parts.push('HttpOnly');
  if (opts.secure) parts.push('Secure');
  return parts.join('; ');
}

/** Build a Set-Cookie header that clears the auth cookie (logout). */
export function buildClearAuthCookie(options: CookieOptions = {}): string {
  const opts: Required<Omit<CookieOptions, 'maxAge'>> = {
    domain: options.domain ?? '.osee.co.id',
    path: options.path ?? '/',
    httpOnly: options.httpOnly ?? true,
    secure: options.secure ?? true,
    sameSite: options.sameSite ?? 'Lax',
  };
  const parts = [
    `${COOKIE_NAME}=`,
    `Domain=${opts.domain}`,
    `Path=${opts.path}`,
    `Max-Age=0`,
    `Expires=Thu, 01 Jan 1970 00:00:00 GMT`,
    `SameSite=${opts.sameSite}`,
  ];
  if (opts.httpOnly) parts.push('HttpOnly');
  if (opts.secure) parts.push('Secure');
  return parts.join('; ');
}

export { COOKIE_NAME };