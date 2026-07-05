import { describe, it, expect } from 'vitest';
import { validateContent, quickValidate } from './content-validator';

describe('content-validator', () => {
  it('validates a well-formed content object', () => {
    const content = {
      title: 'Technology and Society',
      passage: 'In recent years technology has transformed how we live and work and communicate with each other.',
      questions: [
        { question: 'Main idea?', options: ['A', 'B', 'C', 'D'], correct: 'B' },
      ],
    };
    const result = validateContent(content);
    expect(result.valid).toBe(true);
    expect(result.issues.filter((i) => i.type === 'error')).toHaveLength(0);
  });

  it('rejects content missing title', () => {
    const result = validateContent({ passage: 'no title here' });
    expect(result.valid).toBe(false);
    expect(result.issues.some((i) => i.field === 'title')).toBe(true);
  });

  it('flags inappropriate keywords as errors', () => {
    const result = validateContent({
      title: 'Test',
      passage: 'contains gambling reference',
    });
    expect(result.valid).toBe(false);
    expect(result.issues.some((i) => i.message.includes('gambling'))).toBe(true);
  });

  it('warns about bias indicators without failing validation', () => {
    const result = validateContent({
      title: 'Test',
      passage: 'all men are good at math',
    });
    expect(result.warnings.some((w) => w.includes('all men'))).toBe(true);
  });

  it('flags questions with fewer than 2 options', () => {
    const result = validateContent({
      title: 'Test',
      questions: [{ question: 'Q?', options: ['A'], correct: 'A' }],
    });
    expect(result.valid).toBe(false);
    expect(result.issues.some((i) => i.field.includes('options'))).toBe(true);
  });

  it('warns about very short passages', () => {
    const result = validateContent({
      title: 'Test',
      passage: 'too short',
    });
    expect(result.warnings.some((w) => w.includes('short'))).toBe(true);
  });

  it('warns about very long passages', () => {
    const longPassage = 'word '.repeat(2001).trim();
    const result = validateContent({ title: 'Test', passage: longPassage });
    expect(result.warnings.some((w) => w.includes('very long'))).toBe(true);
  });

  it('quickValidate returns only valid + warnings', () => {
    const result = quickValidate({ title: 'Test' });
    expect(result).toHaveProperty('valid');
    expect(result).toHaveProperty('warnings');
    expect(result.valid).toBe(true);
  });
});