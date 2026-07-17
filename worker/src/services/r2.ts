import type { Env } from '../types';

/**
 * R2 storage service — Task 7.3.
 *
 * Uploads audio/video files to Cloudflare R2 buckets.
 * Used for: speaking recordings (R2_AUDIO), video lessons (R2_VIDEOS).
 *
 * Presigned URLs are generated via the S3 Signature V4 algorithm using
 * the Web Crypto API (HMAC-SHA256) — no external SDK required. R2's
 * S3-compatible API endpoint is https://<account_id>.r2.cloudflarestorage.com.
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

// ---------- S3 Signature V4 presigned URL generation ----------

/**
 * Get a presigned URL for direct upload from client (CORS-safe).
 * Uses the AWS Signature V4 algorithm against R2's S3-compatible API.
 * Requires R2_ACCESS_KEY_ID + R2_SECRET_ACCESS_KEY env vars (S3 tokens,
 * not the Wrangler binding). The client PUTs directly to R2, bypassing
 * the Worker — reducing Worker CPU time and latency for large uploads.
 */
export async function getPresignedUploadUrl(
  env: Env,
  bucket: 'audio' | 'video',
  key: string,
  contentType: string,
  expiresIn = 3600
): Promise<string> {
  const accessKeyId = (env as unknown as Record<string, unknown>).R2_ACCESS_KEY_ID as string | undefined;
  const secretAccessKey = (env as unknown as Record<string, unknown>).R2_SECRET_ACCESS_KEY as string | undefined;
  const accountId = (env as unknown as Record<string, unknown>).R2_ACCOUNT_ID as string | undefined;

  if (!accessKeyId || !secretAccessKey || !accountId) {
    // Fallback: if S3 creds aren't configured, return the worker-mediated
    // upload endpoint so the app still works (the worker proxies the upload).
    const bucketPath = bucket === 'audio' ? 'audio' : 'video';
    return `${env.WEBAPP_URL}/api/upload/${bucketPath}?key=${encodeURIComponent(key)}&content_type=${encodeURIComponent(contentType)}&expires=${expiresIn}`;
  }

  const bucketName = bucket === 'audio' ? 'osee-audio' : 'osee-videos';
  const region = 'auto';
  const service = 's3';
  const host = `${bucketName}.${accountId}.r2.cloudflarestorage.com`;
  const now = new Date();
  const amzDate = now.toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z');
  const dateStamp = amzDate.slice(0, 8);

  // Canonical request
  const canonicalUri = `/${key}`;
  const canonicalQueryString = [
    ['X-Amz-Algorithm', 'AWS4-HMAC-SHA256'],
    ['X-Amz-Credential', `${accessKeyId}/${dateStamp}/${region}/${service}/aws4_request`],
    ['X-Amz-Date', amzDate],
    ['X-Amz-Expires', String(expiresIn)],
    ['X-Amz-SignedHeaders', 'content-type;host'],
  ].map(([k, v]) => `${uriEncode(k)}=${uriEncode(v)}`).join('&');

  const canonicalHeaders = `content-type:${contentType}\nhost:${host}\n`;
  const signedHeaders = 'content-type;host';
  const payloadHash = 'UNSIGNED-PAYLOAD';
  const canonicalRequest = [
    'PUT', canonicalUri, canonicalQueryString, canonicalHeaders, signedHeaders, payloadHash,
  ].join('\n');

  // String to sign
  const scope = `${dateStamp}/${region}/${service}/aws4_request`;
  const stringToSign = [
    'AWS4-HMAC-SHA256', amzDate, scope, await sha256Hex(canonicalRequest),
  ].join('\n');

  // Signing key
  const kDate = await hmacSha256(`AWS4${secretAccessKey}`, dateStamp);
  const kRegion = await hmacSha256Hex(kDate, region);
  const kService = await hmacSha256Hex(kRegion, service);
  const kSigning = await hmacSha256Hex(kService, 'aws4_request');
  const signature = await hmacSha256Hex(kSigning, stringToSign);

  return `https://${host}${canonicalUri}?${canonicalQueryString}&X-Amz-Signature=${signature}`;
}

function uriEncode(s: string): string {
  return encodeURIComponent(s).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

async function sha256Hex(data: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(data));
  return bufToHex(buf);
}

async function hmacSha256(key: string | ArrayBuffer, data: string): Promise<ArrayBuffer> {
  const keyBytes = typeof key === 'string' ? new TextEncoder().encode(key) : key;
  return crypto.subtle.sign('HMAC', await crypto.subtle.importKey('raw', keyBytes, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']), new TextEncoder().encode(data));
}

async function hmacSha256Hex(key: string | ArrayBuffer, data: string): Promise<string> {
  return bufToHex(await hmacSha256(key, data));
}

function bufToHex(buf: ArrayBuffer): string {
  return Array.from(new Uint8Array(buf), (b) => b.toString(16).padStart(2, '0')).join('');
}