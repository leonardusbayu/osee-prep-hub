import type { Env, ItemType, UserRole } from '../types';
import { getSupabase } from './supabase';

/**
 * Pricing service — Task 15.5.
 *
 * Looks up prices from pricing_config table based on item_type + role.
 * Falls back to student price if role-specific price not found.
 */

/** Get price for an item type + role. Returns null if no pricing configured. */
export async function getPrice(env: Env, itemType: ItemType, role: UserRole): Promise<number | null> {
  const supabase = getSupabase(env);
  // Try role-specific price first
  const { data, error } = await supabase
    .from('pricing_config')
    .select('price')
    .eq('item_type', itemType)
    .eq('role', role)
    .eq('is_active', true)
    .maybeSingle();

  if (error) {
    console.warn('Pricing query failed:', error.message);
    return null;
  }

  if (data?.price !== null && data?.price !== undefined) {
    return data.price as number;
  }

  // Fall back to student price
  if (role !== 'student') {
    const { data: fallback } = await supabase
      .from('pricing_config')
      .select('price')
      .eq('item_type', itemType)
      .eq('role', 'student')
      .eq('is_active', true)
      .maybeSingle();
    if (fallback?.price !== null && fallback?.price !== undefined) {
      return fallback.price as number;
    }
  }

  return null;
}

/** Get all pricing for a role (for display on order pages). */
export async function getPricingForRole(env: Env, role: UserRole): Promise<Record<string, number>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('pricing_config')
    .select('item_type, price')
    .eq('role', role)
    .eq('is_active', true);

  if (error || !data) return {};

  const result: Record<string, number> = {};
  for (const row of data as Array<{ item_type: string; price: number }>) {
    result[row.item_type] = row.price;
  }

  // Fill in missing items with student price fallback
  if (role !== 'student') {
    const { data: studentPricing } = await supabase
      .from('pricing_config')
      .select('item_type, price')
      .eq('role', 'student')
      .eq('is_active', true);
    if (studentPricing) {
      for (const row of studentPricing as Array<{ item_type: string; price: number }>) {
        if (!result[row.item_type]) {
          result[row.item_type] = row.price;
        }
      }
    }
  }

  return result;
}

/** Admin: set/update price for item_type + role. */
export async function setPrice(
  env: Env,
  itemType: ItemType,
  role: UserRole,
  price: number
): Promise<void> {
  if (price < 0) throw new Error('Price cannot be negative');
  const supabase = getSupabase(env);
  const { error } = await supabase
    .from('pricing_config')
    .upsert(
      { item_type: itemType, role, price, is_active: true },
      { onConflict: 'item_type,role' }
    );
  if (error) throw new Error(`Set price failed: ${error.message}`);
}

/** Admin: list all pricing entries. */
export async function listAllPricing(env: Env): Promise<Array<Record<string, unknown>>> {
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('pricing_config')
    .select('*')
    .order('item_type', { ascending: true })
    .order('role', { ascending: true });
  if (error) throw new Error(`List pricing failed: ${error.message}`);
  return (data ?? []) as Array<Record<string, unknown>>;
}