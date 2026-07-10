/**
 * Worker-side i18n — Task 4 (Wave 1).
 *
 * Simple key→string map for worker-side messages (API errors, email templates).
 * Falls back to English when a key is missing for the requested locale.
 */

import { en } from '../i18n/en';
import { id } from '../i18n/id';

export type Locale = 'en' | 'id';

const BUNDLES: Record<Locale, Record<string, string>> = {
  en: en as Record<string, string>,
  id: id as Record<string, string>,
};

/** Resolve a key for the given locale, falling back to English then the key itself. */
export function t(key: string, locale: Locale = 'en', params?: Record<string, string | number>): string {
  const bundle = BUNDLES[locale] ?? BUNDLES.en;
  let value = bundle[key] ?? BUNDLES.en[key] ?? key;
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      value = value.replace(new RegExp(`\\{${k}\\}`, 'g'), String(v));
    }
  }
  return value;
}

/** Detect a user's preferred locale from their profile or Accept-Language header. */
export function detectLocale(acceptLanguage?: string | null, userPreferred?: string | null): Locale {
  if (userPreferred === 'id' || userPreferred === 'en') return userPreferred;
  if (acceptLanguage) {
    const langs = acceptLanguage.split(',').map(l => l.split(';')[0].trim().toLowerCase());
    for (const l of langs) {
      if (l.startsWith('id')) return 'id';
      if (l.startsWith('en')) return 'en';
    }
  }
  return 'en';
}