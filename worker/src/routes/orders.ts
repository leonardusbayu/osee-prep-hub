import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import {
  createOrder,
  getOrder,
  listOrders,
  cancelOrder,
  markOrderPaid,
} from '../services/orders';

export const orderRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

orderRoutes.use('*', requireAuth());

/** POST /api/orders — create a new order */
orderRoutes.post('/', async (c) => {
  const user = getAuthedUser(c);
  let body: {
    order_type?: string;
    items?: Array<{ item_type: string; quantity: number; assigned_student_id?: string }>;
    notes?: string;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.order_type || !body.items?.length) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'order_type and items required' } }, 400);
  }
  try {
    const order = await createOrder(c.env, user.id, user.role, {
      order_type: body.order_type as never,
      items: body.items as never,
      notes: body.notes,
    });
    return c.json(order, 201);
  } catch (err) {
    return c.json({ error: { code: 'ORDER_FAILED', message: (err as Error).message } }, 400);
  }
});

/** GET /api/orders — list user's orders */
orderRoutes.get('/', async (c) => {
  const user = getAuthedUser(c);
  try {
    const orders = await listOrders(c.env, user.id);
    return c.json({ orders });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/orders/:id — order detail */
orderRoutes.get('/:id', async (c) => {
  const user = getAuthedUser(c);
  const orderId = c.req.param('id');
  try {
    const order = await getOrder(c.env, user.id, orderId);
    if (!order) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Order not found' } }, 404);
    }
    return c.json(order);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/orders/:id/cancel — cancel pending order */
orderRoutes.post('/:id/cancel', async (c) => {
  const user = getAuthedUser(c);
  const orderId = c.req.param('id');
  try {
    await cancelOrder(c.env, user.id, orderId);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'CANCEL_FAILED', message: (err as Error).message } }, 400);
  }
});

/** POST /api/orders/:id/pay — initiate payment (returns TriPay redirect URL) */
orderRoutes.post('/:id/pay', async (c) => {
  const user = getAuthedUser(c);
  const orderId = c.req.param('id');
  let body: { payment_method?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.payment_method) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'payment_method required' } }, 400);
  }
  try {
    // Get order to verify ownership + amount
    const order = await getOrder(c.env, user.id, orderId);
    if (!order) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Order not found' } }, 404);
    }
    // TODO: Bridge to TriPay for real payment. For now, return mock redirect URL.
    const paymentRef = `tripay-${orderId}-${Date.now()}`;
    const redirectUrl = `https://tripay.co.id/checkout?ref=${paymentRef}&amount=${(order as Record<string, unknown>).total_amount}`;
    return c.json({
      payment_ref: paymentRef,
      redirect_url: redirectUrl,
      amount: (order as Record<string, unknown>).total_amount,
    });
  } catch (err) {
    return c.json({ error: { code: 'PAYMENT_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/orders/webhook/tripay — TriPay payment callback (no auth — webhook secret) */
orderRoutes.post('/webhook/tripay', async (c) => {
  let body: { merchant_ref?: string; status?: string; signature?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.merchant_ref) {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'merchant_ref required' } }, 400);
  }
  // TODO: Verify TriPay signature
  // For now, accept and process
  if (body.status === 'paid') {
    try {
      // Extract order_id from merchant_ref (format: tripay-{order_id}-{timestamp})
      const orderId = (body.merchant_ref as string).split('-')[1];
      if (!orderId) {
        return c.json({ error: { code: 'INVALID_REF', message: 'Cannot extract order_id' } }, 400);
      }
      await markOrderPaid(c.env, orderId, 'tripay', body.merchant_ref);
      return c.json({ success: true, order_id: orderId });
    } catch (err) {
      return c.json({ error: { code: 'FULFILL_FAILED', message: (err as Error).message } }, 500);
    }
  }
  return c.json({ success: true, status: body.status });
});