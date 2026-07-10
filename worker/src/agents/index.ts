/**
 * Agent definitions registry — Task 1 (Wave 1).
 *
 * Exports all stub agents. Wave 2 tasks T15-T17 will replace the stubs with
 * full implementations (richer system prompts + eval test cases).
 */

import type { AgentDefinition } from './runtime';
import { curatorAgent } from './definitions/curator';
import { tutorAgent } from './definitions/tutor';
import { examinerAgent } from './definitions/examiner';
import { mentorAgent } from './definitions/mentor';

export const AGENTS: Record<string, AgentDefinition> = {
  curator: curatorAgent,
  tutor: tutorAgent,
  examiner: examinerAgent,
  mentor: mentorAgent,
};

export function getAgent(name: string): AgentDefinition {
  const def = AGENTS[name];
  if (!def) {
    throw new Error(`Unknown agent: ${name}. Available: ${Object.keys(AGENTS).join(', ')}`);
  }
  return def;
}

export function listAgents(): string[] {
  return Object.keys(AGENTS);
}