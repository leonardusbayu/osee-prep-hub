import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

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
      <h2 className="mb-4 text-2xl font-bold">Commission</h2>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}

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
          <div className="overflow-hidden rounded-lg bg-white shadow">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Action</th>
                  <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Description</th>
                  <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Rate (IDR)</th>
                  <th className="px-4 py-3 text-center text-xs font-semibold uppercase text-gray-500">Active</th>
                  <th className="px-4 py-3 text-xs font-semibold uppercase text-gray-500">Save</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {rates.map((rate) => (
                  <tr key={rate.id}>
                    <td className="px-4 py-3 text-sm font-mono text-gray-900">{rate.action}</td>
                    <td className="px-4 py-3 text-sm text-gray-600">{rate.description ?? '—'}</td>
                    <td className="px-4 py-3 text-right text-sm">
                      <input
                        type="number"
                        className="w-28 rounded border px-2 py-1 text-right text-sm"
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
                        className="rounded bg-osee-700 px-2 py-1 text-xs text-white hover:bg-osee-600 disabled:opacity-50"
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
              <div className="overflow-hidden rounded-lg bg-white shadow">
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Teacher</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Students</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Earned</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Pending</th>
                      <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Paid</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-gray-100">
                    {summary.by_teacher.slice(0, 50).map((t) => (
                      <tr key={t.teacher_id}>
                        <td className="px-4 py-3 text-sm font-medium text-gray-900">{t.teacher_name}</td>
                        <td className="px-4 py-3 text-right text-sm text-gray-600">{t.student_count}</td>
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
    <div className="rounded-lg bg-white p-4 shadow">
      <div className="text-sm text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-bold">{value}</div>
    </div>
  );
}

function formatRupiah(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}