import type { Env } from '../types';

/**
 * Email service — sends transactional email via the Resend HTTP API.
 *
 * Resend is used (over MailChannels) because MailChannels' free tier for
 * Cloudflare Workers ended in June 2024; Resend offers a clean HTTP API with
 * a 3000-emails/month free tier and an `onboarding@resend.dev` sandbox sender
 * for development without DNS verification.
 *
 * Production requires verifying the `osee.co.id` domain in the Resend
 * dashboard (SPF/DKIM) and setting MAIL_FROM to an address on that domain.
 */

const RESEND_API_URL = 'https://api.resend.com/emails';
const DEFAULT_FROM = 'OSEE Prep Hub <noreply@osee.co.id>';

/** Typed email error with a stable code for API responses. */
export class EmailError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.name = 'EmailError';
    this.code = code;
  }
}

export interface SendEmailInput {
  to: string;
  subject: string;
  html: string;
  from?: string;
}

export interface SendEmailResult {
  id: string;
}

function resolveFrom(env: Env, from?: string): string {
  return from ?? env.MAIL_FROM ?? DEFAULT_FROM;
}

/** Send a single email via Resend. Throws EmailError on failure. */
export async function sendEmail(env: Env, input: SendEmailInput): Promise<SendEmailResult> {
  if (!env.RESEND_API_KEY) {
    throw new EmailError('EMAIL_NOT_CONFIGURED', 'RESEND_API_KEY is not set');
  }
  if (!input.to || !input.to.includes('@')) {
    throw new EmailError('INVALID_RECIPIENT', 'A valid recipient email is required');
  }
  if (!input.subject || !input.subject.trim()) {
    throw new EmailError('INVALID_SUBJECT', 'A subject is required');
  }
  if (!input.html || !input.html.trim()) {
    throw new EmailError('INVALID_BODY', 'An HTML body is required');
  }

  const response = await fetch(RESEND_API_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: resolveFrom(env, input.from),
      to: input.to,
      subject: input.subject,
      html: input.html,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new EmailError(
      'EMAIL_SEND_FAILED',
      `Resend API error ${response.status}: ${text.slice(0, 500)}`
    );
  }

  const json = (await response.json()) as { id?: string };
  if (!json.id) {
    throw new EmailError('EMAIL_SEND_FAILED', 'Resend API returned no message id');
  }
  return { id: json.id };
}

/** Build and send a student report email. */
export async function sendReportEmail(
  env: Env,
  params: { to: string; studentName: string; reportUrl: string; teacherName?: string }
): Promise<SendEmailResult> {
  const teacherLine = params.teacherName
    ? `<p>Your teacher, <strong>${escapeHtml(params.teacherName)}</strong>, has prepared a progress report for you.</p>`
    : '<p>Your teacher has prepared a progress report for you.</p>';

  const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>Your OSEE Progress Report</title></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background:#f6f7f9; margin:0; padding:32px 0;">
  <div style="max-width:560px; margin:0 auto; background:#ffffff; border-radius:16px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.08);">
    <div style="background:#0a0a0a; padding:24px 32px;">
      <h1 style="color:#ffffff; font-size:20px; margin:0; letter-spacing:0.02em;">OSEE Prep Hub</h1>
      <p style="color:#9ca3af; font-size:13px; margin:4px 0 0;">AI Teaching Assistant — Progress Report</p>
    </div>
    <div style="padding:32px;">
      <p style="font-size:16px; color:#111827; margin:0 0 16px;">Hi ${escapeHtml(params.studentName)},</p>
      ${teacherLine}
      <p style="font-size:15px; color:#374151; margin:0 0 24px;">You can view your full progress report, including scores across practice platforms, readiness assessment, and teacher recommendations, at the link below.</p>
      <a href="${escapeAttr(params.reportUrl)}" style="display:inline-block; background:#CCFF00; color:#0a0a0a; font-weight:600; font-size:15px; padding:12px 24px; border-radius:10px; text-decoration:none;">View my progress report</a>
      <p style="font-size:13px; color:#6b7280; margin:24px 0 0;">If the button above doesn't work, copy and paste this link into your browser:<br><span style="color:#4f46e5; word-break:break-all;">${escapeHtml(params.reportUrl)}</span></p>
    </div>
    <div style="padding:16px 32px; background:#f9fafb; border-top:1px solid #f3f4f6;">
      <p style="font-size:12px; color:#9ca3af; margin:0;">OSEE Prep Hub — prep.osee.co.id — ETS-certified English test preparation.</p>
    </div>
  </div>
</body>
</html>`;

  return sendEmail(env, {
    to: params.to,
    subject: `Your OSEE Progress Report is ready, ${params.studentName}`,
    html,
  });
}

/** Build and send a partner-teacher invitation email. */
export async function sendTeacherInvitation(
  env: Env,
  params: { to: string; institutionName: string; inviteUrl: string; partnerName?: string }
): Promise<SendEmailResult> {
  const partnerLine = params.partnerName
    ? `<p><strong>${escapeHtml(params.partnerName)}</strong> from <strong>${escapeHtml(params.institutionName)}</strong> has invited you to join the OSEE Prep Hub as a teacher.`
    : `<p><strong>${escapeHtml(params.institutionName)}</strong> has invited you to join the OSEE Prep Hub as a teacher.`;

  const html = `<!DOCTYPE html>
<html lang="en">
<head><meta charset="utf-8"><title>You're invited to OSEE Prep Hub</title></head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background:#f6f7f9; margin:0; padding:32px 0;">
  <div style="max-width:560px; margin:0 auto; background:#ffffff; border-radius:16px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.08);">
    <div style="background:#0a0a0a; padding:24px 32px;">
      <h1 style="color:#ffffff; font-size:20px; margin:0; letter-spacing:0.02em;">OSEE Prep Hub</h1>
      <p style="color:#9ca3af; font-size:13px; margin:4px 0 0;">Teacher Invitation</p>
    </div>
    <div style="padding:32px;">
      <p style="font-size:16px; color:#111827; margin:0 0 16px;">Hello,</p>
      ${partnerLine}</p>
      <p style="font-size:15px; color:#374151; margin:0 0 24px;">OSEE Prep Hub gives English teachers free AI tools — a writing grader, material generator, classroom reports — and lets you earn commission on student actions. Complete the invitation by registering your account below.</p>
      <a href="${escapeAttr(params.inviteUrl)}" style="display:inline-block; background:#CCFF00; color:#0a0a0a; font-weight:600; font-size:15px; padding:12px 24px; border-radius:10px; text-decoration:none;">Accept invitation & register</a>
      <p style="font-size:13px; color:#6b7280; margin:24px 0 0;">This invitation link expires in 7 days. If the button above doesn't work, copy and paste this link into your browser:<br><span style="color:#4f46e5; word-break:break-all;">${escapeHtml(params.inviteUrl)}</span></p>
    </div>
    <div style="padding:16px 32px; background:#f9fafb; border-top:1px solid #f3f4f6;">
      <p style="font-size:12px; color:#9ca3af; margin:0;">OSEE Prep Hub — prep.osee.co.id — ETS-certified English test preparation. If you weren't expecting this invitation, you can safely ignore this email.</p>
    </div>
  </div>
</body>
</html>`;

  return sendEmail(env, {
    to: params.to,
    subject: `${params.institutionName} invited you to OSEE Prep Hub`,
    html,
  });
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function escapeAttr(s: string): string {
  return escapeHtml(s);
}