import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { validateVoucher, redeemVoucher } from '../services/voucher';

export const voucherRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

voucherRoutes.use('*', requireAuth());

/** POST /api/vouchers/redeem — redeem a voucher code */
voucherRoutes.post('/redeem', async (c) => {
  const user = getAuthedUser(c);
  let body: { code?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.code?.trim()) {
    return c.json({ error: { code: 'INVALID_CODE', message: 'code required' } }, 400);
  }
  try {
    const result = await redeemVoucher(c.env, body.code.trim().toUpperCase(), user.id);
    return c.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Redeem failed';
    return c.json({ error: { code: 'REDEEM_FAILED', message } }, 400);
  }
});

/** GET /api/vouchers/:code/validate — validate voucher without redeeming */
voucherRoutes.get('/:code/validate', async (c) => {
  const code = c.req.param('code');
  try {
    const result = await validateVoucher(c.env, code);
    return c.json(result);
  } catch (err) {
    return c.json({ error: { code: 'VALIDATE_FAILED', message: (err as Error).message } }, 500);
  }
});