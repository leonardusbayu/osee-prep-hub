import { Hono } from 'hono';
import type { Env, ContextVars } from '../types';
import { requireAuth, getAuthedUser } from '../middleware/auth';
import { getSupabase } from '../services/supabase';

/**
 * Platform bridge routes — Task 11.5, 11.6.
 *
 * Aggregates materials and scores across all practice platforms
 * (ibt.osee.co.id, test.osee.co.id, ielts.osee.co.id, toeic.osee.co.id, EduBot).
 *
 * For now, materials are read from the Hub database (syllabus_items + ai_generation_queue +
 * video_lessons). When practice platforms expose a materials API, this route can
 * proxy those calls.
 */
export const platformRoutes = new Hono<{ Bindings: Env; Variables: ContextVars }>();

platformRoutes.use('*', requireAuth());

/** GET /api/platform/materials?type=reading&exam=IELTS&level=B2 — unified material list. */
platformRoutes.get('/materials', async (c) => {
  const type = c.req.query('type') ?? null;
  const exam = c.req.query('exam') ?? null;
  const level = c.req.query('level') ?? null;
  const limit = Math.min(parseInt(c.req.query('limit') ?? '50', 10), 200);

  const supabase = getSupabase(c.env);

  // Combine: syllabus_items (published) + video_lessons (published) + ai_generation_queue (completed)
  const [syllabusItems, videoLessons, aiGenerated] = await Promise.all([
    supabase
      .from('syllabus_items')
      .select('id, title, description, item_type, source_type, section, difficulty, source_platform_url')
      .eq('item_type', type)
      .eq('source_type', 'teacher_custom')
      .limit(limit),
    supabase
      .from('video_lessons')
      .select('id, title, description, section, cefr_level, youtube_id, is_free_preview')
      .eq('is_published', true)
      .limit(limit),
    supabase
      .from('ai_generation_queue')
      .select('id, generation_type, exam_type, cefr_level, topic, generated_content')
      .eq('status', 'completed')
      .limit(limit),
  ]);

  type Material = {
    id: string;
    title: string;
    description: string | null;
    type: string;
    exam: string | null;
    level: string | null;
    source: string;
    url: string | null;
  };

  const materials: Material[] = [];

  for (const row of (syllabusItems.data ?? []) as Array<Record<string, unknown>>) {
    materials.push({
      id: row.id as string,
      title: row.title as string,
      description: (row.description as string) ?? null,
      type: (row.item_type as string) ?? 'unknown',
      exam: null,
      level: (row.difficulty as string) ?? null,
      source: (row.source_type as string) ?? 'syllabus',
      url: (row.source_platform_url as string) ?? null,
    });
  }

  for (const row of (videoLessons.data ?? []) as Array<Record<string, unknown>>) {
    materials.push({
      id: row.id as string,
      title: row.title as string,
      description: (row.description as string) ?? null,
      type: 'video',
      exam: null,
      level: (row.cefr_level as string) ?? null,
      source: 'video',
      url: row.youtube_id ? `https://youtube.com/watch?v=${row.youtube_id}` : null,
    });
  }

  for (const row of (aiGenerated.data ?? []) as Array<Record<string, unknown>>) {
    materials.push({
      id: row.id as string,
      title: `${row.generation_type ?? 'material'} — ${row.topic ?? ''}`.trim(),
      description: null,
      type: (row.generation_type as string) ?? 'ai_generated',
      exam: (row.exam_type as string) ?? null,
      level: (row.cefr_level as string) ?? null,
      source: 'ai_generated',
      url: null,
    });
  }

  // Filter by query params
  const filtered = materials.filter((m) => {
    if (type && m.type !== type && m.type !== 'video') return false;
    if (exam && m.exam && m.exam !== exam) return false;
    if (level && m.level && m.level !== level) return false;
    return true;
  });

  return c.json({ materials: filtered.slice(0, limit) });
});

/** GET /api/platform/scores — latest scores from all platforms for current student. */
platformRoutes.get('/scores', async (c) => {
  const user = getAuthedUser(c);
  const supabase = getSupabase(c.env);

  const { data: progress } = await supabase
    .from('student_progress_unified')
    .select('*')
    .eq('student_id', user.id)
    .maybeSingle();

  const p = (progress as Record<string, unknown> | null) ?? {};
  return c.json({
    ibt: {
      latest_score: p.ibt_latest_score ?? null,
      section_scores: p.ibt_latest_section_scores ?? null,
      last_test_at: p.ibt_last_test_at ?? null,
    },
    itp: {
      latest_score: p.itp_latest_score ?? null,
      section_scores: p.itp_latest_section_scores ?? null,
      last_test_at: p.itp_last_test_at ?? null,
    },
    ielts: {
      latest_band: p.ielts_latest_band ?? null,
      section_scores: p.ielts_latest_section_scores ?? null,
      last_test_at: p.ielts_last_test_at ?? null,
    },
    toeic: {
      latest_score: p.toeic_latest_score ?? null,
      section_scores: p.toeic_latest_section_scores ?? null,
      last_test_at: p.toeic_last_test_at ?? null,
    },
    edubot: {
      xp: p.edubot_xp ?? 0,
      streak_days: p.edubot_streak_days ?? 0,
      questions_answered: p.edubot_questions_answered ?? 0,
      accuracy_rate: p.edubot_accuracy_rate ?? null,
      last_active: p.edubot_last_active ?? null,
    },
  });
});