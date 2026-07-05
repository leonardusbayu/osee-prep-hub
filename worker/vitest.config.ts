import { defineConfig } from 'vitest/config';

// Plain Node vitest — matches EduBot's pattern.
// We don't need the Workers runtime for pure-function tests (scoring math,
// validation, queue logic). Tests that need D1/R2 bindings mock them inline.
// If we later want to test the full request path including Workers APIs,
// add @cloudflare/vitest-pool-workers and a separate config file for those.
export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
    testTimeout: 10_000,
  },
});