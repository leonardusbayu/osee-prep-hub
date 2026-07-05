import type { Env } from '../types';

/**
 * R2 storage service — Task 7.3.
 *
 * Uploads audio/video files to Cloudflare R2 buckets.
 * Used for: speaking recordings (R2_AUDIO), video lessons (R2_VIDEOS).
 */

const AUDIO_ALLOWED_TYPES = ['audio/webm', 'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/m4a'];
const VIDEO_ALLOWED_TYPES = ['video/mp4', 'video/webm', 'video/ogg'];
const MAX_AUDIO_BYTES = 50 * 1024 * 1024; // 50 MB
const MAX_VIDEO_BYTES = 500 * 1024 * 1024; // 500 MB

export interface UploadResult {
  key: string;
  url: string;
  bucket: string;
  size: number;
  contentType: string;
}

/** Upload an audio file to R2_AUDIO bucket. Returns the R2 key + public URL. */
export async function uploadAudio(
  env: Env,
  file: File | ArrayBuffer,
  contentType: string,
  userId: string
): Promise<UploadResult> {
  if (!AUDIO_ALLOWED_TYPES.includes(contentType)) {
    throw new Error(`Unsupported audio type: ${contentType}. Allowed: ${AUDIO_ALLOWED_TYPES.join(', ')}`);
  }

  const bytes = file instanceof File ? await file.arrayBuffer() : file;
  if (bytes.byteLength > MAX_AUDIO_BYTES) {
    throw new Error(`Audio too large: ${bytes.byteLength} bytes (max ${MAX_AUDIO_BYTES})`);
  }

  // Generate unique key: audio/{userId}/{timestamp}-{random}.ext
  const ext = contentType.split('/')[1] ?? 'webm';
  const key = `audio/${userId}/${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext}`;

  // Upload to R2
  await env.R2_AUDIO.put(key, bytes, {
    httpMetadata: { contentType },
  });

  // Construct public URL (assumes R2 bucket has public access enabled)
  const url = `https://audio.osee.co.id/${key}`;

  return {
    key,
    url,
    bucket: 'osee-audio',
    size: bytes.byteLength,
    contentType,
  };
}

/** Upload a video file to R2_VIDEOS bucket. */
export async function uploadVideo(
  env: Env,
  file: File | ArrayBuffer,
  contentType: string,
  courseId: string
): Promise<UploadResult> {
  if (!VIDEO_ALLOWED_TYPES.includes(contentType)) {
    throw new Error(`Unsupported video type: ${contentType}. Allowed: ${VIDEO_ALLOWED_TYPES.join(', ')}`);
  }

  const bytes = file instanceof File ? await file.arrayBuffer() : file;
  if (bytes.byteLength > MAX_VIDEO_BYTES) {
    throw new Error(`Video too large: ${bytes.byteLength} bytes (max ${MAX_VIDEO_BYTES})`);
  }

  const ext = contentType.split('/')[1] ?? 'mp4';
  const key = `videos/${courseId}/${Date.now()}-${Math.random().toString(36).slice(2, 10)}.${ext}`;

  await env.R2_VIDEOS.put(key, bytes, {
    httpMetadata: { contentType },
  });

  const url = `https://video.osee.co.id/${key}`;

  return {
    key,
    url,
    bucket: 'osee-videos',
    size: bytes.byteLength,
    contentType,
  };
}

/** Get a presigned URL for direct upload from client (CORS-safe). */
export function getPresignedUploadUrl(
  env: Env,
  bucket: 'audio' | 'video',
  key: string,
  contentType: string,
  expiresIn = 3600
): string {
  // In production, this would use R2's S3-compatible API to generate a presigned URL.
  // For now, return the upload endpoint URL — the worker handles the actual upload.
  const bucketPath = bucket === 'audio' ? 'audio' : 'video';
  return `${env.WEBAPP_URL}/api/upload/${bucketPath}?key=${encodeURIComponent(key)}&content_type=${encodeURIComponent(contentType)}&expires=${expiresIn}`;
}