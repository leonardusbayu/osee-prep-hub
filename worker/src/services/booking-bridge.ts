import type { Env } from '../types';

/**
 * Official test booking bridge — Task 15.10.
 *
 * Bridges between Hub and osee.co.id booking system for official TOEFL/TOEIC
 * test bookings created through Hub orders. Hub calls osee.co.id API to
 * create / get / cancel bookings.
 *
 * The osee.co.id booking API is expected to expose:
 *   POST   {OSEE_BOOKING_API_URL}/booking        — create booking
 *   GET    {OSEE_BOOKING_API_URL}/booking/:id    — fetch status
 *   DELETE {OSEE_BOOKING_API_URL}/booking/:id    — cancel booking
 * Authenticated via the `X-Hub-Secret` header using OSEE_BOOKING_API_SECRET.
 *
 * For the student-facing "Book Official Test" CTA, the Hub does not proxy
 * dates — see GET /api/student/book-test which returns osee_booking_url only.
 */

export interface BookingInput {
  order_item_id: string;
  student_id: string;
  student_name: string;
  student_email: string;
  test_type: 'official_toefl' | 'official_toeic';
  date_preference?: string;
  notes?: string;
}

export interface BookingResult {
  booking_id: string;
  status: 'pending' | 'confirmed' | 'cancelled';
  date?: string;
  venue?: string;
  message?: string;
}

/** Create a booking on osee.co.id. */
export async function createBooking(env: Env, input: BookingInput): Promise<BookingResult> {
  const bookingUrl = `${env.OSEE_BOOKING_API_URL}/booking`;

  const response = await fetch(bookingUrl, {
    method: 'POST',
    headers: {
      'X-Hub-Secret': env.OSEE_BOOKING_API_SECRET,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      order_item_id: input.order_item_id,
      student_id: input.student_id,
      student_name: input.student_name,
      student_email: input.student_email,
      test_type: input.test_type,
      date_preference: input.date_preference,
      notes: input.notes,
      source: 'hub-bridge',
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Booking API error ${response.status}: ${errText}`);
  }

  return (await response.json()) as BookingResult;
}

/** Get booking status from osee.co.id. */
export async function getBookingStatus(env: Env, bookingId: string): Promise<BookingResult> {
  const url = `${env.OSEE_BOOKING_API_URL}/booking/${bookingId}`;
  const response = await fetch(url, {
    headers: { 'X-Hub-Secret': env.OSEE_BOOKING_API_SECRET },
  });
  if (!response.ok) {
    throw new Error(`Booking status API error ${response.status}`);
  }
  return (await response.json()) as BookingResult;
}

/** Cancel a booking on osee.co.id. */
export async function cancelBooking(env: Env, bookingId: string): Promise<void> {
  const url = `${env.OSEE_BOOKING_API_URL}/booking/${bookingId}`;
  const response = await fetch(url, {
    method: 'DELETE',
    headers: { 'X-Hub-Secret': env.OSEE_BOOKING_API_SECRET },
  });
  if (!response.ok) {
    throw new Error(`Cancel booking API error ${response.status}`);
  }
}