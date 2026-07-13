import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface AdminStats {
  total_users: number;
  active_teachers: number;
  total_revenue: number;
  commission_paid: number;
  ai_usage: number;
}

export function Dashboard() {
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiFetch<AdminStats>('/admin/stats').then((result) => {
      if (result.error) {
        setError(result.error.message);
        return;
      }
      setStats(result.data ?? null);
    });
  }, []);

  return (
    <div>
      <h2 className="text-2xl font-bold mb-4">Admin Dashboard</h2>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <StatCard label="Total Users" value={stats ? String(stats.total_users) : '—'} />
        <StatCard label="Active Teachers" value={stats ? String(stats.active_teachers) : '—'} />
        <StatCard label="Revenue" value={stats ? formatRupiah(stats.total_revenue) : 'Rp —'} />
      </div>
    </div>
  );
}

function StatCard({ label, value }: { label: string; value: string }) {
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <div className="text-sm text-gray-500">{label}</div>
      <div className="text-2xl font-bold mt-1">{value}</div>
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
