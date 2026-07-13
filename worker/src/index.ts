import { Hono } from 'hono';
import { logger } from 'hono/logger';
import { cors } from './middleware/cors';
import { authRoutes } from './routes/auth';
import { webhookRoutes } from './routes/webhook';
import { teacherRoutes } from './routes/teacher';
import { studentRoutes } from './routes/student';
import { aiRoutes } from './routes/ai';
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
import { platformRoutes } from './routes/platform';
import { brandingRoutes } from './routes/branding';
import type { Env, ContextVars } from './types';
import { getPricingForRole } from './services/pricing';
import { optionalAuth } from './middleware/auth';
import { requireAuth } from './middleware/auth';

const app = new Hono<{ Bindings: Env; Variables: ContextVars }>();

// Middleware
app.use('*', logger());
app.use('*', cors());

// Health check
app.get('/api/health', (c) => {
  return c.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Public pricing endpoint (no auth required, falls back to student role)
app.get('/api/pricing', optionalAuth(), async (c) => {
  const user = c.get('user');
  const role = user?.role ?? 'student';
  const pricing = await getPricingForRole(c.env, role as never);
  return c.json({ pricing, role });
});

// Routes
app.route('/api/auth', authRoutes);
app.route('/api/webhook', webhookRoutes);
app.route('/api/teacher', teacherRoutes);
app.route('/api/teacher/commission', commissionRoutes);
app.route('/api/student', studentRoutes);
app.route('/api/ai', aiRoutes);
app.route('/api/upload', uploadRoutes);
app.route('/api/orders', orderRoutes);
app.route('/api/vouchers', voucherRoutes);
app.route('/api/partner', partnerRoutes);
app.route('/api/videos', videoRoutes);
app.route('/api/classes', classRoutes);
app.route('/api/external', externalRoutes);
app.route('/api/ambassador', ambassadorRoutes);
app.route('/api/admin', adminRoutes);
app.route('/api/platform', platformRoutes);
app.route('/api/branding', brandingRoutes);

// Blueprint alias endpoints (path compatibility — same handler, different path)
// These mirror the blueprint Section 5 exact paths for client compatibility.

// /api/teacher/earnings → commission dashboard
app.get('/api/teacher/earnings', requireAuth(), async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: { code: 'UNAUTHORIZED' } }, 401);
  const { getCommissionStats } = await import('./services/commission-dashboard');
  return c.json(await getCommissionStats(c.env, user.id));
});

// /api/teacher/ai-quota → AI quota
app.get('/api/teacher/ai-quota', requireAuth(), async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: { code: 'UNAUTHORIZED' } }, 401);
  const { getQuotaStatus } = await import('./services/quota');
  const grading = await getQuotaStatus(c.env, user.id, user.role, 'grading');
  const generation = await getQuotaStatus(c.env, user.id, user.role, 'generation');
  return c.json({ grading, generation });
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

// Error handler
app.onError((err, c) => {
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

// ---------- Cron scheduled handler ----------
//
// Triggered by Cloudflare Workers Cron Triggers (wrangler.toml [triggers] crons).
// Runs every minute to:
//   1. Process pending webhook events (webhook_events.processed = false)
//   2. Send reminders for classes starting within the next hour
//
// Uses a shared secret from EDUBOT_INTERNAL_SECRET to prevent abuse if the
// cron payload is replayed — Cloudflare guarantees only Workers infra can
// trigger `scheduled`, so this is defence-in-depth.
import { processWebhookBatch } from './services/webhook-processor';
import { sendUpcomingClassReminders } from './services/live-class';

const scheduledHandler: ExportedHandlerScheduledHandler<Env> = async (_event, env, ctx) => {
  // 1. Process webhook events in FIFO batches
  ctx.waitUntil(
    processWebhookBatch(env, 50)
      .then((result) => {
        console.log(`[cron] webhook batch: ${result.succeeded}/${result.total} succeeded`);
      })
      .catch((err) => {
        console.error('[cron] webhook processing failed:', err);
      })
  );

  // 2. Send class reminders for classes starting within the next 60 minutes
  ctx.waitUntil(
    sendUpcomingClassReminders(env)
      .then((result) => {
        console.log(`[cron] class reminders sent: ${result.reminders_sent}`);
      })
      .catch((err) => {
        console.error('[cron] class reminder failed:', err);
      })
  );
};

export default {
  fetch: app.fetch,
  scheduled: scheduledHandler,
} satisfies ExportedHandler<Env>;
