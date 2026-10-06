import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface Material {
  id: string;
  source_type: string;
  source_material_id: string | null;
  source_platform_url: string | null;
  title: string;
  description: string | null;
  item_type: string;
  section: string | null;
  difficulty: string | null;
  estimated_minutes: number;
  created_by: string | null;
  is_public: boolean;
  tags: string[];
  exam_types: string[];
  created_at: string;
}

const ITEM_TYPES = ['reading', 'listening', 'speaking', 'writing', 'grammar', 'vocabulary', 'mock_test', 'diagnostic', 'video', 'assignment', 'review'];
const SOURCE_TYPES = ['platform_ibt', 'platform_itp', 'platform_ielts', 'platform_toeic', 'edubot', 'teacher_custom', 'ai_generated', 'video_lesson'];
const DIFFICULTIES = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
const EXAM_TYPES = ['TOEFL_IBT', 'TOEFL_ITP', 'IELTS', 'TOEIC', 'GENERAL'];

export function Materials() {
  const [materials, setMaterials] = useState<Material[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [actionMsg, setActionMsg] = useState<string | null>(null);

  // Form state
  const [form, setForm] = useState({
    title: '',
    description: '',
    item_type: 'reading',
    section: '',
    difficulty: 'B2',
    estimated_minutes: 30,
    source_type: 'teacher_custom',
    source_platform_url: '',
    exam_types: [] as string[],
  });

  function load() {
    setLoading(true);
    setError(null);
    apiFetch<{ materials: Material[] }>('/admin/materials')
      .then((res) => {
        if (res.error) setError(res.error.message);
        else setMaterials(res.data?.materials ?? []);
      })
      .finally(() => setLoading(false));
  }

  useEffect(() => { load(); }, []);

  async function createMaterial() {
    if (!form.title.trim()) { setActionMsg('Title required'); return; }
    setActionMsg(null);
    const res = await apiFetch('/admin/materials', {
      method: 'POST',
      body: JSON.stringify({
        title: form.title.trim(),
        description: form.description || null,
        item_type: form.item_type,
        section: form.section || null,
        difficulty: form.difficulty || null,
        estimated_minutes: Number(form.estimated_minutes) || 20,
        source_type: form.source_type,
        source_platform_url: form.source_platform_url || null,
        exam_types: form.exam_types,
      }),
    });
    if (res.error) {
      setActionMsg(`Failed: ${res.error.message}`);
    } else {
      setActionMsg('Material added to catalog.');
      setShowForm(false);
      setForm({ title: '', description: '', item_type: 'reading', section: '', difficulty: 'B2', estimated_minutes: 30, source_type: 'teacher_custom', source_platform_url: '', exam_types: [] });
      load();
    }
  }

  async function deleteMaterial(id: string) {
    if (!confirm('Delete this material from the catalog?')) return;
    const res = await apiFetch(`/admin/materials/${id}`, { method: 'DELETE' });
    if (res.error) setActionMsg(`Delete failed: ${res.error.message}`);
    else { setActionMsg('Material deleted.'); load(); }
  }

  function toggleExamType(et: string) {
    setForm((f) => ({
      ...f,
      exam_types: f.exam_types.includes(et) ? f.exam_types.filter((e) => e !== et) : [...f.exam_types, et],
    }));
  }

  return (
    <div>
      <div className="mb-6 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-extrabold tracking-tight text-osee-900">Materials</h2>
          <p className="text-sm text-osee-400">Global material catalog — teachers drag these into syllabi. Add custom materials, video lessons, platform templates.</p>
        </div>
        <button
          type="button"
          className="rounded-xl bg-osee-600 px-4 py-2 text-sm font-semibold text-white transition-colors hover:bg-osee-700"
          onClick={() => setShowForm((v) => !v)}
        >
          {showForm ? 'Cancel' : '+ Add Material'}
        </button>
      </div>

      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}
      {actionMsg ? <div className="mb-4 rounded-xl bg-blue-50 p-4 text-sm text-blue-600">{actionMsg}</div> : null}

      {showForm ? (
        <div className="card mb-6 p-6">
          <h3 className="mb-4 text-lg font-semibold text-osee-900">New Material</h3>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Title</span>
              <input className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="e.g. IELTS Reading — Academic" />
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Description</span>
              <input className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.description} onChange={(e) => setForm({ ...form, description: e.target.value })} placeholder="Short description" />
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Item Type</span>
              <select className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.item_type} onChange={(e) => setForm({ ...form, item_type: e.target.value })}>
                {ITEM_TYPES.map((t) => <option key={t} value={t}>{t}</option>)}
              </select>
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Source Type</span>
              <select className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.source_type} onChange={(e) => setForm({ ...form, source_type: e.target.value })}>
                {SOURCE_TYPES.map((s) => <option key={s} value={s}>{s}</option>)}
              </select>
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Section</span>
              <input className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.section} onChange={(e) => setForm({ ...form, section: e.target.value })} placeholder="reading / listening / etc." />
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Difficulty (CEFR)</span>
              <select className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.difficulty} onChange={(e) => setForm({ ...form, difficulty: e.target.value })}>
                {DIFFICULTIES.map((d) => <option key={d} value={d}>{d}</option>)}
              </select>
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Estimated Minutes</span>
              <input type="number" className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.estimated_minutes} onChange={(e) => setForm({ ...form, estimated_minutes: Number(e.target.value) })} />
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Platform URL (deep link)</span>
              <input className="mt-1 w-full rounded-lg border border-gray-200 px-3 py-2 text-sm" value={form.source_platform_url} onChange={(e) => setForm({ ...form, source_platform_url: e.target.value })} placeholder="https://ibt.osee.co.id" />
            </label>
          </div>
          <div className="mt-4">
            <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Exam Types</span>
            <div className="mt-2 flex flex-wrap gap-2">
              {EXAM_TYPES.map((et) => (
                <button
                  key={et}
                  type="button"
                  className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors ${form.exam_types.includes(et) ? 'bg-osee-600 text-white' : 'bg-gray-100 text-gray-600 hover:bg-gray-200'}`}
                  onClick={() => toggleExamType(et)}
                >
                  {et}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-6 flex gap-3">
            <button type="button" className="rounded-xl bg-osee-600 px-5 py-2 text-sm font-semibold text-white hover:bg-osee-700" onClick={createMaterial}>Add to Catalog</button>
            <button type="button" className="rounded-xl bg-gray-100 px-5 py-2 text-sm font-semibold text-gray-600 hover:bg-gray-200" onClick={() => setShowForm(false)}>Cancel</button>
          </div>
        </div>
      ) : null}

      {loading ? (
        <div className="flex items-center gap-2 text-gray-500">
          <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path strokeLinecap="round" d="M12 2a10 10 0 1010 10" /></svg>
          Loading...
        </div>
      ) : (
        <div className="card overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Title</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Type</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Source</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Level</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Exams</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">URL</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {materials.length === 0 ? (
                <tr><td className="px-4 py-6 text-sm text-gray-500" colSpan={7}>No materials in catalog yet. Click "Add Material" above.</td></tr>
              ) : materials.map((m) => (
                <tr key={m.id} className="table-row">
                  <td className="px-4 py-3 text-sm">
                    <div className="font-semibold text-osee-900">{m.title}</div>
                    {m.description ? <div className="text-xs text-osee-400">{m.description}</div> : null}
                  </td>
                  <td className="px-4 py-3 text-sm text-osee-500">{m.item_type}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{m.source_type}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{m.difficulty ?? '—'}</td>
                  <td className="px-4 py-3 text-xs text-osee-400">{(m.exam_types ?? []).join(', ') || '—'}</td>
                  <td className="px-4 py-3 text-xs">
                    {m.source_platform_url ? <a href={m.source_platform_url} target="_blank" rel="noopener" className="text-blue-500 hover:underline">Open</a> : '—'}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <button type="button" className="rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-600 hover:bg-red-100" onClick={() => deleteMaterial(m.id)}>Delete</button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}