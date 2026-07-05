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
app.route('/api/student', studentRoutes);
app.route('/api/ai', aiRoutes);
app.route('/api/upload', uploadRoutes);
app.route('/api/orders', orderRoutes);
app.route('/api/vouchers', voucherRoutes);
app.route('/api/partner', partnerRoutes);

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

export default app;