import '@testing-library/jest-dom/vitest';
import { afterEach, vi } from 'vitest';
import { cleanup } from '@testing-library/react';

afterEach(() => {
  cleanup();
  localStorage.clear();
  vi.unstubAllGlobals();
});

// Default fetch stub — individual tests override via vi.stubGlobal('fetch', ...).
globalThis.fetch = vi.fn(async () =>
  new Response('{}', { status: 200, headers: { 'Content-Type': 'application/json' } })
) as unknown as typeof fetch;