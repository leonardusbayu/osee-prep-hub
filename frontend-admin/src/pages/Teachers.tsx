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
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Teachers</h2>
      <p className="mb-6 text-sm text-osee-400">Daftar pengajar beserta tier, referral, dan total penghasilan.</p>
      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}

      <div className="card overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Name</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Email</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Target</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Tier</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Referral</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Students</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Earnings</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Joined</th>
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
                <tr key={t.id} className="table-row">
                  <td className="px-4 py-3 text-sm font-semibold text-osee-900">{t.display_name}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{t.email}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{t.target_exam ?? '—'}</td>
                  <td className="px-4 py-3 text-sm">
                    <span className={`rounded px-2 py-0.5 text-xs ${tierBadgeClass(t.tier)}`}>
                      {t.tier}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm font-mono text-osee-500">{t.referral_code || '—'}</td>
                  <td className="px-4 py-3 text-right text-sm text-osee-500">{t.total_students}</td>
                  <td className="px-4 py-3 text-right text-sm font-medium">
                    {formatRupiah(t.total_earnings)}
                  </td>
                  <td className="px-4 py-3 text-sm text-osee-500">
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
      return 'bg-indigo-100 text-indigo-700';
    case 'institution':
      return 'bg-purple-100 text-purple-700';
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