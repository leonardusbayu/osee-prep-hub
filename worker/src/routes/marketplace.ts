/**
 * Marketplace routes — T14 (Wave 2).
 *
 * GET    /api/marketplace/listings           — list published listings (public, optional auth for personalization)
 * POST   /api/marketplace/listings           — seller creates listing
 * GET    /api/marketplace/listings/:id       — single listing
 * POST   /api/marketplace/purchases          — buyer initiates purchase (escrow pending)
 * GET    /api/marketplace/purchases/me       — list my purchases (bought)
 * POST   /api/marketplace/reviews            — buyer submits review
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser, optionalAuth } from '../middleware/auth';
import {
  createListing,
  listListings,
  initiatePurchase,
  listUserPurchases,
  submitReview,
  getPurchase,
  type Listing,
} from '../services/marketplace';
import { getSupabase } from '../services/supabase';

export const marketplaceRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

/** GET /api/marketplace/listings — public. */
marketplaceRoutes.get('/listings', optionalAuth(), async (c) => {
  const exam = c.req.query('exam');
  const level = c.req.query('level');
  try {
    const listings = await listListings(c.env, { exam, level, limit: 100 });
    return c.json({ listings });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'List failed';
    return c.json({ error: { code: 'LIST_FAILED', message } }, 500);
  }
});

/** POST /api/marketplace/listings — auth required (teacher/admin/partner). */
marketplaceRoutes.post('/listings', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  if (!['teacher', 'admin', 'partner'].includes(user.role)) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teachers/partners/admins only' } }, 403);
  }
  let body: Partial<Listing>;
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  try {
    const listing = await createListing(c.env, user.id, body as {
      title: string;
      description: string;
      listing_type: Listing['listing_type'];
      exam: Listing['exam'];
      level: Listing['level'];
      price_idr: number;
      preview_url?: string;
      syllabus_id?: string;
    });
    return c.json({ listing }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Create failed';
    return c.json({ error: { code: 'CREATE_FAILED', message } }, 400);
  }
});

/** GET /api/marketplace/listings/:id */
marketplaceRoutes.get('/listings/:id', async (c) => {
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  const supabase = getSupabase(c.env);
  const { data: listing, error } = await supabase
    .from('marketplace_listings')
    .select('*, unified_profiles!marketplace_listings_seller_id_fkey(display_name, avatar_url)')
    .eq('id', id)
    .single();
  if (error || !listing) return c.json({ error: { code: 'NOT_FOUND', message: 'Listing not found' } }, 404);
  // Increment view count.
  await supabase
    .from('marketplace_listings')
    .update({ view_count: (listing.view_count ?? 0) + 1 })
    .eq('id', id);
  return c.json({ listing });
});

/** POST /api/marketplace/purchases — initiate purchase (escrow pending). */
marketplaceRoutes.post('/purchases', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  let body: { listingId?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.listingId) return c.json({ error: { code: 'INVALID_INPUT', message: 'listingId required' } }, 400);
  try {
    const purchase = await initiatePurchase(c.env, user.id, body.listingId);
    return c.json({ purchase }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Purchase failed';
    const code = message === 'seller_cannot_buy' ? 'SELLER_CANNOT_BUY'
      : message === 'already_purchased' ? 'ALREADY_PURCHASED'
      : 'PURCHASE_FAILED';
    return c.json({ error: { code, message } }, 400);
  }
});

/** GET /api/marketplace/purchases/me — list my purchases as buyer. */
marketplaceRoutes.get('/purchases/me', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  try {
    const purchases = await listUserPurchases(c.env, user.id, 'buyer');
    return c.json({ purchases });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'List failed';
    return c.json({ error: { code: 'LIST_FAILED', message } }, 500);
  }
});

/** GET /api/marketplace/purchases/sold — list my sales as seller. */
marketplaceRoutes.get('/purchases/sold', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  try {
    const purchases = await listUserPurchases(c.env, user.id, 'seller');
    return c.json({ purchases });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'List failed';
    return c.json({ error: { code: 'LIST_FAILED', message } }, 500);
  }
});

/** GET /api/marketplace/purchases/:id */
marketplaceRoutes.get('/purchases/:id', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);
  const purchase = await getPurchase(c.env, id);
  if (!purchase) return c.json({ error: { code: 'NOT_FOUND', message: 'Purchase not found' } }, 404);
  if (purchase.buyer_id !== user.id && purchase.seller_id !== user.id) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Not your purchase' } }, 403);
  }
  return c.json({ purchase });
});

/** POST /api/marketplace/reviews — buyer submits review. */
marketplaceRoutes.post('/reviews', requireAuth(), async (c) => {
  const user = getAuthedUser(c);
  let body: { purchaseId?: string; stars?: number; comment?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.purchaseId || !body.stars) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'purchaseId, stars required' } }, 400);
  }
  try {
    const review = await submitReview(c.env, user.id, body.purchaseId, body.stars, body.comment);
    return c.json({ review }, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Review failed';
    return c.json({ error: { code: 'REVIEW_FAILED', message } }, 400);
  }
});