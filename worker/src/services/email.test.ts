import { describe, it, expect, vi, beforeEach } from 'vitest';

const mockFetch = vi.fn();
vi.stubGlobal('fetch', mockFetch);

import { sendEmail, sendReportEmail, sendTeacherInvitation, EmailError } from './email';
import type { Env } from '../types';

const mockEnv = {
  RESEND_API_KEY: 'test-resend-key',
  MAIL_FROM: 'OSEE Test <test@osee.co.id>',
} as unknown as Env;

const mockEnvNoKey = {
  RESEND_API_KEY: '',
} as unknown as Env;

const mockEnvNoMailFrom = {
  RESEND_API_KEY: 'test-resend-key',
} as unknown as Env;

describe('email service', () => {
  beforeEach(() => {
    mockFetch.mockReset();
  });

  describe('sendEmail', () => {
    it('sends an email and returns the message id (happy path)', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'msg-abc-123' }),
      } as Response);

      const result = await sendEmail(mockEnv, {
        to: 'student@example.com',
        subject: 'Test report',
        html: '<p>Hello</p>',
      });

      expect(result.id).toBe('msg-abc-123');
      expect(mockFetch).toHaveBeenCalledOnce();
      const call = mockFetch.mock.calls[0];
      expect(call[0]).toBe('https://api.resend.com/emails');
      const opts = call[1] as RequestInit;
      expect(opts.method).toBe('POST');
      const headers = opts.headers as Record<string, string>;
      expect(headers.Authorization).toBe('Bearer test-resend-key');
      expect(headers['Content-Type']).toBe('application/json');
      const body = JSON.parse(opts.body as string);
      expect(body.from).toBe('OSEE Test <test@osee.co.id>');
      expect(body.to).toBe('student@example.com');
      expect(body.subject).toBe('Test report');
      expect(body.html).toBe('<p>Hello</p>');
    });

    it('falls back to default from address when MAIL_FROM is unset', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'msg-1' }),
      } as Response);

      await sendEmail(mockEnvNoMailFrom, {
        to: 'x@example.com',
        subject: 's',
        html: '<p>h</p>',
      });

      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.from).toBe('OSEE Prep Hub <noreply@osee.co.id>');
    });

    it('uses explicit from override over env default', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'msg-2' }),
      } as Response);

      await sendEmail(mockEnv, {
        to: 'x@example.com',
        subject: 's',
        html: '<p>h</p>',
        from: 'Custom <custom@osee.co.id>',
      });

      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.from).toBe('Custom <custom@osee.co.id>');
    });

    it('throws EMAIL_NOT_CONFIGURED when RESEND_API_KEY is missing', async () => {
      await expect(
        sendEmail(mockEnvNoKey, { to: 'x@example.com', subject: 's', html: '<p>h</p>' })
      ).rejects.toThrow(/RESEND_API_KEY/);
      expect(mockFetch).not.toHaveBeenCalled();
    });

    it('throws INVALID_RECIPIENT on missing or malformed email', async () => {
      await expect(
        sendEmail(mockEnv, { to: '', subject: 's', html: '<p>h</p>' })
      ).rejects.toThrow(/recipient/i);
      await expect(
        sendEmail(mockEnv, { to: 'not-an-email', subject: 's', html: '<p>h</p>' })
      ).rejects.toThrow(/recipient/i);
    });

    it('throws INVALID_SUBJECT on empty subject', async () => {
      await expect(
        sendEmail(mockEnv, { to: 'x@example.com', subject: '  ', html: '<p>h</p>' })
      ).rejects.toThrow(/subject/i);
    });

    it('throws INVALID_BODY on empty html', async () => {
      await expect(
        sendEmail(mockEnv, { to: 'x@example.com', subject: 's', html: '' })
      ).rejects.toThrow(/body/i);
    });

    it('throws EMAIL_SEND_FAILED on Resend 4xx/5xx response', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 422,
        text: async () => 'validation_error: invalid recipient',
      } as Response);

      await expect(
        sendEmail(mockEnv, { to: 'x@example.com', subject: 's', html: '<p>h</p>' })
      ).rejects.toThrow(/Resend API error 422/);
    });

    it('throws EMAIL_SEND_FAILED when response has no id', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({}),
      } as Response);

      await expect(
        sendEmail(mockEnv, { to: 'x@example.com', subject: 's', html: '<p>h</p>' })
      ).rejects.toThrow(/no message id/);
    });

    it('propagates network errors as EmailError', async () => {
      mockFetch.mockRejectedValueOnce(new TypeError('fetch failed'));
      await expect(
        sendEmail(mockEnv, { to: 'x@example.com', subject: 's', html: '<p>h</p>' })
      ).rejects.toThrow(/fetch failed/);
    });
  });

  describe('sendReportEmail', () => {
    it('renders student name + report URL into the HTML and sends', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'rep-1' }),
      } as Response);

      const result = await sendReportEmail(mockEnv, {
        to: 'parent@example.com',
        studentName: 'Budi Santoso',
        reportUrl: 'https://prep.osee.co.id/report/abc',
        teacherName: 'Mrs. Ari',
      });

      expect(result.id).toBe('rep-1');
      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.to).toBe('parent@example.com');
      expect(body.subject).toContain('Budi Santoso');
      expect(body.html).toContain('Budi Santoso');
      expect(body.html).toContain('Mrs. Ari');
      expect(body.html).toContain('https://prep.osee.co.id/report/abc');
      expect(body.html).toContain('View my progress report');
    });

    it('omits the teacher line when teacherName is not provided', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'rep-2' }),
      } as Response);

      await sendReportEmail(mockEnv, {
        to: 's@example.com',
        studentName: 'Sari',
        reportUrl: 'https://prep.osee.co.id/report/xyz',
      });

      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.html).not.toContain('Your teacher,');
      expect(body.html).toContain('has prepared a progress report');
    });

    it('escapes HTML special characters in user input', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'rep-3' }),
      } as Response);

      await sendReportEmail(mockEnv, {
        to: 's@example.com',
        studentName: '<script>alert(1)</script>',
        reportUrl: 'https://prep.osee.co.id/r',
      });

      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.html).not.toContain('<script>alert(1)</script>');
      expect(body.html).toContain('&lt;script&gt;alert(1)&lt;/script&gt;');
    });
  });

  describe('sendTeacherInvitation', () => {
    it('renders institution name + invite URL and sends', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'inv-1' }),
      } as Response);

      const result = await sendTeacherInvitation(mockEnv, {
        to: 'newteacher@example.com',
        institutionName: 'SMA Negeri 1 Jakarta',
        inviteUrl: 'https://prep.osee.co.id/register?invite=token123',
        partnerName: 'Pak Budi',
      });

      expect(result.id).toBe('inv-1');
      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.to).toBe('newteacher@example.com');
      expect(body.subject).toContain('SMA Negeri 1 Jakarta');
      expect(body.html).toContain('SMA Negeri 1 Jakarta');
      expect(body.html).toContain('Pak Budi');
      expect(body.html).toContain('register?invite=token123');
      expect(body.html).toContain('Accept invitation');
      expect(body.html).toContain('expires in 7 days');
    });

    it('omits partner name when not provided', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'inv-2' }),
      } as Response);

      await sendTeacherInvitation(mockEnv, {
        to: 't@example.com',
        institutionName: 'SMA 2',
        inviteUrl: 'https://prep.osee.co.id/register?invite=t',
      });

      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.html).toContain('SMA 2');
      expect(body.html).not.toContain('from <strong>Pak');
    });

    it('escapes user input in invitation', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({ id: 'inv-3' }),
      } as Response);

      await sendTeacherInvitation(mockEnv, {
        to: 't@example.com',
        institutionName: 'SMA <img src=x>',
        inviteUrl: 'https://prep.osee.co.id/register?invite=t',
      });

      const body = JSON.parse((mockFetch.mock.calls[0][1] as RequestInit).body as string);
      expect(body.html).not.toContain('<img src=x>');
      expect(body.html).toContain('&lt;img src=x&gt;');
    });
  });

  it('EmailError carries a stable code', () => {
    const err = new EmailError('EMAIL_SEND_FAILED', 'boom');
    expect(err.code).toBe('EMAIL_SEND_FAILED');
    expect(err.message).toBe('boom');
    expect(err.name).toBe('EmailError');
    expect(err).toBeInstanceOf(Error);
  });
});