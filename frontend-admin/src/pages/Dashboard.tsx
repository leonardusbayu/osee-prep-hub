import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';
import { formatRupiah } from '../utils/format';

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
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Dashboard</h2>
      <p className="mb-6 text-sm text-osee-400">Platform overview at a glance</p>

      {error ? (
        <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div>
      ) : null}

      {loading ? (
        <div className="flex items-center gap-3 text-osee-400">
          <div className="h-5 w-5 animate-spin rounded-full border-2 border-osee-200 border-t-osee-600" />
          <span className="text-sm">Loading...</span>
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-4 md:grid-cols-4">
          <StatCard icon="users" label="Total Users" value={stats ? String(stats.total_users) : '—'} />
          <StatCard icon="teacher" label="Teachers" value={stats ? String(stats.active_teachers) : '—'} />
          <StatCard icon="student" label="Students" value={stats ? String(stats.total_students) : '—'} />
          <StatCard icon="booking" label="Bookings" value={stats ? String(stats.total_bookings) : '—'} />
          <StatCard icon="revenue" label="Revenue" value={stats ? formatRupiah(stats.total_revenue) : '—'} />
          <StatCard icon="paid" label="Commission Paid" value={stats ? formatRupiah(stats.commission_paid) : '—'} />
          <StatCard icon="pending" label="Commission Pending" value={stats ? formatRupiah(stats.commission_pending) : '—'} />
          <StatCard icon="ai" label="AI Usage" value={stats ? String(stats.ai_usage) : '—'} />
        </div>
      )}
    </div>
  );
}

const icons: Record<string, string> = {
  users: 'M17 20h5v-2a4 4 0 00-3-3.87M9 20H4v-2a4 4 0 013-3.87m6-1.13a4 4 0 10-8 0 4 4 0 008 0zm6-4a3 3 0 11-6 0 3 3 0 016 0z',
  teacher: 'M12 14l9-5-9-5-9 5 9 5z M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z',
  student: 'M12 14l9-5-9-5-9 5 9 5z M12 14l6.16-3.422',
  booking: 'M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z',
  revenue: 'M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1',
  paid: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
  pending: 'M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z',
  ai: 'M13 10V3L4 14h7v7l9-11h-7z',
};

function StatCard({ icon, label, value }: { icon: string; label: string; value: string }) {
  return (
    <div className="stat-card">
      <div className="flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-osee-600/10">
          <svg className="h-5 w-5 text-osee-600" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d={icons[icon] || icons.users} />
          </svg>
        </div>
        <div className="stat-label">{label}</div>
      </div>
      <div className="stat-value">{value}</div>
    </div>
  );
}
