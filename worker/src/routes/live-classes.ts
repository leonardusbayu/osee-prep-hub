/**
 * Live class routes — T12 (Wave 2).
 *
 * POST /api/live-classes                     — teacher schedules a class
 * POST /api/live-classes/:id/join            — get LiveKit JWT for joining
 * POST /api/live-classes/:id/end             — teacher ends the class
 *
 * Skeleton: endpoints exist, JWT is mocked. Real impl requires LiveKit
 * credentials + livekit_client Flutter package + R2 recording webhook.
 */

import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { generateLivekitJwt } from '../services/live-class';

export const liveClassRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

liveClassRoutes.use('*', requireAuth());

/** POST /api/live-classes — schedule a class. */
liveClassRoutes.post('/', async (c) => {
  const user = getAuthedUser(c);
  if (!['teacher', 'admin'].includes(user.role)) {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Teachers only' } }, 403);
  }
  let body: { syllabusId?: string; scheduledAt?: string; durationMinutes?: number };
  try { body = await c.req.json(); } catch {
    return c.json({ error: { code: 'BAD_REQUEST', message: 'Invalid JSON' } }, 400);
  }
  if (!body.syllabusId || !body.scheduledAt || !body.durationMinutes) {
    return c.json({ error: { code: 'INVALID_INPUT', message: 'syllabusId, scheduledAt, durationMinutes required' } }, 400);
  }

  const roomName = `syllabus-${body.syllabusId}-${Date.now()}`;
  // TODO: persist to live_classes table.
  return c.json({
    liveClass: {
      id: crypto.randomUUID(),
      syllabus_id: body.syllabusId,
      teacher_id: user.id,
      scheduled_at: body.scheduledAt,
      duration_minutes: body.durationMinutes,
      livekit_room_name: roomName,
      status: 'scheduled',
      recording_url: null,
      created_at: new Date().toISOString(),
    },
  }, 201);
});

/** POST /api/live-classes/:id/join — get LiveKit JWT. */
liveClassRoutes.post('/:id/join', async (c) => {
  const user = getAuthedUser(c);
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);

  // TODO: load live class by ID, get room name.
  const roomName = `live-${id}`;
  const jwt = generateLivekitJwt(c.env, roomName, user.id, user.display_name ?? 'User');
  return c.json({
    token: jwt,
    url: 'wss://livekit.example.com', // TODO: from env
    roomName,
  });
});

/** POST /api/live-classes/:id/end */
liveClassRoutes.post('/:id/end', async (c) => {
  const id = c.req.param('id');
  if (!id) return c.json({ error: { code: 'BAD_REQUEST', message: 'id required' } }, 400);

  // TODO: verify teacher owns the class + trigger LiveKit room close +
  // fetch recording from R2.
  return c.json({
    liveClassId: id,
    status: 'ended',
    endedAt: new Date().toISOString(),
  });
});