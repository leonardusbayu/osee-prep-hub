import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface Teacher {
  id: string;
  display_name: string;
  email: string;
  target_exam: string | null;
  tier: string;
  referral_code: string;
  total_students: number;
  total_earnings: number;
  created_at: string;
}

export function Teachers() {
  const [teachers, setTeachers] = useState<Teacher[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch<{ teachers: Teacher[] }>('/admin/teachers')
      .then((result) => {
        if (cancelled) return;
        if (result.error) setError(result.error.message);
        else setTeachers(result.data?.teachers ?? []);
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
      <h2 className="mb-4 text-2xl font-bold">Teachers</h2>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}

      <div className="overflow-hidden rounded-lg bg-white shadow">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Name</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Email</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Target</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Tier</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Referral</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Students</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Earnings</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Joined</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={8}>
                  Loading...
                </td>
              </tr>
            ) : teachers.length === 0 && !error ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={8}>
                  No teachers yet.
                </td>
              </tr>
            ) : (
              teachers.map((t) => (
                <tr key={t.id}>
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{t.display_name}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">{t.email}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">{t.target_exam ?? '—'}</td>
                  <td className="px-4 py-3 text-sm">
                    <span className={`rounded px-2 py-0.5 text-xs ${tierBadgeClass(t.tier)}`}>
                      {t.tier}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm font-mono text-gray-600">{t.referral_code || '—'}</td>
                  <td className="px-4 py-3 text-right text-sm text-gray-600">{t.total_students}</td>
                  <td className="px-4 py-3 text-right text-sm font-medium">
                    {formatRupiah(t.total_earnings)}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
                    {new Date(t.created_at).toLocaleDateString('id-ID')}
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function tierBadgeClass(tier: string): string {
  switch (tier) {
    case 'pro':
      return 'bg-blue-100 text-blue-800';
    case 'institution':
      return 'bg-purple-100 text-purple-800';
    default:
      return 'bg-gray-100 text-gray-800';
  }
}

function formatRupiah(value: number) {
  return new Intl.NumberFormat('id-ID', {
    style: 'currency',
    currency: 'IDR',
    maximumFractionDigits: 0,
  }).format(value);
}