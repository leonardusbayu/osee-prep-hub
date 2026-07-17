import { describe, it, expect, vi, beforeEach } from 'vitest';
import { uploadAudio, uploadVideo, getPresignedUploadUrl } from './r2';
import type { Env } from '../types';

// Mock R2 bucket
const mockPut = vi.fn();
const mockR2Audio = { name: 'osee-audio', put: mockPut };
const mockR2Videos = { name: 'osee-videos', put: vi.fn() };

const mockEnv = {
  R2_AUDIO: mockR2Audio,
  R2_VIDEOS: mockR2Videos,
  WEBAPP_URL: 'http://localhost:8787',
} as unknown as Env;

describe('r2 service', () => {
  beforeEach(() => {
    mockPut.mockClear();
    (mockR2Videos.put as ReturnType<typeof vi.fn>).mockClear();
  });

  it('uploads audio to R2_AUDIO bucket with correct key', async () => {
    mockPut.mockResolvedValueOnce({});

    const audioBytes = new ArrayBuffer(1024);
    const result = await uploadAudio(mockEnv, audioBytes, 'audio/webm', 'user-123');

    expect(result.bucket).toBe('osee-audio');
    expect(result.contentType).toBe('audio/webm');
    expect(result.size).toBe(1024);
    expect(result.key).toMatch(/^audio\/user-123\/\d+-[a-z0-9]+\.webm$/);
    expect(result.url).toContain(result.key);
    expect(mockPut).toHaveBeenCalledOnce();
    const [key, bytes, opts] = mockPut.mock.calls[0];
    expect(key).toBe(result.key);
    expect(bytes).toBe(audioBytes);
    expect(opts.httpMetadata.contentType).toBe('audio/webm');
  });

  it('rejects unsupported audio type', async () => {
    await expect(
      uploadAudio(mockEnv, new ArrayBuffer(10), 'text/plain', 'user')
    ).rejects.toThrow(/Unsupported audio type/);
  });

  it('rejects audio over 50MB', async () => {
    const big = new ArrayBuffer(51 * 1024 * 1024);
    await expect(
      uploadAudio(mockEnv, big, 'audio/webm', 'user')
    ).rejects.toThrow(/Audio too large/);
  });

  it('uploads video to R2_VIDEOS bucket', async () => {
    (mockR2Videos.put as ReturnType<typeof vi.fn>).mockResolvedValueOnce({});

    const videoBytes = new ArrayBuffer(1024 * 1024); // 1 MB
    const result = await uploadVideo(mockEnv, videoBytes, 'video/mp4', 'course-1');

    expect(result.bucket).toBe('osee-videos');
    expect(result.contentType).toBe('video/mp4');
    expect(result.size).toBe(1024 * 1024);
    expect(result.key).toMatch(/^videos\/course-1\/\d+-[a-z0-9]+\.mp4$/);
  });

  it('rejects unsupported video type', async () => {
    await expect(
      uploadVideo(mockEnv, new ArrayBuffer(10), 'text/plain', 'course')
    ).rejects.toThrow(/Unsupported video type/);
  });

  it('rejects video over 500MB', async () => {
    const big = new ArrayBuffer(501 * 1024 * 1024);
    await expect(
      uploadVideo(mockEnv, big, 'video/mp4', 'course')
    ).rejects.toThrow(/Video too large/);
  });

  it('generates presigned upload URL (falls back to worker-mediated endpoint when S3 creds missing)', async () => {
    const url = await getPresignedUploadUrl(
      mockEnv,
      'audio',
      'audio/user1/test.webm',
      'audio/webm',
      3600
    );
    expect(url).toContain('/api/upload/audio');
    expect(url).toContain('key=audio%2Fuser1%2Ftest.webm');
    expect(url).toContain('content_type=audio%2Fwebm');
    expect(url).toContain('expires=3600');
  });

  it('generates a real S3 presigned URL when R2 S3 creds are configured', async () => {
    const envWithCreds = {
      ...mockEnv,
      R2_ACCESS_KEY_ID: 'test-access-key',
      R2_SECRET_ACCESS_KEY: 'test-secret-key',
      R2_ACCOUNT_ID: 'testaccountid',
    } as unknown as Env;
    const url = await getPresignedUploadUrl(
      envWithCreds,
      'audio',
      'audio/user1/test.webm',
      'audio/webm',
      3600
    );
    expect(url).toContain('r2.cloudflarestorage.com');
    expect(url).toContain('X-Amz-Algorithm=AWS4-HMAC-SHA256');
    expect(url).toContain('X-Amz-Signature=');
    expect(url).toContain('X-Amz-Credential=test-access-key%2F');
  });
});