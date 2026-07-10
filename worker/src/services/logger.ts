/**
 * Structured logger — Task 7 (Wave 1).
 *
 * JSON logs for Cloudflare Logflare ingestion. PII is scrubbed:
 * - email addresses
 * - phone numbers
 * - display_name values
 *
 * Levels: debug, info, warn, error.
 */

type LogLevel = 'debug' | 'info' | 'warn' | 'error';

interface LogEntry {
  timestamp: string;
  level: LogLevel;
  message: string;
  userId?: string;
  requestId?: string;
  agentName?: string;
  traceId?: string;
  durationMs?: number;
  [key: string]: unknown;
}

const PII_PATTERNS: Array<{ pattern: RegExp; replacement: string }> = [
  { pattern: /[\w.+-]+@[\w-]+\.[\w.-]+/g, replacement: '[email]' },
  { pattern: /\+?\d{10,15}/g, replacement: '[phone]' },
];

function scrubPii(value: unknown): unknown {
  if (typeof value === 'string') {
    let scrubbed = value;
    for (const { pattern, replacement } of PII_PATTERNS) {
      scrubbed = scrubbed.replace(pattern, replacement);
    }
    return scrubbed;
  }
  if (Array.isArray(value)) {
    return value.map(scrubPii);
  }
  if (value && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      // Redact known-PII keys entirely.
      if (k === 'email' || k === 'phone' || k === 'display_name' || k === 'password' || k === 'token') {
        out[k] = '[redacted]';
      } else {
        out[k] = scrubPii(v);
      }
    }
    return out;
  }
  return value;
}

function log(level: LogLevel, message: string, fields?: Record<string, unknown>): void {
  const entry: LogEntry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...fields,
  };
  const scrubbed = scrubPii(entry) as Record<string, unknown>;
  // Use console.log so Logflare ingests it as a single line.
  console.log(JSON.stringify(scrubbed));
}

export const logger = {
  debug: (message: string, fields?: Record<string, unknown>) => log('debug', message, fields),
  info: (message: string, fields?: Record<string, unknown>) => log('info', message, fields),
  warn: (message: string, fields?: Record<string, unknown>) => log('warn', message, fields),
  error: (message: string, fields?: Record<string, unknown>) => log('error', message, fields),
};

/** Test-only: scrubPii exposed for testing. */
export const _scrubPiiForTests = scrubPii;