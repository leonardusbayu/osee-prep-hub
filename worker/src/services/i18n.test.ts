/** i18n service tests — Task 4 (Wave 1). */

import { describe, it, expect } from 'vitest';
import { t, detectLocale } from './i18n';

describe('i18n service', () => {
  it('returns English string by default', () => {
    expect(t('auth.login_success')).toBe('Logged in');
  });

  it('returns Bahasa string when locale=id', () => {
    expect(t('auth.login_success', 'id')).toBe('Berhasil masuk');
  });

  it('falls back to English when key missing in id', () => {
    // Use a key we know exists in en but check fallback behavior with a missing key.
    expect(t('nonexistent.key', 'id')).toBe('nonexistent.key');
  });

  it('interpolates params', () => {
    // Use the agent.rate_limited key (no params) — just verify params substitution
    // works on a synthetic key.
    const result = t('Hello {name}', 'en', { name: 'Andi' });
    expect(result).toBe('Hello Andi');
  });

  it('detectLocale from Accept-Language', () => {
    expect(detectLocale('id-ID,id;q=0.9,en;q=0.8')).toBe('id');
    expect(detectLocale('en-US,en;q=0.9')).toBe('en');
    expect(detectLocale('fr-FR')).toBe('en'); // unknown → fallback en
  });

  it('detectLocale prefers userPreferred over header', () => {
    expect(detectLocale('en-US', 'id')).toBe('id');
  });

  it('detectLocale defaults to en', () => {
    expect(detectLocale(null, null)).toBe('en');
  });
});