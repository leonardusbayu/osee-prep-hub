import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface AdminStats {
  total_users: number;
  active_teachers: number;
  total_students: number;
  total_revenue: number;
  commission_paid: number;
  commission_pending: number;
  ai_usage: number;
  total_bookings: number;
}

export function Dashboard() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    apiFetch<AdminStats>('/admin/stats')
      .then((result) => {
        if (cancelled) return;
        if (result.error) {
          setError(result.error.message);
        } else {
          setStats(result.data ?? null);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div>
      <h2 className="mb-4 text-2xl font-bold">Admin Dashboard</h2>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}
      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : (
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <StatCard label="Total Users" value={stats ? String(stats.total_users) : '—'} />
          <StatCard label="Active Teachers" value={stats ? String(stats.active_teachers) : '—'} />
          <StatCard label="Students" value={stats ? String(stats.total_students) : '—'} />
          <StatCard label="Bookings" value={stats ? String(stats.total_bookings) : '—'} />
          <StatCard label="Revenue" value={stats ? formatRupiah(stats.total_revenue) : 'Rp —'} />
          <StatCard label="Commission Paid" value={stats ? formatRupiah(stats.commission_paid) : 'Rp —'} />
          <StatCard label="Commission Pending" value={stats ? formatRupiah(stats.commission_pending) : 'Rp —'} />
          <StatCard label="AI Usage" value={stats ? String(stats.ai_usage) : '—'} />
        </div>
      )}
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg bg-white p-4 shadow">
      <div className="text-sm text-gray-500">{label}</div>
      <div className="mt-1 text-2xl font-bold">{value}</div>
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