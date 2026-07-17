import { Hono } from 'hono';
import type { Env, ContextVars, UserRole } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';
import { setPrice, listAllPricing, deactivatePrice } from '../services/pricing';
import { getSupabase } from '../services/supabase';
import {
  getAdminCommissionSummary,
  getAdminAnalytics,
  listTeachers,
  listStudents,
} from '../services/admin-stats';
import { cache } from '../middleware/cache';

/**
 * Admin routes — blueprint Section 5 (admin endpoints) + Task 18.4.
 *
 * All routes require `admin` role. `requireAuth` + `requireRole('admin')` are
 * registered before any route handler.
 */

const VALID_CATEGORIES = [
  'grammar', 'vocabulary', 'pronunciation', 'rubrics',
  'question_templates', 'error_patterns', 'cultural', 'general',
];
const VALID_CEFR = ['', 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const VALID_COMMISSION_ACTIONS = [
  'first_test', 'official_booking', 'premium_monthly', 'practice_package',
  'ambassador_first_test', 'ambassador_booking', 'ambassador_premium_monthly',
];

export const adminRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

adminRoutes.use('*', requireAuth());
adminRoutes.use('*', requireRole('admin'));

// ---------- Pricing ----------

/** GET /api/admin/pricing — list all pricing entries */
adminRoutes.get('/pricing', async (c) => {
  try {
    const pricing = await listAllPricing(c.env);
    return c.json({ pricing });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/admin/pricing — set/update price */
adminRoutes.post('/pricing', async (c) => {
  let body: { item_type?: string; role?: string; price?: number };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.item_type || !body.role || typeof body.price !== 'number') {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'item_type, role, price required' } }, 400);
  }
  if (body.price < 0) {
    return c.json({ error: { code: 'INVALID_PRICE', message: 'price must be >= 0' } }, 400);
  }
  try {
    await setPrice(c.env, body.item_type as never, body.role as never, body.price);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'SET_FAILED', message: (err as Error).message } }, 500);
  }
});

/** DELETE /api/admin/pricing/:item_type/:role — deactivate a pricing entry (Task 15.5) */
adminRoutes.delete('/pricing/:itemType/:role', async (c) => {
  const itemType = c.req.param('itemType');
  const role = c.req.param('role') as UserRole;
  try {
    const ok = await deactivatePrice(c.env, itemType as never, role);
    if (!ok) {
      return c.json({ error: { code: 'NOT_FOUND', message: 'Pricing entry not found' } }, 404);
    }
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'DELETE_FAILED', message: (err as Error).message } }, 500);
  }
});

// ---------- Stats + Analytics ----------

/** GET /api/admin/stats — quick platform stats (legacy alias) */
adminRoutes.get('/stats', cache({ ttl: 30, varyByUser: false }), async (c) => {
  try {
    const analytics = await getAdminAnalytics(c.env);
    return c.json({
      total_users: analytics.total_teachers + analytics.total_students + analytics.total_partners,
      active_teachers: analytics.total_teachers,
      total_students: analytics.total_students,
      total_revenue: analytics.total_revenue,
      commission_paid: analytics.commission_paid,
      commission_pending: analytics.commission_pending,
      ai_usage: analytics.ai_grading_count + analytics.ai_generation_count,
      total_bookings: analytics.total_bookings,
    });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/analytics — platform-wide analytics (blueprint:1542, Task 18.4) */
adminRoutes.get('/analytics', cache({ ttl: 30, varyByUser: false }), async (c) => {
  try {
    const analytics = await getAdminAnalytics(c.env);
    return c.json(analytics);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

// ---------- Users (with role filter + pagination) ----------

/** GET /api/admin/users — list recent users (filter by ?role=&limit=) */
adminRoutes.get('/users', async (c) => {
  const role = c.req.query('role');
  const limit = Math.min(parseInt(c.req.query('limit') ?? '100', 10), 500);

  try {
    const supabase = getSupabase(c.env);
    let query = supabase
      .from('unified_profiles')
      .select('id,email,display_name,role,created_at')
      .order('created_at', { ascending: false })
      .limit(limit);
    if (role) {
      query = query.eq('role', role);
    }
    const { data, error } = await query;
    if (error) throw error;
    return c.json({ users: data ?? [] });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/teachers — list all teachers with stats (blueprint:1529) */
adminRoutes.get('/teachers', async (c) => {
  try {
    const teachers = await listTeachers(c.env);
    return c.json({ teachers });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/students — list all students with progress (blueprint:1532) */
adminRoutes.get('/students', async (c) => {
  try {
    const students = await listStudents(c.env);
    return c.json({ students });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

// ---------- Commission ----------

/** GET /api/admin/commission — commission summary across all teachers (blueprint:1535) */
adminRoutes.get('/commission', cache({ ttl: 30, varyByUser: false }), async (c) => {
  try {
    const summary = await getAdminCommissionSummary(c.env);
    return c.json(summary);
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/commission-rates — list all commission rates */
adminRoutes.get('/commission-rates', async (c) => {
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('commission_rates')
    .select('id, action, rate_idr, description, active, updated_at')
    .order('action');
  if (error) {
    return c.json({ error: { code: 'FETCH_FAILED', message: error.message } }, 500);
  }
  return c.json({ rates: data ?? [] });
});

/** POST /api/admin/commission-rates — update a commission rate */
adminRoutes.post('/commission-rates', async (c) => {
  let body: { action?: string; rate_idr?: number; description?: string; active?: boolean };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.action || typeof body.rate_idr !== 'number') {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'action and rate_idr required' } }, 400);
  }
  if (!VALID_COMMISSION_ACTIONS.includes(body.action)) {
    return c.json(
      { error: { code: 'INVALID_ACTION', message: `action must be one of: ${VALID_COMMISSION_ACTIONS.join(', ')}` } },
      400
    );
  }
  if (body.rate_idr < 0) {
    return c.json({ error: { code: 'INVALID_RATE', message: 'rate_idr must be >= 0' } }, 400);
  }

  const supabase = getSupabase(c.env);
  const update: Record<string, unknown> = {
    rate_idr: body.rate_idr,
    updated_at: new Date().toISOString(),
  };
  if (typeof body.description === 'string') update.description = body.description;
  if (typeof body.active === 'boolean') update.active = body.active;

  // Use select() to verify row was actually updated (audit fix)
  const { data, error } = await supabase
    .from('commission_rates')
    .update(update)
    .eq('action', body.action)
    .select('id')
    .maybeSingle();
  if (error) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error.message } }, 500);
  }
  if (!data) {
    return c.json(
      { error: { code: 'NOT_FOUND', message: `Commission action '${body.action}' not found` } },
      404
    );
  }
  return c.json({ success: true });
});

// ---------- Ambassadors (with recruited_count) ----------

/** GET /api/admin/payouts — list all payout requests (for approval) */
adminRoutes.get('/payouts', async (c) => {
  const supabase = getSupabase(c.env);
  const status = c.req.query('status') ?? 'pending';
  const { data, error } = await supabase
    .from('commission_payouts')
    .select(`
      id, teacher_id, amount, method, status, reference, notes,
      requested_at, processed_at, paid_at,
      teacher:unified_profiles!commission_payouts_teacher_id_fkey (display_name, email)
    `)
    .eq('status', status)
    .order('requested_at', { ascending: false })
    .limit(100);
  if (error) {
    return c.json({ error: { code: 'FETCH_FAILED', message: error.message } }, 500);
  }
  return c.json({ payouts: data ?? [] });
});

/** POST /api/admin/payouts/:id/approve — approve payout (mark as paid) */
adminRoutes.post('/payouts/:id/approve', async (c) => {
  const supabase = getSupabase(c.env);
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('commission_payouts')
    .update({ status: 'paid', processed_at: now, paid_at: now })
    .eq('id', c.req.param('id'))
    .eq('status', 'pending')  // only approve pending payouts
    .select('id, teacher_id, amount')
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error?.message ?? 'payout not found or not pending' } }, 500);
  }

  // Also update commission_ledger entries for this teacher — mark as paid
  const row = data as Record<string, unknown>;
  await supabase
    .from('commission_ledger')
    .update({ status: 'paid', paid_at: now })
    .eq('teacher_id', row.teacher_id as string)
    .eq('status', 'pending');

  return c.json({ success: true, payout_id: row.id });
});

/** POST /api/admin/payouts/:id/reject — reject payout */
adminRoutes.post('/payouts/:id/reject', async (c) => {
  let body: { notes?: string };
  try { body = await c.req.json().catch(() => ({})); } catch {
    body = {};
  }
  const supabase = getSupabase(c.env);
  const { error } = await supabase
    .from('commission_payouts')
    .update({ status: 'rejected', processed_at: new Date().toISOString(), notes: body.notes ?? 'Rejected by admin' })
    .eq('id', c.req.param('id'))
    .eq('status', 'pending');
  if (error) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error.message } }, 500);
  }
  return c.json({ success: true });
});

// ---------- Ambassadors (with recruited_count) ----------

/** GET /api/admin/ambassadors — list ambassadors with recruited_count (blueprint:1549) */
adminRoutes.get('/ambassadors', async (c) => {
  const supabase = getSupabase(c.env);

  // Fetch ambassadors — specify FK hint (user_id) because there are 2 FKs
  // between unified_profiles and teacher_profiles (user_id + ambassador_recruited_by)
  const { data: ambassadors, error } = await supabase
    .from('unified_profiles')
    .select(`
      id, display_name, email,
      teacher_profiles!user_id!inner(is_ambassador, ambassador_recruited_at, ambassador_recruited_by)
    `)
    .eq('teacher_profiles.is_ambassador', true)
    .order('display_name');
  if (error) {
    return c.json({ error: { code: 'FETCH_FAILED', message: error.message } }, 500);
  }

  // Count recruited teachers per ambassador in one query
  const ambassadorIds = (ambassadors ?? []).map((a) => (a as Record<string, unknown>).id as string);
  const { data: referrals } = await supabase
    .from('unified_profiles')
    .select('referred_by')
    .in('referred_by', ambassadorIds)
    .eq('role', 'teacher');
  const recruitedCount: Record<string, number> = {};
  for (const r of (referrals ?? []) as Array<Record<string, unknown>>) {
    const rid = r.referred_by as string;
    recruitedCount[rid] = (recruitedCount[rid] ?? 0) + 1;
  }

  return c.json({
    ambassadors: (ambassadors ?? []).map((a) => {
      const row = a as Record<string, unknown>;
      return {
        ...row,
        recruited_count: recruitedCount[row.id as string] ?? 0,
      };
    }),
  });
});

/** POST /api/admin/ambassadors/promote — promote a teacher to ambassador (auto-set Pro tier for life, Appendix B line 2920) */
adminRoutes.post('/ambassadors/promote', async (c) => {
  let body: { teacher_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.teacher_id) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'teacher_id required' } }, 400);
  }
  const supabase = getSupabase(c.env);
  const now = new Date().toISOString();
  // Set is_ambassador + auto-upgrade tier to Pro for life (tier_expires_at = NULL = never expires)
  const { data, error } = await supabase
    .from('teacher_profiles')
    .update({
      is_ambassador: true,
      ambassador_recruited_at: now,
      tier: 'pro',
      tier_expires_at: null,  // for life
      badge: 'osee_certified_educator',  // Appendix B line 2918
      updated_at: now,
    })
    .eq('user_id', body.teacher_id)
    .select()
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'PROMOTE_FAILED', message: error?.message ?? 'teacher not found' } }, 500);
  }
  return c.json({ success: true, ambassador: data });
});

/** POST /api/admin/ambassadors/revoke — revoke ambassador status from a teacher */
adminRoutes.post('/ambassadors/revoke', async (c) => {
  let body: { teacher_id?: string };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.teacher_id) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'teacher_id required' } }, 400);
  }
  const supabase = getSupabase(c.env);
  const now = new Date().toISOString();
  const { data, error } = await supabase
    .from('teacher_profiles')
    .update({
      is_ambassador: false,
      ambassador_recruited_at: null,
      badge: null,
      updated_at: now,
    })
    .eq('user_id', body.teacher_id)
    .select()
    .maybeSingle();
  if (error || !data) {
    return c.json({ error: { code: 'REVOKE_FAILED', message: error?.message ?? 'teacher not found' } }, 500);
  }
  return c.json({ success: true, ambassador: data });
});

// ---------- Orders management (Goal 3/9) ----------

/** GET /api/admin/orders — list all orders across users (filter by ?status=) */
adminRoutes.get('/orders', async (c) => {
  const status = c.req.query('status') ?? undefined;
  try {
    const { listAllOrders } = await import('../services/orders');
    const orders = await listAllOrders(c.env, status);
    return c.json({ orders });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** POST /api/admin/orders/:id/refund — refund a paid/fulfilled order + void vouchers */
adminRoutes.post('/orders/:id/refund', async (c) => {
  const orderId = c.req.param('id');
  try {
    const { refundOrder } = await import('../services/orders');
    await refundOrder(c.env, orderId);
    return c.json({ success: true, message: 'Order refunded and vouchers voided' });
  } catch (err) {
    return c.json({ error: { code: 'REFUND_FAILED', message: (err as Error).message } }, 400);
  }
});

/** POST /api/admin/orders/:id/retry-fulfill — retry fulfillment for failed/pending items */
adminRoutes.post('/orders/:id/retry-fulfill', async (c) => {
  const orderId = c.req.param('id');
  try {
    const { retryFulfill } = await import('../services/orders');
    const result = await retryFulfill(c.env, orderId);
    return c.json({ success: true, ...result });
  } catch (err) {
    return c.json({ error: { code: 'FULFILL_FAILED', message: (err as Error).message } }, 400);
  }
});

/** POST /api/admin/orders/:id/cancel — admin cancels an order (pending or unpaid). */
adminRoutes.post('/orders/:id/cancel', async (c) => {
  const orderId = c.req.param('id');
  try {
    const { cancelOrderAdmin } = await import('../services/orders');
    await cancelOrderAdmin(c.env, orderId);
    return c.json({ success: true, message: 'Order cancelled' });
  } catch (err) {
    return c.json({ error: { code: 'CANCEL_FAILED', message: (err as Error).message } }, 400);
  }
});

/** POST /api/admin/orders/:id/mark-paid — manually mark a pending order as paid
 *  (for offline payments like bank transfer that bypass TriPay webhook). */
adminRoutes.post('/orders/:id/mark-paid', async (c) => {
  const orderId = c.req.param('id');
  let body: { payment_method?: string } = {};
  try { body = await c.req.json(); } catch { /* ok if no body */ }
  try {
    const { markOrderPaidAdmin } = await import('../services/orders');
    await markOrderPaidAdmin(c.env, orderId, body.payment_method ?? 'manual');
    return c.json({ success: true, message: 'Order marked paid + fulfilled' });
  } catch (err) {
    return c.json({ error: { code: 'MARK_PAID_FAILED', message: (err as Error).message } }, 400);
  }
});

// ---------- Knowledge base ----------

/** GET /api/admin/knowledge-base/documents — list KB documents (filter by ?category=&active=) */
adminRoutes.get('/knowledge-base/documents', async (c) => {
  const category = c.req.query('category');
  const active = c.req.query('active');
  const limit = Math.min(parseInt(c.req.query('limit') ?? '200', 10), 500);

  const supabase = getSupabase(c.env);
  let query = supabase
    .from('knowledge_base_documents')
    .select('id, title, source, category, cefr_level, content_chunk_count, is_active, created_at')
    .order('created_at', { ascending: false })
    .limit(limit);
  if (category) query = query.eq('category', category);
  if (active === 'true') query = query.eq('is_active', true);
  if (active === 'false') query = query.eq('is_active', false);

  const { data, error } = await query;
  if (error) {
    return c.json({ error: { code: 'FETCH_FAILED', message: error.message } }, 500);
  }
  return c.json({ documents: data ?? [] });
});

/** POST /api/admin/knowledge-base/upload — admin uploads to RAG knowledge base */
adminRoutes.post('/knowledge-base/upload', async (c) => {
  let body: {
    title?: string;
    source?: string;
    category?: string;
    content?: string;
    cefr_level?: string;
    metadata?: Record<string, unknown>;
  };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.title || !body.source || !body.category || !body.content) {
    return c.json(
      { error: { code: 'INVALID_INPUT', message: 'title, source, category, content required' } },
      400
    );
  }
  if (!VALID_CATEGORIES.includes(body.category)) {
    return c.json(
      { error: { code: 'INVALID_CATEGORY', message: `category must be one of: ${VALID_CATEGORIES.join(', ')}` } },
      400
    );
  }
  if (body.cefr_level && !VALID_CEFR.includes(body.cefr_level)) {
    return c.json(
      { error: { code: 'INVALID_CEFR', message: `cefr_level must be one of: ${VALID_CEFR.join(', ')}` } },
      400
    );
  }

  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('knowledge_base_documents')
    .insert({
      title: body.title,
      source: body.source,
      category: body.category,
      content: body.content,
      cefr_level: body.cefr_level ?? null,
      metadata: body.metadata ?? {},
      is_active: true,
    })
    .select()
    .single();
  if (error || !data) {
    return c.json({ error: { code: 'INSERT_FAILED', message: error?.message ?? 'unknown' } }, 500);
  }
  return c.json({ document_id: (data as Record<string, unknown>).id, success: true }, 201);
});

/** POST /api/admin/knowledge-base/:id/embed — trigger embedding (via OpenAI) for an existing document.
 *
 *  Chunks fail count is tracked so admin can see partial embedding failures
 *  (data-integrity fix — previously failures were silently skipped and
 *  content_chunk_count reported as if all chunks succeeded). */
adminRoutes.post('/knowledge-base/:id/embed', async (c) => {
  const docId = c.req.param('id');
  const supabase = getSupabase(c.env);

  const { data: doc } = await supabase
    .from('knowledge_base_documents')
    .select('id, content')
    .eq('id', docId)
    .maybeSingle();
  if (!doc) {
    return c.json({ error: { code: 'NOT_FOUND', message: 'Document not found' } }, 404);
  }
  const content = (doc as Record<string, unknown>).content as string;

  const chunks = chunkText(content, 500, 50);
  let embedded = 0;
  const failures: Array<{ chunk_index: number; error: string }> = [];
  for (let i = 0; i < chunks.length; i++) {
    const result = await getEmbedding(c.env, chunks[i]);
    if (result.ok) {
      const { error: embError } = await supabase.from('knowledge_base_embeddings').insert({
        document_id: docId,
        chunk_index: i,
        chunk_text: chunks[i],
        embedding: result.embedding,
      });
      if (embError) {
        failures.push({ chunk_index: i, error: embError.message });
      } else {
        embedded++;
      }
    } else {
      failures.push({ chunk_index: i, error: result.error });
    }
  }

  // content_chunk_count = number actually embedded (not number attempted)
  await supabase
    .from('knowledge_base_documents')
    .update({ content_chunk_count: embedded })
    .eq('id', docId);

  return c.json({
    success: failures.length === 0,
    chunks: chunks.length,
    embedded,
    failures,
  });
});

// ---------- Helpers ----------

/** Chunk text into ~maxTokens chunks with overlap (words). */
function chunkText(text: string, maxTokens: number, overlap: number): string[] {
  const paragraphs = text.split(/\n\n+/);
  const chunks: string[] = [];
  let current = '';
  for (const para of paragraphs) {
    const estTokens = Math.ceil((current + para).length / 4);
    if (estTokens > maxTokens && current) {
      chunks.push(current);
      const words = current.split(' ');
      current = words.slice(-overlap).join(' ') + '\n\n' + para;
    } else {
      current = current ? current + '\n\n' + para : para;
    }
  }
  if (current) chunks.push(current);
  return chunks;
}

/** Get OpenAI embedding for a text chunk — returns error message on failure (audit fix). */
async function getEmbedding(
  env: Env,
  text: string
): Promise<{ ok: true; embedding: number[] } | { ok: false; error: string }> {
  try {
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({ model: 'text-embedding-3-small', input: text }),
    });
    if (!res.ok) {
      const errText = await res.text().catch(() => '');
      return { ok: false, error: `OpenAI ${res.status}: ${errText.slice(0, 200)}` };
    }
    const json = (await res.json()) as { data: Array<{ embedding: number[] }> };
    if (!json.data[0]?.embedding) {
      return { ok: false, error: 'OpenAI returned no embedding' };
    }
    return { ok: true, embedding: json.data[0].embedding };
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : 'Unknown error' };
  }
}