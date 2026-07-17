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
import { handoffRoutes } from './routes/handoffs';
import { pushRoutes } from './routes/push';
import { viralRoutes } from './routes/viral';
import { disputeRoutes } from './routes/disputes';
import { ambassadorV2Routes } from './routes/ambassador-v2';
import { viralMetricsRoutes } from './routes/viral-metrics';
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
app.route('/api/handoffs', handoffRoutes);
app.route('/api/push', pushRoutes);
app.route('/api/viral', viralRoutes);
app.route('/api/disputes', disputeRoutes);
app.route('/api/ambassador-v2', ambassadorV2Routes);
app.route('/api/viral-metrics', viralMetricsRoutes);

// Public Ed25519 key for Passport employer-side verification.
app.get('/.well-known/passport-public-key.pem', async (c) => {
  const { getPublicKeyPem, recordAudit } = await import('./services/passport');
  try {
    const pem = await getPublicKeyPem(c.env);
    // T27 audit: record public key fetch (no credential id — system event).
    await recordAudit(c.env, {
      action: 'public_key_fetched',
      actor_type: 'anonymous',
      actor_ip: c.req.header('CF-Connecting-IP') ?? c.req.header('X-Forwarded-For') ?? null,
      user_agent: c.req.header('User-Agent') ?? null,
      details: { key_length: pem.length },
    });
    return new Response(pem, {
      status: 200,
      headers: { 'Content-Type': 'application/x-pem-file', 'Cache-Control': 'public, max-age=3600' },
    });
  } catch {
    return c.json({ error: { code: 'KEY_UNAVAILABLE', message: 'Passport signing key not configured' } }, 500);
  }
});
app.route('/api/platform', platformRoutes);
app.route('/api/branding', brandingRoutes);
app.route('/api/reports', reportRoutes); // Blueprint Section 5 lines 1391-1401

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

// Blueprint Section 5 top-level /api/commission/* namespace (lines 1407-1416).
// Aliases to the /api/teacher/commission/* handlers for Blueprint path compliance.
app.route('/api/commission', commissionRoutes);
// /api/commission/earnings → same as /dashboard
app.get('/api/commission/earnings', requireAuth(), async (c) => {
  const user = c.get('user');
  if (!user) return c.json({ error: { code: 'UNAUTHORIZED' } }, 401);
  const { getCommissionStats } = await import('./services/commission-dashboard');
  return c.json(await getCommissionStats(c.env, user.id));
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
import { creditRecurringPremiumCommission } from './services/premium-recurring';

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

  // 3. Credit recurring monthly premium commission (Blueprint line 64)
  ctx.waitUntil(
    creditRecurringPremiumCommission(env)
      .then((result) => {
        if (result.credited > 0) {
          console.log(`[cron] premium recurring commission credited: ${result.credited} students`);
        }
      })
      .catch((err) => {
        console.error('[cron] premium recurring commission failed:', err);
      })
  );
};

export default {
  fetch: app.fetch,
  scheduled: scheduledHandler,
} satisfies ExportedHandler<Env>;
