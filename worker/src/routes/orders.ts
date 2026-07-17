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
import { createPayment, verifyWebhookSignature } from '../services/tripay';

export const orderRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

/** TriPay webhook — registered BEFORE requireAuth so it can be called without auth. */
orderRoutes.post('/webhook/tripay', async (c) => {
  let body: {
    merchant_ref?: string;
    reference?: string;
    status?: string;
    amount?: number;
    signature?: string;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.merchant_ref) {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'merchant_ref required' } }, 400);
  }

  // Verify signature (TriPay sends a signature over merchant_ref + status + amount + private_key)
  if (body.signature && body.status && typeof body.amount === 'number') {
    const valid = verifyWebhookSignature(
      c.env,
      body.merchant_ref,
      body.status,
      body.amount,
      body.signature
    );
    if (!valid) {
      return c.json({ error: { code: 'INVALID_SIGNATURE', message: 'Invalid TriPay signature' } }, 401);
    }
  }

  if (body.status === 'PAID' || body.status === 'paid') {
    try {
      // Extract order_id from merchant_ref (format: OSEE-{order_id})
      const orderId = body.merchant_ref.replace(/^OSEE-/, '').split('-')[0];
      if (!orderId) {
        return c.json({ error: { code: 'INVALID_REF', message: 'Cannot extract order_id' } }, 400);
      }
      await markOrderPaid(c.env, orderId, 'tripay', body.reference ?? body.merchant_ref);
      return c.json({ success: true, order_id: orderId });
    } catch (err) {
      return c.json({ error: { code: 'FULFILL_FAILED', message: (err as Error).message } }, 500);
    }
  }
  return c.json({ success: true, status: body.status });
});

// All other order routes require authentication
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

/** POST /api/orders/:id/pay — initiate payment via TriPay */
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
    const order = await getOrder(c.env, user.id, orderId);
    if (!order) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Order not found' } }, 404);
    }
    const o = order as Record<string, unknown>;
    const amount = Number(o.total_amount ?? 0);
    if (amount <= 0) {
      return c.json({ error: { code: 'INVALID_AMOUNT', message: 'Order amount must be > 0' } }, 400);
    }

    // Build TriPay payment request
    const merchantRef = `OSEE-${orderId}`;
    const payment = await createPayment(c.env, {
      payment_method: body.payment_method,
      merchant_ref: merchantRef,
      amount,
      customer_name: user.display_name,
      customer_email: user.email,
      order_items: [
        {
          name: `OSEE Order ${orderId}`,
          price: amount,
          quantity: 1,
        },
      ],
      return_url: `${c.env.WEBAPP_URL ?? ''}/teacher/orders`,
    });

    return c.json({
      payment_ref: payment.reference,
      redirect_url: payment.payment_url,
      pay_code: payment.pay_code,
      amount: payment.amount,
      fee: payment.fee,
      expired_time: payment.expired_time,
    });
  } catch (err) {
    return c.json({ error: { code: 'PAYMENT_FAILED', message: (err as Error).message } }, 500);
  }
});