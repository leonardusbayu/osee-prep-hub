import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { setPrice, listAllPricing } from '../services/pricing';
import { getSupabase } from '../services/supabase';

export const adminRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

adminRoutes.use('*', requireAuth());

/** Admin role guard */
adminRoutes.use('*', async (c, next) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin role required' } }, 403);
  }
  await next();
  return; // ensure all code paths return
});

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
  try {
    await setPrice(c.env, body.item_type as never, body.role as never, body.price);
    return c.json({ success: true });
  } catch (err) {
    return c.json({ error: { code: 'SET_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/stats — platform-wide stats (placeholder for Task 18.4) */
adminRoutes.get('/stats', async (c) => {
  try {
    const supabase = getSupabase(c.env);
    const [
      users,
      teachers,
      revenue,
      commissionPaid,
      aiUsage,
    ] = await Promise.all([
      supabase.from('unified_profiles').select('id', { count: 'exact', head: true }),
      supabase
        .from('unified_profiles')
        .select('id', { count: 'exact', head: true })
        .eq('role', 'teacher'),
      supabase
        .from('orders')
        .select('total_amount')
        .in('status', ['paid', 'fulfilled']),
      supabase
        .from('commission_ledger')
        .select('amount_idr')
        .eq('status', 'paid'),
      supabase
        .from('ai_quota_usage')
        .select('used_count'),
    ]);

    const totalRevenue = (revenue.data ?? []).reduce(
      (sum, row) => sum + Number((row as { total_amount?: number }).total_amount ?? 0),
      0
    );
    const totalCommissionPaid = (commissionPaid.data ?? []).reduce(
      (sum, row) => sum + Number((row as { amount_idr?: number }).amount_idr ?? 0),
      0
    );
    const totalAiUsage = (aiUsage.data ?? []).reduce(
      (sum, row) => sum + Number((row as { used_count?: number }).used_count ?? 0),
      0
    );

    return c.json({
      total_users: users.count ?? 0,
      active_teachers: teachers.count ?? 0,
      total_revenue: totalRevenue,
      commission_paid: totalCommissionPaid,
      ai_usage: totalAiUsage,
    });
  } catch (err) {
    return c.json({ error: { code: 'FETCH_FAILED', message: (err as Error).message } }, 500);
  }
});

/** GET /api/admin/users — list recent users */
adminRoutes.get('/users', async (c) => {
  try {
    const supabase = getSupabase(c.env);
    const { data, error } = await supabase
      .from('unified_profiles')
      .select('id,email,display_name,role,created_at')
      .order('created_at', { ascending: false })
      .limit(100);
    if (error) throw error;
    return c.json({ users: data ?? [] });
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
  const supabase = getSupabase(c.env);
  const update: Record<string, unknown> = {
    rate_idr: body.rate_idr,
    updated_at: new Date().toISOString(),
  };
  if (typeof body.description === 'string') update.description = body.description;
  if (typeof body.active === 'boolean') update.active = body.active;

  const { error } = await supabase
    .from('commission_rates')
    .update(update)
    .eq('action', body.action);
  if (error) {
    return c.json({ error: { code: 'UPDATE_FAILED', message: error.message } }, 500);
  }
  return c.json({ success: true });
});

/** GET /api/admin/ambassadors — list ambassadors with recruited count (Task 17.x) */
adminRoutes.get('/ambassadors', async (c) => {
  const supabase = getSupabase(c.env);
  const { data: ambassadors, error } = await supabase
    .from('unified_profiles')
    .select('id, display_name, email, teacher_profiles!inner(is_ambassador, ambassador_recruited_at, ambassador_recruited_by)')
    .eq('teacher_profiles.is_ambassador', true);
  if (error) {
    return c.json({ error: { code: 'FETCH_FAILED', message: error.message } }, 500);
  }
  return c.json({ ambassadors: ambassadors ?? [] });
});

/** GET /api/admin/knowledge-base/documents — list KB documents */
adminRoutes.get('/knowledge-base/documents', async (c) => {
  const supabase = getSupabase(c.env);
  const { data, error } = await supabase
    .from('knowledge_base_documents')
    .select('id, title, source, category, cefr_level, content_chunk_count, is_active, created_at')
    .order('created_at', { ascending: false })
    .limit(200);
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

/** POST /api/admin/knowledge-base/:id/embed — trigger embedding (via OpenAI) for an existing document */
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

  // Chunk + embed via OpenAI
  const chunks = chunkText(content, 500, 50);
  for (let i = 0; i < chunks.length; i++) {
    const embedding = await getEmbedding(c.env, chunks[i]);
    if (embedding) {
      await supabase.from('knowledge_base_embeddings').insert({
        document_id: docId,
        chunk_index: i,
        chunk_text: chunks[i],
        embedding,
      });
    }
  }
  await supabase
    .from('knowledge_base_documents')
    .update({ content_chunk_count: chunks.length })
    .eq('id', docId);

  return c.json({ success: true, chunks: chunks.length });
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

/** Get OpenAI embedding for a text chunk. */
async function getEmbedding(env: Env, text: string): Promise<number[] | null> {
  try {
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.OPENAI_API_KEY}`,
      },
      body: JSON.stringify({ model: 'text-embedding-3-small', input: text }),
    });
    if (!res.ok) return null;
    const json = (await res.json()) as { data: Array<{ embedding: number[] }> };
    return json.data[0]?.embedding ?? null;
  } catch {
    return null;
  }
}
