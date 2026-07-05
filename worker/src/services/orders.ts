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
      // TODO: Task 15.10 will implement booking bridge
      // For now, mark as pending booking
      console.log(`Booking needed for order ${orderId}, item ${itemId}, student ${assignedStudentId}`);
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