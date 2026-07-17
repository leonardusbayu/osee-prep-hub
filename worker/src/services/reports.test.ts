import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { Env } from '../types';

const hoisted = vi.hoisted(() => {
  const chainPlan: Array<{ data?: unknown; error?: unknown }> = [];
  return { chainPlan };
});

vi.mock('../services/supabase', () => {
  const consume = () => hoisted.chainPlan.shift() ?? { data: null, error: null };
  const makeChain = () => {
    let consumed: { data?: unknown; error?: unknown } | null = null;
    const getResolved = () => (consumed ??= consume());
    const chain = {
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      neq: vi.fn(() => chain),
      order: vi.fn(() => chain),
      insert: vi.fn(() => chain),
      update: vi.fn(() => chain),
      delete: vi.fn(() => chain),
      limit: vi.fn(() => chain),
      in: vi.fn(() => chain),
      maybeSingle: vi.fn(async () => getResolved()),
      single: vi.fn(async () => getResolved()),
      get data() { return getResolved().data; },
      get error() { return getResolved().error; },
    };
    (chain as unknown as { then: (resolve: (v: unknown) => unknown) => Promise<unknown> }).then =
      (resolve) => Promise.resolve(getResolved()).then(resolve);
    return chain;
  };
  return { getSupabase: vi.fn(() => ({ from: vi.fn(() => makeChain()) })) };
});

import {
  generateStudentReport,
  generateClassroomReport,
  generateBatchStudentReports,
  getTeacherEffectiveness,
} from './reports';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('reports service', () => {
  beforeEach(() => {
    hoisted.chainPlan.length = 0;
  });

  describe('generateStudentReport', () => {
    it('throws when teacher does not own student', async () => {
      hoisted.chainPlan.push({ data: [{ classroom: { teacher_id: 'other' } }], error: null });
      await expect(generateStudentReport(mockEnv, 'teacher-1', 'stu-1')).rejects.toThrow(/Not authorized/);
    });

    it('allows student to view own report', async () => {
      // teacherOwnsStudent false but teacherId === studentId
      hoisted.chainPlan.push({ data: [{ classroom: { teacher_id: 'other' } }], error: null });
      hoisted.chainPlan.push({ data: { id: 'stu-1', display_name: 'Self', email: 's@e.com', target_exam: 'TOEFL_IBT', current_level: 'B1' }, error: null });
      hoisted.chainPlan.push({ data: null, error: null }); // progress
      hoisted.chainPlan.push({ data: [], error: null }); // recent events
      const r = await generateStudentReport(mockEnv, 'stu-1', 'stu-1');
      expect(r.student.id).toBe('stu-1');
      expect(r.student.name).toBe('Self');
      expect(r.progress.ibt_latest_score).toBeNull();
      expect(r.weaknesses).toEqual([]);
      expect(r.recent_activity).toEqual([]);
    });

    it('throws when student not found', async () => {
      hoisted.chainPlan.push({ data: [{ classroom: { teacher_id: 'teacher-1' } }], error: null });
      hoisted.chainPlan.push({ data: null, error: { message: 'no row' } });
      await expect(generateStudentReport(mockEnv, 'teacher-1', 'missing')).rejects.toThrow(/Student not found/);
    });

    it('aggregates scores and detects weaknesses below 50', async () => {
      hoisted.chainPlan.push({ data: [{ classroom: { teacher_id: 'teacher-1' } }], error: null });
      hoisted.chainPlan.push({
        data: { id: 'stu-1', display_name: 'S', email: 's@e.com', target_exam: 'IELTS', current_level: 'B2' },
        error: null,
      });
      hoisted.chainPlan.push({
        data: {
          ibt_latest_score: 40, itp_latest_score: 80, ielts_latest_band: 7, toeic_latest_score: null,
          ibt_practice_count: 2, itp_practice_count: 1, ielts_practice_count: 3, toeic_practice_count: 0,
          edubot_streak_days: 5,
        },
        error: null,
      });
      hoisted.chainPlan.push({ data: [{ event_type: 'test_completed', platform: 'ibt', created_at: '2024-01-01' }], error: null });
      const r = await generateStudentReport(mockEnv, 'teacher-1', 'stu-1');
      expect(r.progress.ibt_latest_score).toBe(40);
      expect(r.progress.itp_latest_score).toBe(80);
      expect(r.progress.ielts_latest_band).toBe(7);
      expect(r.progress.toeic_latest_score).toBeNull();
      expect(r.progress.total_practice_count).toBe(6);
      // Weaknesses: code compares raw scores < 50 across all platforms, so
      // IBT=40 and IELTS=7 both trip the threshold (IETLTS band scale differs).
      expect(r.weaknesses).toHaveLength(2);
      expect(r.weaknesses.map((w) => w.area).sort()).toEqual(['IBT', 'IELTS']);
      expect(r.recent_activity).toHaveLength(1);
    });
  });

  describe('generateClassroomReport', () => {
    it('throws when classroom not owned', async () => {
      hoisted.chainPlan.push({ data: null, error: null });
      await expect(generateClassroomReport(mockEnv, 'teacher-1', 'cls-x')).rejects.toThrow(/not found or not owned/);
    });

    it('aggregates classroom stats', async () => {
      hoisted.chainPlan.push({ data: { id: 'cls-1', name: 'Class A', teacher_id: 'teacher-1' }, error: null });
      hoisted.chainPlan.push({
        data: [
          { student: { id: 's1', display_name: 'Al' } },
          { student: { id: 's2', display_name: 'Bo' } },
        ],
        error: null,
      });
      // progress per student (2 calls via Promise.all)
      hoisted.chainPlan.push({
        data: { ibt_latest_score: 55, itp_latest_score: 65, ielts_latest_band: null, toeic_latest_score: null,
          ibt_practice_count: 1, itp_practice_count: 0, ielts_practice_count: 0, toeic_practice_count: 0 },
        error: null,
      });
      hoisted.chainPlan.push({
        data: { ibt_latest_score: 40, itp_latest_score: null, ielts_latest_band: null, toeic_latest_score: null,
          ibt_practice_count: 2, itp_practice_count: 0, ielts_practice_count: 0, toeic_practice_count: 0 },
        error: null,
      });

      const r = await generateClassroomReport(mockEnv, 'teacher-1', 'cls-1');
      expect(r.classroom.id).toBe('cls-1');
      expect(r.summary.total_students).toBe(2);
      expect(r.summary.active_students).toBe(2);
      expect(r.students).toHaveLength(2);
      // common weakness IBT appears for both (40 and 55... 55 not <60, only 40)
      // Only one student <60 → not >= floor(2/3)=1 actually 1>=1 true, IBT becomes common weakness
      expect(r.summary.common_weaknesses).toContain('IBT');
    });
  });

  describe('generateBatchStudentReports', () => {
    it('throws when classroom not owned', async () => {
      hoisted.chainPlan.push({ data: null, error: null });
      await expect(generateBatchStudentReports(mockEnv, 'teacher-1', 'cls-x')).rejects.toThrow(/not found or not owned/);
    });

    it('returns per-student report entries', async () => {
      hoisted.chainPlan.push({ data: { id: 'cls-1', name: 'A', teacher_id: 'teacher-1' }, error: null });
      hoisted.chainPlan.push({ data: [{ student: { id: 's1', display_name: 'Al' } }], error: null });
      // generateStudentReport internals: enrollment check, student lookup, progress, events
      hoisted.chainPlan.push({ data: [{ classroom: { teacher_id: 'teacher-1' } }], error: null });
      hoisted.chainPlan.push({ data: { id: 's1', display_name: 'Al', email: 'a@e.com', target_exam: null, current_level: null }, error: null });
      hoisted.chainPlan.push({ data: null, error: null });
      hoisted.chainPlan.push({ data: [], error: null });

      const r = await generateBatchStudentReports(mockEnv, 'teacher-1', 'cls-1');
      expect(r).toHaveLength(1);
      expect(r[0].student_id).toBe('s1');
      expect(r[0].report).not.toBeNull();
    });

    it('collects per-student errors without aborting batch', async () => {
      hoisted.chainPlan.push({ data: { id: 'cls-1', name: 'A', teacher_id: 'teacher-1' }, error: null });
      hoisted.chainPlan.push({ data: [{ student: { id: 's1', display_name: 'Al' } }], error: null });
      // generateStudentReport: enrollment check fails (not owned)
      hoisted.chainPlan.push({ data: [{ classroom: { teacher_id: 'other' } }], error: null });
      // Note: throws before further queries

      const r = await generateBatchStudentReports(mockEnv, 'teacher-1', 'cls-1');
      expect(r[0].report).toBeNull();
      expect(r[0].error).toMatch(/Not authorized/);
    });
  });

  describe('getTeacherEffectiveness', () => {
    it('throws when classroom not found', async () => {
      hoisted.chainPlan.push({ data: null, error: null });
      await expect(getTeacherEffectiveness(mockEnv, 'teacher-1', 'cls-x')).rejects.toThrow(/Classroom not found/);
    });

    it('returns zeros when classroom has no students', async () => {
      hoisted.chainPlan.push({ data: { id: 'cls-1', teacher_id: 'teacher-1', created_at: '2024-01-01' }, error: null });
      hoisted.chainPlan.push({ data: [], error: null });
      const r = await getTeacherEffectiveness(mockEnv, 'teacher-1', 'cls-1');
      expect(r.total_students).toBe(0);
      expect(r.active_students).toBe(0);
      expect(r.engagement_rate).toBe(0);
    });

    it('computes effectiveness from progress rows', async () => {
      hoisted.chainPlan.push({ data: { id: 'cls-1', teacher_id: 'teacher-1', created_at: '2024-01-01' }, error: null });
      hoisted.chainPlan.push({
        data: [
          { enrolled_at: '2024-01-01', student: { id: 's1' } },
          { enrolled_at: '2024-02-01', student: { id: 's2' } },
        ],
        error: null,
      });
      hoisted.chainPlan.push({
        data: [
          { ibt_latest_score: 90, itp_latest_score: null, ielts_latest_band: null, toeic_latest_score: null,
            ibt_practice_count: 5, itp_practice_count: 0, ielts_practice_count: 0, toeic_practice_count: 0, edubot_practice_count: 0,
            readiness_pct: 85 },
          { ibt_latest_score: 30, itp_latest_score: null, ielts_latest_band: null, toeic_latest_score: null,
            ibt_practice_count: 0, itp_practice_count: 0, ielts_practice_count: 0, toeic_practice_count: 0, edubot_practice_count: 0,
            readiness_pct: 10 },
        ],
        error: null,
      });

      const r = await getTeacherEffectiveness(mockEnv, 'teacher-1', 'cls-1');
      expect(r.total_students).toBe(2);
      expect(r.active_students).toBe(1);
      expect(r.engagement_rate).toBe(50);
      expect(r.top_performers).toBe(1);
      expect(r.needs_attention).toBeGreaterThanOrEqual(1);
      expect(r.teaching_duration_weeks).toBeGreaterThanOrEqual(1);
    });
  });
});