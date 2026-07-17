import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';

// Supabase chainable mock
type Row = Record<string, unknown>;
interface MockChain {
  select: ReturnType<typeof vi.fn>;
  eq: ReturnType<typeof vi.fn>;
  maybeSingle: ReturnType<typeof vi.fn>;
  single: ReturnType<typeof vi.fn>;
}
function buildChain(finalData: Row | null, finalError: unknown = null): MockChain {
  const chain = {} as MockChain;
  chain.select = vi.fn(() => chain);
  chain.eq = vi.fn(() => chain);
  chain.maybeSingle = vi.fn(async () => ({ data: finalData, error: finalError }));
  chain.single = vi.fn(async () => ({ data: finalData, error: finalError }));
  return chain;
}

const supabaseMock = {
  from: vi.fn(),
};
vi.mock('../services/supabase', () => ({
  getSupabase: () => supabaseMock,
}));

// Mock the email service — use vi.hoisted so the mock factory can reference it
const { mockSendReportEmail } = vi.hoisted(() => ({ mockSendReportEmail: vi.fn() }));
vi.mock('../services/email', () => ({
  sendReportEmail: mockSendReportEmail,
  EmailError: class EmailError extends Error {
    code: string;
    constructor(code: string, message: string) {
      super(message);
      this.code = code;
    }
  },
}));

// Mock the other services so the teacher route module loads cleanly.
vi.mock('../services/classroom', () => ({
  createClassroom: vi.fn(),
  getClassroomsByTeacher: vi.fn(),
  getClassroomDetail: vi.fn(),
  addStudentsToClassroom: vi.fn(),
}));
vi.mock('../services/reports', () => ({
  generateStudentReport: vi.fn(),
  generateClassroomReport: vi.fn(),
  generateBatchStudentReports: vi.fn(),
  getTeacherEffectiveness: vi.fn(),
}));
vi.mock('../services/pdf', () => ({
  generateStudentReportHtml: vi.fn(),
  generateClassroomReportHtml: vi.fn(),
}));
vi.mock('../services/syllabus', () => ({
  createSyllabus: vi.fn(),
  listSyllabi: vi.fn(),
  getSyllabus: vi.fn(),
  listSyllabusItems: vi.fn(),
  batchSaveSyllabusItems: vi.fn(),
  addSyllabusItem: vi.fn(),
  deleteSyllabusItem: vi.fn(),
  deleteSyllabus: vi.fn(),
  togglePublishSyllabus: vi.fn(),
}));
vi.mock('../services/pricing', () => ({ getPricingForRole: vi.fn() }));
vi.mock('../middleware/cache', () => ({
  cache: () => {
    return async (_c: unknown, next: () => Promise<void>) => {
      await next();
    };
  },
}));

// Stub auth middleware to inject a fake user.
const fakeUser = {
  id: 'teacher-1',
  email: 'teacher@example.com',
  display_name: 'Mrs. Ari',
  role: 'teacher',
  avatar_url: null,
  telegram_id: null,
  target_exam: null,
  target_score: null,
  current_level: null,
  teacher_institution: null,
  created_at: '2024-01-01T00:00:00Z',
  updated_at: '2024-01-01T00:00:00Z',
};
vi.mock('../middleware/auth', () => ({
  requireAuth: () => async (c: { set: (k: string, v: unknown) => void }, next: () => Promise<void>) => {
    c.set('user', fakeUser);
    await next();
  },
  getAuthedUser: (c: { get: (k: string) => unknown }) => c.get('user') as typeof fakeUser,
}));

import { teacherRoutes } from './teacher';

function makeEnv(): Env {
  return {
    SUPABASE_URL: 'https://test.supabase.co',
    SUPABASE_ANON_KEY: 'anon',
    SUPABASE_SERVICE_KEY: 'service',
    JWT_SECRET: 'test-secret-xxxxxxxxxxxx',
    JWT_EXPIRY: '1h',
    OPENAI_API_KEY: 'sk-test',
    EDUBOT_API_URL: '',
    EDUBOT_INTERNAL_SECRET: '',
    WEBHOOK_SECRET_IBT: '', WEBHOOK_SECRET_ITP: '', WEBHOOK_SECRET_IELTS: '',
    WEBHOOK_SECRET_TOEIC: '', WEBHOOK_SECRET_BOOKING: '', WEBHOOK_SECRET_EDUBOT: '',
    WEBAPP_URL: 'http://localhost:8787',
    R2_VIDEOS: {} as never, R2_AUDIO: {} as never,
    TRIPAY_API_KEY: '', TRIPAY_PRIVATE_KEY: '', TRIPAY_MERCHANT_CODE: '',
    TELEGRAM_BOT_TOKEN: '', TELEGRAM_CHANNEL_ID: '',
    OSEE_BOOKING_API_URL: '', OSEE_BOOKING_API_SECRET: '',
    RESEND_API_KEY: 'test-resend',
    ENVIRONMENT: 'development',
  } as Env;
}

function makeApp(): Hono<{ Bindings: Env; Variables: ContextVars }> {
  const app = new Hono<{ Bindings: Env; Variables: ContextVars }>();
  app.route('/api/teacher', teacherRoutes);
  return app;
}

interface JsonBody {
  success?: boolean;
  message?: string;
  recipient?: string;
  message_id?: string;
  error?: { code: string; message: string };
}
async function bodyJson(res: Response): Promise<JsonBody> {
  return (await res.json()) as JsonBody;
}

describe('teacher routes — POST /students/:id/report/email', () => {
  let app: Hono<{ Bindings: Env; Variables: ContextVars }>;
  let env: Env;

  beforeEach(() => {
    vi.clearAllMocks();
    supabaseMock.from.mockReset();
    mockSendReportEmail.mockReset();
    app = makeApp();
    env = makeEnv();
  });

  it('emails the report to the student email on file (happy path)', async () => {
    supabaseMock.from.mockImplementation(() =>
      buildChain({
        id: 'student-1',
        display_name: 'Budi Santoso',
        email: 'budi@example.com',
        role: 'student',
      })
    );
    mockSendReportEmail.mockResolvedValueOnce({ id: 'msg-xyz' });

    const res = await app.request(
      '/api/teacher/students/student-1/report/email',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      },
      env
    );

    expect(res.status).toBe(200);
    const body = await bodyJson(res);
    expect(body.success).toBe(true);
    expect(body.recipient).toBe('budi@example.com');
    expect(body.message_id).toBe('msg-xyz');
    expect(mockSendReportEmail).toHaveBeenCalledOnce();
    const arg = mockSendReportEmail.mock.calls[0][1];
    expect(arg.to).toBe('budi@example.com');
    expect(arg.studentName).toBe('Budi Santoso');
    expect(arg.teacherName).toBe('Mrs. Ari');
    expect(arg.reportUrl).toContain('/api/teacher/students/student-1/report/html');
  });

  it('uses the body-provided email override when supplied', async () => {
    supabaseMock.from.mockImplementation(() =>
      buildChain({
        id: 'student-1',
        display_name: 'Sari',
        email: 'sari@example.com',
        role: 'student',
      })
    );
    mockSendReportEmail.mockResolvedValueOnce({ id: 'msg-2' });

    const res = await app.request(
      '/api/teacher/students/student-1/report/email',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: 'parent@example.com' }),
      },
      env
    );

    expect(res.status).toBe(200);
    const body = await bodyJson(res);
    expect(body.recipient).toBe('parent@example.com');
    expect(mockSendReportEmail.mock.calls[0][1].to).toBe('parent@example.com');
  });

  it('returns 404 when the student is not found', async () => {
    supabaseMock.from.mockImplementation(() => buildChain(null));

    const res = await app.request(
      '/api/teacher/students/missing/report/email',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      },
      env
    );

    expect(res.status).toBe(404);
    const body = await bodyJson(res);
    expect(body.error?.code).toBe('NOT_FOUND');
    expect(mockSendReportEmail).not.toHaveBeenCalled();
  });

  it('returns 400 when the student has no email and none is provided', async () => {
    supabaseMock.from.mockImplementation(() =>
      buildChain({ id: 's', display_name: 'No Email', email: '', role: 'student' })
    );

    const res = await app.request(
      '/api/teacher/students/s/report/email',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      },
      env
    );

    expect(res.status).toBe(400);
    const body = await bodyJson(res);
    expect(body.error?.code).toBe('RECIPIENT_EMAIL_REQUIRED');
  });

  it('returns 502 when email send fails', async () => {
    supabaseMock.from.mockImplementation(() =>
      buildChain({ id: 's', display_name: 'X', email: 'x@example.com', role: 'student' })
    );
    const { EmailError } = await import('../services/email');
    mockSendReportEmail.mockRejectedValueOnce(new EmailError('EMAIL_SEND_FAILED', 'Resend 500'));

    const res = await app.request(
      '/api/teacher/students/s/report/email',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      },
      env
    );

    expect(res.status).toBe(502);
    const body = await bodyJson(res);
    expect(body.error?.code).toBe('EMAIL_SEND_FAILED');
  });

  it('returns 400 on invalid JSON body', async () => {
    supabaseMock.from.mockImplementation(() => buildChain(null));

    const res = await app.request(
      '/api/teacher/students/s/report/email',
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: 'not-json',
      },
      env
    );

    expect(res.status).toBe(400);
    const body = await bodyJson(res);
    expect(body.error?.code).toBe('BAD_REQUEST');
  });
});