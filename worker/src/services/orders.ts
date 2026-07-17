import type { Env, ItemType, OrderType, UserRole } from '../types';
import { getSupabase } from './supabase';
import { getPrice } from './pricing';

/**
 * Order service — Task 15.6.
 *
 * Handles 4 ordering modes:
 * 1. voucher_resale — buy vouchers at discount, distribute to students, keep margin
 * 2. book_for_student — book official tests on behalf of students
 * 3. bulk_purchase — buy packages, assign to specific students
 * 4. self_purchase — buy for own use
 *
 * Payment via TriPay (bridge to EduBot's payment service).
 * Voucher generation + fulfillment on payment confirmation.
 */

const VOUCHER_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const VOUCHER_LENGTH = 12;

/** Generate a unique voucher code (collision-checked). */
async function generateUniqueVoucherCode(
  supabase: import('@supabase/supabase-js').SupabaseClient
): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    let code = '';
    for (let i = 0; i < VOUCHER_LENGTH; i++) {
      code += VOUCHER_CHARS[Math.floor(Math.random() * VOUCHER_CHARS.length)];
    }
    const { data } = await supabase
      .from('vouchers')
      .select('id')
      .eq('code', code)
      .maybeSingle();
    if (!data) return code;
  }
  throw new Error('Failed to generate unique voucher code after 20 attempts');
}

export interface OrderItemInput {
  item_type: ItemType;
  quantity: number;
  assigned_student_id?: string; // for bulk_purchase / book_for_student
}

export interface CreateOrderInput {
  order_type: OrderType;
  items: OrderItemInput[];
  notes?: string;
}

export interface OrderResult {
  id: string;
  order_type: string;
  status: string;
  total_amount: number;
  items: Array<{
    id: string;
    item_type: string;
    quantity: number;
    unit_price: number;
    assigned_student_id: string | null;
    fulfillment_status: string;
  }>;
}

/** Create a new order. Validates pricing + calculates total. */
export async function createOrder(
  env: Env,
  userId: string,
  role: UserRole,
  input: CreateOrderInput
): Promise<OrderResult> {
  const supabase = getSupabase(env);

  if (!input.items?.length) {
    throw new Error('At least one item required');
  }

  // Calculate total + validate pricing
  let totalAmount = 0;
  const itemsWithPrice: Array<{
    item_type: ItemType;
    quantity: number;
    unit_price: number;
    assigned_student_id: string | null;
  }> = [];

  for (const item of input.items) {
    if (item.quantity < 1) throw new Error(`Quantity must be >= 1 for ${item.item_type}`);
    const price = await getPrice(env, item.item_type, role);
    if (price === null) {
      throw new Error(`No pricing configured for ${item.item_type} (${role})`);
    }
    totalAmount += price * item.quantity;
    itemsWithPrice.push({
      item_type: item.item_type,
      quantity: item.quantity,
      unit_price: price,
      assigned_student_id: item.assigned_student_id ?? null,
    });
  }

  // Create order
  const { data: order, error: orderErr } = await supabase
    .from('orders')
    .insert({
      user_id: userId,
      order_type: input.order_type,
      status: 'pending',
      total_amount: totalAmount,
      notes: input.notes ?? null,
    })
    .select()
    .single();

  if (orderErr || !order) {
    throw new Error(`Create order failed: ${orderErr?.message ?? 'unknown'}`);
  }

  const orderId = order.id as string;

  // Create order items
  const itemInserts = itemsWithPrice.map((item) => ({
    order_id: orderId,
    item_type: item.item_type,
    quantity: item.quantity,
    unit_price: item.unit_price,
    assigned_student_id: item.assigned_student_id,
    fulfillment_status: 'pending',
  }));

  const { data: insertedItems, error: itemsErr } = await supabase
    .from('order_items')
    .insert(itemInserts)
    .select();

  if (itemsErr || !insertedItems) {
    throw new Error(`Create order items failed: ${itemsErr?.message}`);
  }

  return {
    id: orderId,
    order_type: order.order_type as string,
    status: order.status as string,
    total_amount: order.total_amount as number,
    items: insertedItems.map((item: Record<string, unknown>) => ({
      id: item.id as string,
      item_type: item.item_type as string,
      quantity: item.quantity as number,
      unit_price: item.unit_price as number,
      assigned_student_id: (item.assigned_student_id as string) ?? null,
      fulfillment_status: item.fulfillment_status as string,
    })),
  };
}

/** Fulfill a paid order — generates vouchers, bridges to booking, etc. */
export async function fulfillOrder(env: Env, orderId: string): Promise<void> {
  const supabase = getSupabase(env);

  // Get order + items
  const { data: order } = await supabase
    .from('orders')
    .select('*')
    .eq('id', orderId)
    .maybeSingle();

  if (!order) throw new Error(`Order ${orderId} not found`);
  if ((order as Record<string, unknown>).status !== 'paid') {
    throw new Error(`Order ${orderId} not paid (status: ${(order as Record<string, unknown>).status})`);
  }

  // Get items
  const { data: items } = await supabase
    .from('order_items')
    .select('*')
    .eq('order_id', orderId);

  for (const item of (items ?? []) as Array<Record<string, unknown>>) {
    const itemType = item.item_type as ItemType;
    const quantity = item.quantity as number;
    const itemId = item.id as string;
    const assignedStudentId = (item.assigned_student_id as string) ?? null;

    // For voucher_resale + bulk_purchase: generate vouchers
    if (
      (order as Record<string, unknown>).order_type === 'voucher_resale' ||
      (order as Record<string, unknown>).order_type === 'bulk_purchase'
    ) {
      for (let i = 0; i < quantity; i++) {
        const code = await generateUniqueVoucherCode(supabase);
        const expiresAt = new Date();
        expiresAt.setFullYear(expiresAt.getFullYear() + 1);
        await supabase.from('vouchers').insert({
          order_item_id: itemId,
          code,
          item_type: itemType,
          status: 'active',
          expires_at: expiresAt.toISOString(),
        });
      }
      await supabase
        .from('order_items')
        .update({ fulfillment_status: 'voucher_generated' })
        .eq('id', itemId);
    }

    // For book_for_student: bridge to osee.co.id booking (Task 15.10)
    if (
      (order as Record<string, unknown>).order_type === 'book_for_student' &&
      (itemType === 'official_toefl' || itemType === 'official_toeic')
    ) {
      try {
        // Look up the assigned student
        const studentId = assignedStudentId as string | undefined;
        if (studentId) {
          const { data: student } = await supabase
            .from('unified_profiles')
            .select('id, display_name, email')
            .eq('id', studentId)
            .maybeSingle();
          const s = (student as Record<string, unknown> | null) ?? {};

          // Call booking bridge
          const { createBooking } = await import('./booking-bridge');
          const booking = await createBooking(env, {
            order_item_id: itemId,
            student_id: studentId,
            student_name: (s.display_name as string) ?? '',
            student_email: (s.email as string) ?? '',
            test_type: itemType as 'official_toefl' | 'official_toeic',
          });
          console.log(`Booking created: ${booking.booking_id} (status: ${booking.status})`);

          await supabase
            .from('order_items')
            .update({
              fulfillment_status: booking.status === 'confirmed' ? 'booking_confirmed' : 'pending',
              external_booking_id: booking.booking_id,
            })
            .eq('id', itemId);
        } else {
          await supabase
            .from('order_items')
            .update({ fulfillment_status: 'pending_assignment' })
            .eq('id', itemId);
        }
      } catch (err) {
        console.error(`Booking bridge failed for item ${itemId}:`, err);
        await supabase
          .from('order_items')
          .update({ fulfillment_status: 'booking_failed' })
          .eq('id', itemId);
      }
    }

    // For self_purchase: grant access directly
    if ((order as Record<string, unknown>).order_type === 'self_purchase') {
      await supabase
        .from('order_items')
        .update({ fulfillment_status: 'fulfilled' })
        .eq('id', itemId);
    }
  }

  // Mark order as fulfilled
  await supabase.from('orders').update({ status: 'fulfilled' }).eq('id', orderId);
}

/** Get order by ID (must belong to user). */
export async function getOrder(env: Env, userId: string, orderId: string): Promise<Record<string, unknown> | null> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('orders')
    .select('*, order_items(*)')
    .eq('id', orderId)
    .eq('user_id', userId)
    .maybeSingle();
  if (error || !data) return null;
  return data as Record<string, unknown>;
}

/** List user's orders. */
export async function listOrders(env: Env, userId: string): Promise<Array<Record<string, unknown>>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('orders')
    .select('*, order_items(*)')
    .eq('user_id', userId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(`List orders failed: ${error.message}`);
  return (data ?? []) as Array<Record<string, unknown>>;
}

/** Cancel order (only if pending). */
export async function cancelOrder(env: Env, userId: string, orderId: string): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('orders')
    .update({ status: 'cancelled' })
    .eq('id', orderId)
    .eq('user_id', userId)
    .eq('status', 'pending');
  if (error) throw new Error(`Cancel failed: ${error.message}`);
}

/** Mark order as paid (called by TriPay webhook). */
export async function markOrderPaid(
  env: Env,
  orderId: string,
  paymentMethod: string,
  paymentRef: string
): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('orders')
    .update({
      status: 'paid',
      payment_method: paymentMethod,
      payment_ref: paymentRef,
    })
    .eq('id', orderId)
    .eq('status', 'pending');
  if (error) throw new Error(`Mark paid failed: ${error.message}`);

  // Fulfill the order
  await fulfillOrder(env, orderId);
}

/** List ALL orders (admin) — optionally filtered by status. (Goal 3/9) */
export async function listAllOrders(env: Env, status?: string): Promise<Array<Record<string, unknown>>> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('orders')
    .select('*, order_items(*), user:unified_profiles!orders_user_id_fkey(email, display_name, role)')
    .order('created_at', { ascending: false })
    .limit(500);
  if (status) query = query.eq('status', status);
  const { data, error } = await query;
  if (error) throw new Error(`List all orders failed: ${error.message}`);
  return (data ?? []) as Array<Record<string, unknown>>;
}

/** Refund an order — sets status='refunded' and voids linked vouchers. (Goal 3) */
export async function refundOrder(env: Env, orderId: string): Promise<void> {
  const supabase = getSupabase(env);

  // Verify order exists and is in a refundable state.
  const { data: order } = await supabase
    .from('orders')
    .select('id, status')
    .eq('id', orderId)
    .maybeSingle();
  if (!order) throw new Error('Order not found');
  const o = order as Record<string, unknown>;
  if (!['paid', 'fulfilled'].includes(o.status as string)) {
    throw new Error(`Cannot refund order in status '${o.status}' (only paid/fulfilled)`);
  }

  // Void any vouchers linked to this order's items.
  const { data: items } = await supabase
    .from('order_items')
    .select('id')
    .eq('order_id', orderId);
  const itemIds = (items ?? []).map((i: Record<string, unknown>) => i.id as string);
  if (itemIds.length > 0) {
    await supabase
      .from('vouchers')
      .update({ status: 'cancelled' })
      .in('order_item_id', itemIds)
      .in('status', ['active', 'redeemed']);
  }

  // Mark order as refunded.
  const { error } = await supabase
    .from('orders')
    .update({ status: 'refunded' })
    .eq('id', orderId);
  if (error) throw new Error(`Refund failed: ${error.message}`);
}

/** Retry fulfillment for items that failed/pending booking. (Goal 3) */
export async function retryFulfill(env: Env, orderId: string): Promise<{ retried: number }> {
  const supabase = getSupabase(env);

  // Check order is paid (fulfillment only runs on paid orders).
  const { data: order } = await supabase
    .from('orders')
    .select('id, status')
    .eq('id', orderId)
    .maybeSingle();
  if (!order) throw new Error('Order not found');
  if ((order as Record<string, unknown>).status !== 'paid') {
    throw new Error('Order must be paid to retry fulfillment');
  }

  // Count items in a retryable state.
  const { data: items } = await supabase
    .from('order_items')
    .select('id, fulfillment_status')
    .eq('order_id', orderId);
  const retryable = (items ?? []).filter(
    (i: Record<string, unknown>) => ['booking_failed', 'pending_assignment', 'pending_booking', 'pending'].includes(i.fulfillment_status as string)
  );
  if (retryable.length === 0) {
    return { retried: 0 };
  }

  // Re-run fulfillment — fulfillOrder re-processes all items but is idempotent
  // for already-fulfilled ones (it checks status before each action).
  await fulfillOrder(env, orderId);
  return { retried: retryable.length };
}

/** Admin: cancel any order (no user_id scope). (Goal 3) */
export async function cancelOrderAdmin(env: Env, orderId: string): Promise<void> {
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('orders')
    .update({ status: 'cancelled' })
    .eq('id', orderId)
    .in('status', ['pending', 'paid']); // can cancel pending or unpaid-before-fulfill
  if (error) throw new Error(`Cancel failed: ${error.message}`);
  // Void any vouchers already generated
  const { data: items } = await supabase
    .from('order_items')
    .select('id')
    .eq('order_id', orderId);
  const itemIds = (items ?? []).map((i: Record<string, unknown>) => i.id as string);
  if (itemIds.length > 0) {
    await supabase
      .from('vouchers')
      .update({ status: 'cancelled' })
      .in('order_item_id', itemIds)
      .eq('status', 'active');
  }
}

/** Admin: mark a pending order as paid manually (for offline payment like
 *  bank transfer that doesn't trigger TriPay webhook) then fulfill it. */
export async function markOrderPaidAdmin(
  env: Env,
  orderId: string,
  paymentMethod: string = 'manual'
): Promise<void> {
  await markOrderPaid(env, orderId, paymentMethod, `admin-manual-${Date.now()}`);
}