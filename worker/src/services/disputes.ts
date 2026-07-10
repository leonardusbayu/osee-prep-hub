/**
 * Marketplace dispute + reputation service — T28 (Wave 4).
 */

import type { Env } from '../types';
import { getSupabase } from './supabase';

export interface Dispute {
  id: string;
  purchase_id: string;
  opened_by: string;
  reason: 'not_as_described' | 'never_delivered' | 'quality_issue' | 'duplicate' | 'other';
  description: string;
  status: 'open' | 'under_review' | 'resolved_refund' | 'resolved_reject' | 'closed';
  resolution_notes: string | null;
  resolved_by: string | null;
  resolved_at: string | null;
  evidence_urls: string[];
  created_at: string;
}

export interface SellerReputation {
  seller_id: string;
  average_stars: number;
  review_count: number;
  completed_sales: number;
  dispute_count: number;
  badges: string[];
}

/** Open a dispute on a purchase. */
export async function openDispute(
  env: Env,
  openerId: string,
  purchaseId: string,
  reason: Dispute['reason'],
  description: string,
  evidenceUrls: string[] = []
): Promise<Dispute> {
  const supabase = getSupabase(env);

  // Verify opener is the buyer of this purchase.
  const { data: purchase } = await supabase
    .from('marketplace_purchases')
    .select('buyer_id, escrow_status')
    .eq('id', purchaseId)
    .single();
  if (!purchase) throw new Error('Purchase not found');
  if (purchase.buyer_id !== openerId) throw new Error('Only the buyer can open a dispute');
  if (purchase.escrow_status === 'released') {
    throw new Error('Cannot dispute a released escrow');
  }

  // Check no existing open dispute.
  const { data: existing } = await supabase
    .from('marketplace_disputes')
    .select('id')
    .eq('purchase_id', purchaseId)
    .in('status', ['open', 'under_review'])
    .maybeSingle();
  if (existing) throw new Error('A dispute is already open for this purchase');

  // Set escrow to disputed.
  await supabase
    .from('marketplace_purchases')
    .update({ escrow_status: 'disputed' })
    .eq('id', purchaseId);

  const { data, error } = await supabase
    .from('marketplace_disputes')
    .insert({
      purchase_id: purchaseId,
      opened_by: openerId,
      reason,
      description,
      evidence_urls: evidenceUrls,
    })
    .select()
    .single();
  if (error || !data) throw new Error(`openDispute failed: ${error?.message ?? 'no row'}`);
  return data as Dispute;
}

/** Admin reviews and resolves a dispute. */
export async function resolveDispute(
  env: Env,
  disputeId: string,
  adminId: string,
  resolution: 'resolved_refund' | 'resolved_reject',
  notes: string
): Promise<void> {
  const supabase = getSupabase(env);
  const { data: dispute } = await supabase
    .from('marketplace_disputes')
    .select('purchase_id')
    .eq('id', disputeId)
    .single();
  if (!dispute) throw new Error('Dispute not found');

  // Update dispute.
  await supabase
    .from('marketplace_disputes')
    .update({
      status: resolution,
      resolution_notes: notes,
      resolved_by: adminId,
      resolved_at: new Date().toISOString(),
    })
    .eq('id', disputeId);

  // Update purchase escrow status.
  const newEscrowStatus = resolution === 'resolved_refund' ? 'refunded' : 'released';
  await supabase
    .from('marketplace_purchases')
    .update({ escrow_status: newEscrowStatus })
    .eq('id', dispute.purchase_id);
}

/** Recompute seller reputation from reviews + sales + disputes. */
export async function recomputeSellerReputation(env: Env, sellerId: string): Promise<SellerReputation> {
  const supabase = getSupabase(env);

  const { data: listings } = await supabase
    .from('marketplace_listings')
    .select('id')
    .eq('seller_id', sellerId);
  const listingIds = (listings ?? []).map((l: any) => l.id);

  const { data: reviewRows } = listingIds.length > 0
    ? await supabase
        .from('marketplace_reviews')
        .select('stars')
        .in('listing_id', listingIds)
    : { data: [] };
  const reviewList = (reviewRows ?? []) as { stars: number }[];
  const avgStars = reviewList.length > 0
    ? reviewList.reduce((sum, r) => sum + r.stars, 0) / reviewList.length
    : 0;

  const { count: completedSales } = await supabase
    .from('marketplace_purchases')
    .select('id', { count: 'exact', head: true })
    .eq('seller_id', sellerId)
    .eq('escrow_status', 'released');

  const { count: disputeCount } = await supabase
    .from('marketplace_disputes')
    .select('id', { count: 'exact', head: true })
    .in('purchase_id', await supabase
      .from('marketplace_purchases')
      .select('id')
      .eq('seller_id', sellerId)
      .then(r => (r.data ?? []).map((p: any) => p.id))
    );

  const badges: string[] = [];
  if (avgStars >= 4.5 && reviewList.length >= 10) badges.push('top_rated');
  if (completedSales && completedSales >= 50) badges.push('verified_teacher');

  const reputation: SellerReputation = {
    seller_id: sellerId,
    average_stars: Math.round(avgStars * 100) / 100,
    review_count: reviewList.length,
    completed_sales: completedSales ?? 0,
    dispute_count: disputeCount ?? 0,
    badges,
  };

  await supabase
    .from('marketplace_seller_reputation')
    .upsert({
      ...reputation,
      updated_at: new Date().toISOString(),
    });
  return reputation;
}