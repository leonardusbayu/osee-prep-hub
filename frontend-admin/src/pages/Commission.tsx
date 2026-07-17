import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';
import { formatRupiah } from '../utils/format';

interface CommissionRate {
  id: string;
  action: string;
  rate_idr: number;
  description: string | null;
  active: boolean;
  updated_at: string;
}

interface CommissionSummary {
  total_paid: number;
  total_pending: number;
  total_confirmed: number;
  by_teacher: Array<{
    teacher_id: string;
    teacher_name: string;
    total_earned: number;
    pending: number;
    paid: number;
    student_count: number;
  }>;
}

export function Commission() {
  const [rates, setRates] = useState<CommissionRate[]>([]);
  const [summary, setSummary] = useState<CommissionSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [editing, setEditing] = useState<Record<string, string>>({});
  const [saving, setSaving] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    setError(null);
    const [r1, r2] = await Promise.all([
      apiFetch<{ rates: CommissionRate[] }>('/admin/commission-rates'),
      apiFetch<CommissionSummary>('/admin/commission'),
    ]);
    if (r1.error || r2.error) {
      setError(r1.error?.message ?? r2.error?.message ?? 'Failed to load');
    } else {
      setRates(r1.data?.rates ?? []);
      setSummary(r2.data ?? null);
    }
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  async function saveRate(action: string) {
    const newRate = editing[action];
    if (!newRate) return;
    const parsed = parseInt(newRate, 10);
    if (Number.isNaN(parsed) || parsed < 0) {
      setError('Rate must be a non-negative number');
      return;
    }
    setSaving(action);
    const res = await apiFetch('/admin/commission-rates', {
      method: 'POST',
      body: JSON.stringify({ action, rate_idr: parsed }),
    });
    setSaving(null);
    if (res.error) {
      setError(res.error.message);
    } else {
      setEditing((prev) => {
        const next = { ...prev };
        delete next[action];
        return next;
      });
      load();
    }
  }

  return (
    <div>
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Commission</h2>
      <p className="mb-6 text-sm text-osee-400">Ringkasan komisi pengajar dan editor tarif komisi per aksi.</p>
      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}

      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : (
        <>
          {/* Summary cards */}
          {summary ? (
            <div className="mb-6 grid grid-cols-1 gap-4 md:grid-cols-3">
              <Card label="Total Paid" value={formatRupiah(summary.total_paid)} />
              <Card label="Pending" value={formatRupiah(summary.total_pending)} />
              <Card label="Confirmed" value={formatRupiah(summary.total_confirmed)} />
            </div>
          ) : null}

          {/* Commission rates editor */}
          <h3 className="mb-2 text-lg font-semibold">Commission Rates</h3>
          <div className="card overflow-hidden">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Action</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Description</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Rate (IDR)</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-osee-400">Active</th>
                  <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-osee-400">Save</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {rates.map((rate) => (
                  <tr key={rate.id} className="table-row">
                    <td className="px-4 py-3 text-sm font-mono text-osee-900">{rate.action}</td>
                    <td className="px-4 py-3 text-sm text-osee-500">{rate.description ?? '—'}</td>
                    <td className="px-4 py-3 text-right text-sm">
                      <input
                        type="number"
                        className="input w-28 text-right text-sm"
                        defaultValue={rate.rate_idr}
                        onChange={(e) =>
                          setEditing((p) => ({ ...p, [rate.action]: e.target.value }))
                        }
                      />
                    </td>
                    <td className="px-4 py-3 text-center text-sm">
                      <span className={rate.active ? 'text-green-600' : 'text-gray-400'}>
                        {rate.active ? '✓' : '✗'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <button
                        className="btn-primary px-3 py-1.5 text-sm disabled:opacity-50"
                        disabled={!editing[rate.action] || saving === rate.action}
                        onClick={() => saveRate(rate.action)}
                      >
                        {saving === rate.action ? '...' : 'Save'}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          {/* By teacher */}
          {summary && summary.by_teacher.length > 0 ? (
            <>
              <h3 className="mb-2 mt-6 text-lg font-semibold">Top Teachers by Earnings</h3>
              <div className="card overflow-hidden">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Teacher</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Students</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Earned</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Pending</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Paid</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {summary.by_teacher.slice(0, 50).map((t) => (
                      <tr key={t.teacher_id} className="table-row">
                        <td className="px-4 py-3 text-sm font-semibold text-osee-900">{t.teacher_name}</td>
                        <td className="px-4 py-3 text-right text-sm text-osee-500">{t.student_count}</td>
                        <td className="px-4 py-3 text-right text-sm">{formatRupiah(t.total_earned)}</td>
                        <td className="px-4 py-3 text-right text-sm text-orange-600">{formatRupiah(t.pending)}</td>
                        <td className="px-4 py-3 text-right text-sm text-green-700">{formatRupiah(t.paid)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </>
          ) : null}
        </>
      )}
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat-card">
      <div className="stat-label">{label}</div>
      <div className="stat-value">{value}</div>
    </div>
  );
}
