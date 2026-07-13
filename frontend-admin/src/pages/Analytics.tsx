import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface Analytics {
  total_teachers: number;
  total_students: number;
  total_partners: number;
  total_classrooms: number;
  total_bookings: number;
  total_revenue: number;
  commission_paid: number;
  commission_pending: number;
  ai_grading_count: number;
  ai_generation_count: number;
  active_payouts: number;
}

export function Analytics() {
  const [data, setData] = useState<Analytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch<Analytics>('/admin/analytics')
      .then((result) => {
        if (cancelled) return;
        if (result.error) setError(result.error.message);
        else setData(result.data ?? null);
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (loading) return <p className="text-gray-500">Loading...</p>;
  if (error) return <p className="rounded bg-red-50 p-3 text-sm text-red-700">{error}</p>;
  if (!data) return null;

  return (
    <div>
      <h2 className="mb-4 text-2xl font-bold">Platform Analytics</h2>

      <h3 className="mb-2 text-lg font-semibold">Users</h3>
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card label="Teachers" value={data.total_teachers} />
        <Card label="Students" value={data.total_students} />
        <Card label="Partners" value={data.total_partners} />
        <Card label="Classrooms" value={data.total_classrooms} />
      </div>

      <h3 className="mb-2 text-lg font-semibold">Revenue</h3>
      <div className="mb-6 grid grid-cols-2 gap-4 md:grid-cols-4">
        <Card label="Bookings" value={data.total_bookings} />
        <Card label="Revenue" value={formatRupiah(data.total_revenue)} />
        <Card label="Commission Paid" value={formatRupiah(data.commission_paid)} />
        <Card label="Commission Pending" value={formatRupiah(data.commission_pending)} />
      </div>

      <h3 className="mb-2 text-lg font-semibold">AI Usage</h3>
      <div className="grid grid-cols-2 gap-4 md:grid-cols-3">
        <Card label="Grading Jobs" value={data.ai_grading_count} />
        <Card label="Generation Jobs" value={data.ai_generation_count} />
        <Card label="Active Payouts" value={data.active_payouts} />
      </div>
    </div>
  );
}

function Card({ label, value }: { label: string; value: number | string }) {
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