import { Hono } from 'hono';
import { logger } from 'hono/logger';
import * as Sentry from '@sentry/cloudflare';
import { cors } from './middleware/cors';
import { authRoutes } from './routes/auth';
import { webhookRoutes } from './routes/webhook';
import { teacherRoutes } from './routes/teacher';
import { studentRoutes } from './routes/student';
import { aiRoutes } from './routes/ai';
import { boardRoutes } from './routes/boards';
import { materialRoutes } from './routes/materials';
import { reportRoutes } from './routes/reports';
import { uploadRoutes } from './routes/upload';
import { orderRoutes } from './routes/orders';
import { voucherRoutes } from './routes/voucher';
import { partnerRoutes } from './routes/partner';
import { commissionRoutes } from './routes/commission';
import { videoRoutes } from './routes/video';
import { classRoutes } from './routes/classes';
import { externalRoutes } from './routes/external';
import { ambassadorRoutes } from './routes/ambassador';
import { adminRoutes } from './routes/admin';
import { agentRoutes } from './routes/agents';
import { realtimeRoutes } from './routes/realtime';
import { passportRoutes } from './routes/passport';
import { coachRoutes } from './routes/coach';
import { marketplaceRoutes } from './routes/marketplace';
import { insightRoutes } from './routes/insight';
import { studioRoutes } from './routes/studio';
import { liveClassRoutes } from './routes/live-classes';
import type { Env, ContextVars } from './types';

const app = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// Middleware
app.use('*', logger());
app.use('*', cors());

// Health check
app.get('/api/health', (c) => {
  return c.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/webhook', webhookRoutes);
app.route('/api/teacher', teacherRoutes);
app.route('/api/teacher/commission', commissionRoutes);
app.route('/api/student', studentRoutes);
app.route('/api/ai', aiRoutes);
app.route('/api/boards', boardRoutes);
app.route('/api/materials', materialRoutes);
app.route('/api/reports', reportRoutes);
app.route('/api/upload', uploadRoutes);
app.route('/api/orders', orderRoutes);
app.route('/api/vouchers', voucherRoutes);
app.route('/api/partner', partnerRoutes);
app.route('/api/videos', videoRoutes);
app.route('/api/classes', classRoutes);
app.route('/api/external', externalRoutes);
app.route('/api/ambassador', ambassadorRoutes);
app.route('/api/admin', adminRoutes);
app.route('/api/agents', agentRoutes);
app.route('/api/syllabi', realtimeRoutes);
app.route('/api/passport', passportRoutes);
app.route('/api/coach', coachRoutes);
app.route('/api/marketplace', marketplaceRoutes);
app.route('/api/insight', insightRoutes);
app.route('/api/studio', studioRoutes);
app.route('/api/live-classes', liveClassRoutes);

// Public Ed25519 key for Passport employer-side verification.
app.get('/.well-known/passport-public-key.pem', async (c) => {
  const { getPublicKeyPem } = await import('./services/passport');
  try {
    const pem = await getPublicKeyPem(c.env);
    return new Response(pem, {
      status: 200,
      headers: { 'Content-Type': 'application/x-pem-file', 'Cache-Control': 'public, max-age=3600' },
    });
  } catch {
    return c.json({ error: { code: 'KEY_UNAVAILABLE', message: 'Passport signing key not configured' } }, 500);
  }
});

// Root
app.get('/', (c) => {
  return c.json({
    name: 'OSEE Prep Hub API',
    version: '0.1.0',
    docs: '/api/health',
  });
});

// 404 handler
app.notFound((c) => {
  return c.json(
    {
      error: {
        code: 'NOT_FOUND',
        message: `Route ${c.req.method} ${c.req.path} not found`,
      },
    },
    404
  );
});

// Error handler — Task 7: report to Sentry before responding.
app.onError((err, c) => {
  if (c.env.SENTRY_DSN) {
    try { Sentry.captureException(err); } catch { /* best-effort */ }
  }
  console.error('Unhandled error:', err);
  return c.json(
    {
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred',
      },
    },
    500
  );
});

export default app;