/**
 * OSEE Prep Hub — TypeScript type definitions
 *
 * Env bindings for Cloudflare Workers + Hono context variables.
 * Adapted from EduBot's worker/src/types.ts pattern.
 */

/** Cloudflare Workers environment bindings. */
export interface Env {
  // Supabase
  SUPABASE_URL: string;
  SUPABASE_ANON_KEY: string;
  SUPABASE_SERVICE_KEY: string;

  // JWT
  JWT_SECRET: string;
  JWT_EXPIRY: string; // e.g. "7d"

  // OpenAI
  OPENAI_API_KEY: string;

  // EduBot bridge
  EDUBOT_API_URL: string;
  EDUBOT_INTERNAL_SECRET: string;

  // Webhook secrets (one per platform)
  WEBHOOK_SECRET_IBT: string;
  WEBHOOK_SECRET_ITP: string;
  WEBHOOK_SECRET_IELTS: string;
  WEBHOOK_SECRET_TOEIC: string;
  WEBHOOK_SECRET_BOOKING: string;
  WEBHOOK_SECRET_EDUBOT: string;

  // Frontend URL
  WEBAPP_URL: string;

  // R2 storage
  R2_VIDEOS: R2Bucket;
  R2_AUDIO: R2Bucket;

  // Payment (TriPay)
  TRIPAY_API_KEY: string;
  TRIPAY_PRIVATE_KEY: string;
  TRIPAY_MERCHANT_CODE: string;

  // Telegram (EduBot bridge for live class notifications)
  TELEGRAM_BOT_TOKEN: string;
  TELEGRAM_CHANNEL_ID: string;

  // OSEE booking bridge (official tests)
  OSEE_BOOKING_API_URL: string;
  OSEE_BOOKING_API_SECRET: string;

  // Environment
  ENVIRONMENT: 'development' | 'staging' | 'production';
}

/** User roles supported by the platform. */
export type UserRole = 'student' | 'teacher' | 'partner' | 'admin';

/** User record from unified_profiles table. */
export interface User {
  id: string;
  email: string;
  display_name: string;
  role: UserRole;
  avatar_url: string | null;
  telegram_id: string | null;
  target_exam: string | null;
  target_score: Record<string, unknown> | null;
  current_level: string | null;
  created_at: string;
  updated_at: string;
}

/** JWT payload structure. */
export interface JwtPayload {
  sub: string; // user ID
  email: string;
  role: UserRole;
  exp: number; // expiration (Unix seconds)
  iat: number; // issued at (Unix seconds)
}

/** Orderable item types (matches pricing_config + order_items schema). */
export type ItemType =
  | 'mock_itp'
  | 'mock_ibt'
  | 'mock_ielts'
  | 'mock_toeic'
  | 'tutor_bot_premium'
  | 'official_toefl'
  | 'official_toeic';

/** Order types (matches orders schema). */
export type OrderType =
  | 'voucher_resale'
  | 'book_for_student'
  | 'bulk_purchase'
  | 'self_purchase';

/** Order status (matches orders schema). */
export type OrderStatus =
  | 'pending'
  | 'paid'
  | 'fulfilled'
  | 'cancelled'
  | 'refunded';

/** Voucher status (matches vouchers schema). */
export type VoucherStatus = 'active' | 'redeemed' | 'expired' | 'cancelled';

/** Webhook event types from practice platforms. */
export type WebhookEventType =
  | 'practice_completed'
  | 'test_booked'
  | 'test_completed'
  | 'bot_session_started'
  | 'booking_confirmed'
  | 'booking_cancelled';

/** Webhook event payload from practice platforms. */
export interface WebhookEvent {
  platform: 'ibt' | 'itp' | 'ielts' | 'toeic' | 'booking' | 'edubot';
  event_type: WebhookEventType;
  student_id: string;
  timestamp: string;
  data: Record<string, unknown>;
}

/** Standard API error response shape. */
export interface ApiError {
  error: {
    code: string;
    message: string;
    requestId?: string;
  };
}

/** Hono context variables set by middleware. */
export interface ContextVars {
  user: User | null;
}