import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { uploadAudio, uploadVideo } from '../services/r2';

export const uploadRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

uploadRoutes.use('*', requireAuth());

/** POST /api/upload/audio — upload audio recording to R2 (Task 7.3) */
uploadRoutes.post('/audio', async (c) => {
  const user = getAuthedUser(c);

  const contentType = c.req.header('Content-Type') ?? '';
  if (!contentType.startsWith('audio/')) {
    // Check if multipart form
    const formData = await c.req.formData();
    const file = formData.get('file') as File | null;
    if (!file) {
      return c.json({ error: { code: 'NO_FILE', message: 'audio file required' } }, 400);
    }
    try {
      const result = await uploadAudio(c.env, file, file.type, user.id);
      return c.json(result, 201);
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Upload failed';
      return c.json({ error: { code: 'UPLOAD_FAILED', message } }, 400);
    }
  }

  // Direct binary upload
  const body = await c.req.arrayBuffer();
  try {
    const result = await uploadAudio(c.env, body, contentType, user.id);
    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Upload failed';
    return c.json({ error: { code: 'UPLOAD_FAILED', message } }, 400);
  }
});

/** POST /api/upload/video — upload video to R2 (admin-only) */
uploadRoutes.post('/video', async (c) => {
  const user = getAuthedUser(c);
  if (user.role !== 'admin' && user.role !== 'partner') {
    return c.json({ error: { code: 'FORBIDDEN', message: 'Admin or partner role required' } }, 403);
  }

  let courseId: string | undefined;
  let file: File | null = null;

  const contentType = c.req.header('Content-Type') ?? '';
  if (contentType.startsWith('multipart/form-data')) {
    const formData = await c.req.formData();
    courseId = (formData.get('course_id') as string) ?? undefined;
    const f = formData.get('file') as File | null;
    if (f) file = f;
  } else {
    // Direct binary — course_id from query param
    courseId = c.req.query('course_id') ?? 'general';
    const body = await c.req.arrayBuffer();
    file = new File([body], 'video', { type: contentType });
  }

  if (!file) {
    return c.json({ error: { code: 'NO_FILE', message: 'video file required' } }, 400);
  }

  try {
    const result = await uploadVideo(c.env, file, file.type, courseId ?? 'general');
    return c.json(result, 201);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Upload failed';
    return c.json({ error: { code: 'UPLOAD_FAILED', message } }, 400);
  }
});