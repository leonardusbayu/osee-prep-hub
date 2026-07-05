/**
 * Content validation service — Task 6.4.
 *
 * Validates AI-generated content for:
 * - Appropriateness (no harmful/offensive content)
 * - Accuracy (format compliance, structure)
 * - Bias detection
 * - Format compliance (required fields present)
 *
 * Adapted from EduBot's content-validator.ts pattern at:
 * D:\claude telegram bot\worker\src\services\content-validator.ts
 */

export interface ValidationIssue {
  type: 'error' | 'warning';
  field: string;
  message: string;
}

export interface ValidationResult {
  valid: boolean;
  issues: ValidationIssue[];
  warnings: string[];
}

const INAPPROPRIATE_KEYWORDS = [
  'porn', 'sexual', 'drug', 'gambling', 'violence', 'weapon',
  'terrorist', 'extremist', 'hate', 'racist', 'sexist',
];

const BIAS_INDICATORS = [
  'all men', 'all women', 'all boys', 'all girls',
  'always', 'never', 'everyone knows', 'obviously',
];

/** Validate generated material content. */
export function validateContent(content: Record<string, unknown>): ValidationResult {
  const issues: ValidationIssue[] = [];
  const warnings: string[] = [];

  // 1. Required fields based on material type
  if (!content.title || typeof content.title !== 'string') {
    issues.push({ type: 'error', field: 'title', message: 'title (string) required' });
  }

  // 2. Check for inappropriate content
  const allText = JSON.stringify(content).toLowerCase();
  for (const keyword of INAPPROPRIATE_KEYWORDS) {
    if (allText.includes(keyword)) {
      issues.push({
        type: 'error',
        field: 'content',
        message: `Inappropriate keyword detected: "${keyword}"`,
      });
    }
  }

  // 3. Bias detection (warning, not error)
  for (const indicator of BIAS_INDICATORS) {
    if (allText.includes(indicator)) {
      warnings.push(`Potential bias indicator: "${indicator}" — review for overgeneralization`);
    }
  }

  // 4. Structure validation — questions should have correct shape
  if (Array.isArray(content.questions)) {
    for (let i = 0; i < content.questions.length; i++) {
      const q = content.questions[i] as Record<string, unknown>;
      if (!q.question || typeof q.question !== 'string') {
        issues.push({ type: 'error', field: `questions[${i}].question`, message: 'question string required' });
      }
      if (Array.isArray(q.options)) {
        if (q.options.length < 2) {
          issues.push({ type: 'error', field: `questions[${i}].options`, message: 'at least 2 options required' });
        }
      }
      if (!q.correct) {
        warnings.push(`questions[${i}]: no correct answer specified`);
      }
    }
  }

  // 5. Word count check (if specified)
  if (content.passage && typeof content.passage === 'string') {
    const wordCount = content.passage.split(/\s+/).length;
    if (wordCount < 50) {
      warnings.push(`Passage is short (${wordCount} words) — may not be sufficient for practice`);
    }
    if (wordCount > 2000) {
      warnings.push(`Passage is very long (${wordCount} words) — may exceed time limits`);
    }
  }

  return {
    valid: issues.filter((i) => i.type === 'error').length === 0,
    issues,
    warnings,
  };
}

/** Validate generated content + return only valid flag + warnings (simplified). */
export function quickValidate(content: Record<string, unknown>): {
  valid: boolean;
  warnings: string[];
} {
  const result = validateContent(content);
  return { valid: result.valid, warnings: result.warnings };
}