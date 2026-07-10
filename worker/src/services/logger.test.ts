/** Logger tests — Task 7 (Wave 1). */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { logger, _scrubPiiForTests } from './logger';

describe('logger', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.spyOn(console, 'log').mockImplementation(() => {});
  });

  it('emits JSON with level + message + timestamp', () => {
    logger.info('test message');
    expect(console.log).toHaveBeenCalled();
    const call = (console.log as any).mock.calls[0][0] as string;
    const parsed = JSON.parse(call);
    expect(parsed.level).toBe('info');
    expect(parsed.message).toBe('test message');
    expect(parsed.timestamp).toBeDefined();
  });

  it('scrubs email from message', () => {
    logger.info('user logged in: alice@example.com');
    const call = (console.log as any).mock.calls[0][0] as string;
    expect(call).toContain('[email]');
    expect(call).not.toContain('alice@example.com');
  });

  it('scrubs phone from message', () => {
    logger.info('call me at +6281234567890');
    const call = (console.log as any).mock.calls[0][0] as string;
    expect(call).toContain('[phone]');
    expect(call).not.toContain('6281234567890');
  });

  it('redacts known-PII fields in objects', () => {
    logger.info('user data', { email: 'x@y.com', display_name: 'Alice', id: '123' });
    const call = (console.log as any).mock.calls[0][0] as string;
    const parsed = JSON.parse(call);
    expect(parsed.email).toBe('[redacted]');
    expect(parsed.display_name).toBe('[redacted]');
    expect(parsed.id).toBe('123');
  });

  it('redacts password and token fields', () => {
    logger.info('auth', { password: 'secret', token: 'jwt-abc', userId: 'u1' });
    const call = (console.log as any).mock.calls[0][0] as string;
    const parsed = JSON.parse(call);
    expect(parsed.password).toBe('[redacted]');
    expect(parsed.token).toBe('[redacted]');
    expect(parsed.userId).toBe('u1');
  });

  it('supports all log levels', () => {
    logger.debug('d');
    logger.info('i');
    logger.warn('w');
    logger.error('e');
    const calls = (console.log as any).mock.calls.map((c: any[]) => JSON.parse(c[0]));
    expect(calls[0].level).toBe('debug');
    expect(calls[1].level).toBe('info');
    expect(calls[2].level).toBe('warn');
    expect(calls[3].level).toBe('error');
  });
});

describe('_scrubPiiForTests', () => {
  it('scrubs nested objects', () => {
    const result = _scrubPiiForTests({
      user: { email: 'a@b.com', name: 'Alice' },
      message: 'contact alice@example.com',
    }) as Record<string, unknown>;
    expect((result.user as any).email).toBe('[redacted]');
    expect(result.message).toBe('contact [email]');
  });
});