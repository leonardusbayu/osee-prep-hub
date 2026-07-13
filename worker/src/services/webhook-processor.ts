import type { Env } from '../types';
import { getSupabase } from './supabase';
import { updateStudentProgress } from './student-progress';
import { recordCommission } from './commission';
import { awardQuotaBonus } from './quota';

/**
 * Webhook event processing pipeline.
 *
 * Reads unprocessed webhook_events in order (FIFO by created_at),
 * processes each based on platform + event_type:
 *   - practice_completed → update student_progress_unified
 *   - test_booked → create commission entry
 *   - test_completed → update progress + commission
 *   - booking_confirmed → no-op (status update only)
 *
 * Marks each event as processed=true with optional error_message on failure.
 */

interface WebhookEventRow {
  id: string;
  platform: string;
  event_type: string;
  user_email: string | null;
  user_id: string | null;
  payload: Record<string, unknown>;
  created_at: string;
}

export interface ProcessResult {
  total: number;
  succeeded: number;
  failed: number;
  errors: Array<{ event_id: string; error: string }>;
}

/** Process a batch of unprocessed webhook events. Returns summary. */
export async function processWebhookBatch(env: Env, batchSize = 100): Promise<ProcessResult> {
  const supabase = getSupabase(env);

  // Read unprocessed events in FIFO order
  const { data: events, error: fetchError } = await supabase
    .from('webhook_events')
    .select('*')
    .eq('processed', false)
    .order('created_at', { ascending: true })
    .limit(batchSize);

  if (fetchError) {
    throw new Error(`Failed to fetch webhook events: ${fetchError.message}`);
  }

  const result: ProcessResult = {
    total: events?.length ?? 0,
    succeeded: 0,
    failed: 0,
    errors: [],
  };

  if (!events || events.length === 0) {
    return result;
  }

  for (const event of events as WebhookEventRow[]) {
    try {
      await processSingleEvent(env, event);
      result.succeeded++;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Unknown error';
      result.failed++;
      result.errors.push({ event_id: event.id, error: message });
      // Mark as processed with error (don't block queue)
      await markProcessed(supabase, event.id, message);
    }
  }

  return result;
}

/** Process a single webhook event. Throws on failure. */
async function processSingleEvent(env: Env, event: WebhookEventRow): Promise<void> {
  const supabase = getSupabase(env);

  // Resolve user_id from user_email if needed
  let userId = event.user_id;
  if (!userId && event.user_email) {
    const { data: user } = await supabase
      .from('unified_profiles')
      .select('id')
      .eq('email', event.user_email.toLowerCase())
      .maybeSingle();
    if (user) {
      userId = user.id as string;
    }
  }

  if (!userId) {
    throw new Error(`Could not resolve user for event ${event.id}`);
  }

  // Dispatch to handler based on event_type
  switch (event.event_type) {
    case 'practice_completed':
    case 'test_completed':
      await updateStudentProgress(env, {
        user_id: userId,
        platform: event.platform,
        event_type: event.event_type,
        payload: event.payload,
      });
      // Also check for commission trigger (first practice = Rp 10k)
      const commissionRec1 = await recordCommissionAndReturnTeacher(env, {
        user_id: userId,
        event_type: event.event_type,
        platform: event.platform,
        payload: event.payload,
      });
      // Award quota bonus to teacher (Task 12.4) — +5 generation credits
      if (commissionRec1) {
        await awardQuotaBonus(env, commissionRec1, 'test_completed').catch(() => {});
      }
      break;

    case 'test_booked':
      // Booking triggers commission (Rp 50k to teacher)
      const commissionRec2 = await recordCommissionAndReturnTeacher(env, {
        user_id: userId,
        event_type: 'test_booked',
        platform: event.platform,
        payload: event.payload,
      });
      // Award quota bonus — +10 generation credits for official booking
      if (commissionRec2) {
        await awardQuotaBonus(env, commissionRec2, 'official_booking').catch(() => {});
      }
      break;

    case 'booking_confirmed':
    case 'booking_cancelled':
      // Status updates — no action needed (commission already recorded on test_booked)
      break;

    case 'bot_session_started':
      // EduBot session — no commission, no progress update needed
      break;

    case 'premium_subscribed':
      // EduBot premium subscription — commission + quota bonus
      const commissionRec3 = await recordCommissionAndReturnTeacher(env, {
        user_id: userId,
        event_type: 'premium_subscribed',
        platform: event.platform,
        payload: event.payload,
      });
      if (commissionRec3) {
        await awardQuotaBonus(env, commissionRec3, 'premium_subscribed').catch(() => {});
      }
      break;

    default:
      // Unknown event type — log warning but don't fail
      console.warn(`Unknown webhook event_type: ${event.event_type}`);
      break;
  }

  // Mark as successfully processed
  await markProcessed(supabase, event.id, null);
}

/**
 * Record commission and return the teacher_id who earned it (or null if no
 * referring teacher). Wraps recordCommission with a lookup.
 */
async function recordCommissionAndReturnTeacher(
  env: Env,
  input: { user_id: string; event_type: string; platform: string; payload: Record<string, unknown> }
): Promise<string | null> {
  // Find the student's referring teacher
  const supabase = getSupabase(env);
  const { data: student } = await supabase
    .from('unified_profiles')
    .select('referred_by')
    .eq('id', input.user_id)
    .maybeSingle();
  const teacherId = (student as Record<string, unknown> | null)?.referred_by as string | null;
  if (!teacherId) return null;

  // Record commission (idempotent)
  await recordCommission(env, input).catch((err) => {
    console.error('recordCommission failed:', err);
  });
  return teacherId;
}

/** Mark a webhook event as processed. error_message is null on success. */
async function markProcessed(
  supabase: import('@supabase/supabase-js').SupabaseClient,
  eventId: string,
  errorMessage: string | null
): Promise<void> {
  const { error } = await supabase
    .from('webhook_events')
    .update({
      processed: true,
      processed_at: new Date().toISOString(),
      error_message: errorMessage,
    })
    .eq('id', eventId);
  if (error) {
    console.error(`Failed to mark event ${eventId} as processed:`, error);
  }
}