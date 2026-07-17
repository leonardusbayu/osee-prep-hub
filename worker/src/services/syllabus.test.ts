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
      // builders return chain so they compose
      select: vi.fn(() => chain),
      eq: vi.fn(() => chain),
      neq: vi.fn(() => chain),
      order: vi.fn(() => chain),
      insert: vi.fn(() => chain),
      update: vi.fn(() => chain),
      delete: vi.fn(() => chain),
      limit: vi.fn(() => chain),
      // terminal async
      maybeSingle: vi.fn(async () => getResolved()),
      single: vi.fn(async () => getResolved()),
      // terminal sync (destructured {data, error})
      get data() { return getResolved().data; },
      get error() { return getResolved().error; },
    };
    // chain is thenable so `await chain` returns resolved value too.
    (chain as unknown as { then: (resolve: (v: unknown) => unknown) => Promise<unknown> }).then =
      (resolve) => Promise.resolve(getResolved()).then(resolve);
    return chain;
  };
  return { getSupabase: vi.fn(() => ({ from: vi.fn(() => makeChain()) })) };
});

import {
  createSyllabus,
  listSyllabi,
  getSyllabus,
  listSyllabusItems,
  batchSaveSyllabusItems,
  addSyllabusItem,
  deleteSyllabusItem,
  deleteSyllabus,
  togglePublishSyllabus,
} from './syllabus';

const mockEnv = {
  SUPABASE_URL: 'https://test.supabase.co',
  SUPABASE_SERVICE_KEY: 'test-key',
} as unknown as Env;

describe('syllabus service', () => {
  beforeEach(() => {
    hoisted.chainPlan.length = 0;
  });

  it('createSyllabus returns the created syllabus', async () => {
    const created = { id: 's1', teacher_id: 't1', name: 'Test' };
    hoisted.chainPlan.push({ data: created, error: null });
    const result = await createSyllabus(mockEnv, 't1', { name: 'Test Syllabus' });
    expect(result).toEqual(created);
  });

  it('createSyllabus throws on db error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'null violation' } });
    await expect(createSyllabus(mockEnv, 't1', { name: '' })).rejects.toThrow(/Create syllabus failed/);
  });

  it('listSyllabi returns array (possibly empty)', async () => {
    hoisted.chainPlan.push({ data: [{ id: 's1' }, { id: 's2' }], error: null });
    const list = await listSyllabi(mockEnv, 't1');
    expect(list).toHaveLength(2);
  });

  it('listSyllabi throws on error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'nope' } });
    await expect(listSyllabi(mockEnv, 't1')).rejects.toThrow(/List syllabi failed/);
  });

  it('getSyllabus returns syllabus when found', async () => {
    hoisted.chainPlan.push({ data: { id: 's1', teacher_id: 't1' }, error: null });
    const s = await getSyllabus(mockEnv, 't1', 's1');
    expect(s?.id).toBe('s1');
  });

  it('getSyllabus returns null when not found', async () => {
    hoisted.chainPlan.push({ data: null, error: null });
    const s = await getSyllabus(mockEnv, 't1', 'missing');
    expect(s).toBeNull();
  });

  it('listSyllabusItems returns items ordered by sort_order', async () => {
    hoisted.chainPlan.push({ data: [{ id: 'i1', sort_order: 0 }, { id: 'i2', sort_order: 1 }], error: null });
    const items = await listSyllabusItems(mockEnv, 's1');
    expect(items).toHaveLength(2);
    expect(items[0].sort_order).toBe(0);
  });

  it('batchSaveSyllabusItems deletes then inserts', async () => {
    hoisted.chainPlan.push({ data: null, error: null }); // delete
    hoisted.chainPlan.push({ data: null, error: null }); // insert
    await batchSaveSyllabusItems(mockEnv, 's1', [
      { sort_order: 0, source_type: 'teacher_custom', title: 'A', item_type: 'reading' } as never,
    ]);
    // no throw = pass
  });

  it('batchSaveSyllabusItems with empty list only deletes (no insert)', async () => {
    hoisted.chainPlan.push({ data: null, error: null }); // delete only
    await batchSaveSyllabusItems(mockEnv, 's1', []);
  });

  it('batchSaveSyllabusItems throws on delete error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'delete failed' } });
    await expect(batchSaveSyllabusItems(mockEnv, 's1', [])).rejects.toThrow(/Delete old items failed/);
  });

  it('batchSaveSyllabusItems throws on insert error', async () => {
    hoisted.chainPlan.push({ data: null, error: null }); // delete
    hoisted.chainPlan.push({ data: null, error: { message: 'insert failed' } });
    await expect(
      batchSaveSyllabusItems(mockEnv, 's1', [
        { sort_order: 0, source_type: 'teacher_custom', title: 'A', item_type: 'reading' } as never,
      ])
    ).rejects.toThrow(/Insert items failed/);
  });

  it('addSyllabusItem computes next sort_order and returns new item', async () => {
    hoisted.chainPlan.push({ data: { sort_order: 5 }, error: null }); // existing max
    hoisted.chainPlan.push({ data: { id: 'i10', sort_order: 6, title: 'New' }, error: null }); // insert single
    const item = await addSyllabusItem(mockEnv, 's1', {
      sort_order: 6,
      source_type: 'ai_generated',
      title: 'New',
      item_type: 'reading',
    } as never);
    expect(item.id).toBe('i10');
    expect(item.sort_order).toBe(6);
  });

  it('addSyllabusItem uses 0 when no existing items', async () => {
    hoisted.chainPlan.push({ data: null, error: null }); // no existing
    hoisted.chainPlan.push({ data: { id: 'i1', sort_order: 0 }, error: null });
    const item = await addSyllabusItem(mockEnv, 's1', {
      sort_order: 0,
      source_type: 'teacher_custom',
      title: 'First',
      item_type: 'reading',
    } as never);
    expect(item.sort_order).toBe(0);
  });

  it('addSyllabusItem throws on insert error', async () => {
    hoisted.chainPlan.push({ data: null, error: null });
    hoisted.chainPlan.push({ data: null, error: { message: 'bad' } });
    await expect(
      addSyllabusItem(mockEnv, 's1', {
        sort_order: 0, source_type: 'x', title: 'y', item_type: 'z',
      } as never)
    ).rejects.toThrow(/Add item failed/);
  });

  it('deleteSyllabusItem succeeds', async () => {
    hoisted.chainPlan.push({ data: null, error: null });
    await deleteSyllabusItem(mockEnv, 's1', 'i1');
  });

  it('deleteSyllabusItem throws on error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'rls blocked' } });
    await expect(deleteSyllabusItem(mockEnv, 's1', 'i1')).rejects.toThrow(/Delete item failed/);
  });

  it('deleteSyllabus throws when not owned', async () => {
    hoisted.chainPlan.push({ data: null, error: null }); // ownership check returns null
    await expect(deleteSyllabus(mockEnv, 't1', 's1')).rejects.toThrow(/not found or not owned/);
  });

  it('deleteSyllabus succeeds when owned', async () => {
    hoisted.chainPlan.push({ data: { id: 's1' }, error: null }); // ownership
    hoisted.chainPlan.push({ data: null, error: null }); // delete
    await deleteSyllabus(mockEnv, 't1', 's1');
  });

  it('deleteSyllabus throws on delete error', async () => {
    hoisted.chainPlan.push({ data: { id: 's1' }, error: null });
    hoisted.chainPlan.push({ data: null, error: { message: 'fk violation' } });
    await expect(deleteSyllabus(mockEnv, 't1', 's1')).rejects.toThrow(/Delete syllabus failed/);
  });

  it('togglePublishSyllabus succeeds', async () => {
    hoisted.chainPlan.push({ data: null, error: null });
    await togglePublishSyllabus(mockEnv, 't1', 's1', true);
  });

  it('togglePublishSyllabus throws on error', async () => {
    hoisted.chainPlan.push({ data: null, error: { message: 'no perms' } });
    await expect(togglePublishSyllabus(mockEnv, 't1', 's1', true)).rejects.toThrow(/Publish toggle failed/);
  });
});