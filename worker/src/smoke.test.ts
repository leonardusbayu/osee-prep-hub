import { describe, it, expect } from 'vitest';

// Smoke test — verifies vitest is configured correctly and can run.
// Pattern matches EduBot's tests at D:\claude telegram bot\worker\src\services\*.test.ts
describe('smoke test', () => {
  it('vitest runs and assertions work', () => {
    expect(1 + 1).toBe(2);
  });

  it('environment is node (not jsdom)', () => {
    expect(typeof window).toBe('undefined');
  });

  it('TypeScript features work', () => {
    const greet = (name: string): string => `Hello, ${name}!`;
    expect(greet('OSEE')).toBe('Hello, OSEE!');
  });
});