/**
 * Marketplace service — T14 (Wave 2).
 *
 * Listings + purchases + reviews. Escrow flow uses TriPay (integrated in payment service).
 * 15% OSEE commission on every purchase.
 *
 * Stub: TriPay integration is mocked — the purchase creates a row with
 * escrow_status='pending' and a fake tripay_transaction_ref. The release/refund
 * flow requires the real TriPay webhook handler (existing webhook.ts).
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export const OSEE_COMMISSION_PCT = 15;

export interface Listing {
  id: string;
  seller_id: string;
  title: string;
  description: string;
  listing_type: 'lesson_plan' | 'mock_test' | 'live_class' | 'video' | 'ebook';
  exam: 'TOEFL_IBT' | 'TOEFL_ITP' | 'IELTS' | 'TOEIC' | 'GENERAL';
  level: 'A1' | 'A2' | 'B1' | 'B2' | 'C1' | 'C2' | 'GENERAL';
  price_idr: number;
  preview_url: string | null;
  syllabus_id: string | null;
  is_published: boolean;
  view_count: number;
  purchase_count: number;
  created_at: string;
}

export interface Purchase {
  id: string;
  listing_id: string;
  buyer_id: string;
  seller_id: string;
  price_idr: number;
  commission_idr: number;
  payout_idr: number;
  escrow_status: 'pending' | 'paid' | 'released' | 'refunded' | 'disputed';
  tripay_transaction_ref: string | null;
  created_at: string;
  released_at: string | null;
}

export function calculateSplit(priceIdr: number): { commission: number; payout: number } {
  const commission = Math.round(priceIdr * OSEE_COMMISSION_PCT / 100);
  const payout = priceIdr - commission;
  return { commission, payout };
}

/** Create a new listing. */
export async function createListing(
  env: Env,
  sellerId: string,
  input: {
    title: string;
    description: string;
    listing_type: Listing['listing_type'];
    exam: Listing['exam'];
    level: Listing['level'];
    price_idr: number;
    preview_url?: string;
    syllabus_id?: string;
  }
): Promise<Listing> {
  if (!input.title || !input.description || input.price_idr <= 0) {
    throw new Error('title, description, price_idr required');
  }
  const supabase = getSupabase(env);
  const { data, error } = await supabase
    .from('marketplace_listings')
    .insert({ ...input, seller_id: sellerId, preview_url: input.preview_url ?? null, syllabus_id: input.syllabus_id ?? null })
    .select()
    .single();
  if (error || !data) throw new Error(`createListing failed: ${error?.message ?? 'no row'}`);
  return data as Listing;
}

/** List published listings, optionally filtered by exam/level. */
export async function listListings(
  env: Env,
  filters?: { exam?: string; level?: string; sellerId?: string; limit?: number }
): Promise<Listing[]> {
  const supabase = getSupabase(env);
  let query = supabase
    .from('marketplace_listings')
    .select('*')
    .eq('is_published', true)
    .order('created_at', { ascending: false })
    .limit(filters?.limit ?? 50);
  if (filters?.exam) query = query.eq('exam', filters.exam);
  if (filters?.level) query = query.eq('level', filters.level);
  if (filters?.sellerId) query = query.eq('seller_id', filters.sellerId);
  const { data, error } = await query;
  if (error) throw new Error(`listListings failed: ${error.message}`);
  return (data ?? []) as Listing[];
}

/** Initiate a purchase — creates escrow row + mock TriPay transaction ref. */
export async function initiatePurchase(
  env: Env,
  buyerId: string,
  listingId: string
): Promise<Purchase> {
  const supabase = getSupabase(env);
  // Fetch listing.
  const { data: listing } = await supabase
    .from('marketplace_listings')
    .select('*')
    .eq('id', listingId)
    .single();
  if (!listing) throw new Error('Listing not found');
  if (listing.seller_id === buyerId) throw new Error('seller_cannot_buy');

  // Check no existing purchase.
  const { data: existing } = await supabase
    .from('marketplace_purchases')
    .select('id, escrow_status')
    .eq('listing_id', listingId)
    .eq('buyer_id', buyerId)
    .in('escrow_status', ['pending', 'paid'])
    .maybeSingle();
  if (existing) throw new Error('already_purchased');

  const split = calculateSplit(listing.price_idr);
  // Mock TriPay transaction ref.
  const tripayRef = `TRX-MOCK-${Date.now()}-${listingId.slice(0, 8)}`;

  const { data: purchase, error } = await supabase
    .from('marketplace_purchases')
    .insert({
      listing_id: listingId,
      buyer_id: buyerId,
      seller_id: listing.seller_id,
      price_idr: listing.price_idr,
      commission_idr: split.commission,
      payout_idr: split.payout,
      escrow_status: 'pending',
      tripay_transaction_ref: tripayRef,
    })
    .select()
    .single();
  if (error || !purchase) throw new Error(`initiatePurchase failed: ${error?.message ?? 'no row'}`);
  return purchase as Purchase;
}

/** Get purchase by ID. */
export async function getPurchase(env: Env, purchaseId: string): Promise<Purchase | null> {
  const supabase = getSupabase(env);
  const { data } = await supabase
    .from('marketplace_purchases')
    .select('*')
    .eq('id', purchaseId)
    .single();
  return (data as Purchase) ?? null;
}

/** List user's purchases (bought + sold). */
export async function listUserPurchases(
  env: Env,
  userId: string,
  role: 'buyer' | 'seller'
): Promise<Purchase[]> {
  const supabase = getSupabase(env);
  const column = role === 'buyer' ? 'buyer_id' : 'seller_id';
  const { data, error } = await supabase
    .from('marketplace_purchases')
    .select('*')
    .eq(column, userId)
    .order('created_at', { ascending: false });
  if (error) throw new Error(`listUserPurchases failed: ${error.message}`);
  return (data ?? []) as Purchase[];
}

/** Submit a review. Only the buyer can review, only after escrow released. */
export async function submitReview(
  env: Env,
  buyerId: string,
  purchaseId: string,
  stars: number,
  comment?: string
): Promise<{ id: string }> {
  if (stars < 1 || stars > 5) throw new Error('stars must be 1-5');
  const supabase = getSupabase(env);
  const { data: purchase } = await supabase
    .from('marketplace_purchases')
    .select('buyer_id, listing_id, escrow_status')
    .eq('id', purchaseId)
    .single();
  if (!purchase) throw new Error('Purchase not found');
  if (purchase.buyer_id !== buyerId) throw new Error('Only the buyer can review');
  if (purchase.escrow_status !== 'released') throw new Error('Cannot review before escrow released');

  const { data, error } = await supabase
    .from('marketplace_reviews')
    .insert({
      purchase_id: purchaseId,
      listing_id: purchase.listing_id,
      reviewer_id: buyerId,
      stars,
      comment: comment ?? null,
    })
    .select('id')
    .single();
  if (error) throw new Error(`submitReview failed: ${error.message}`);
  return { id: data.id };
}