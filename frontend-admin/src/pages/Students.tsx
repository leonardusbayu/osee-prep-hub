import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface Student {
  id: string;
  display_name: string;
  email: string;
  target_exam: string | null;
  current_level: string | null;
  referred_by: string | null;
  ibt_latest_score: number | null;
  ielts_latest_band: number | null;
  created_at: string;
}

export function Students() {
  const [students, setStudents] = useState<Student[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch<{ students: Student[] }>('/admin/students')
      .then((result) => {
        if (cancelled) return;
        if (result.error) setError(result.error.message);
        else setStudents(result.data?.students ?? []);
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
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Students</h2>
      <p className="mb-6 text-sm text-osee-400">Lihat semua siswa, skor terbaru, dan informasi referral.</p>
      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}

      <div className="card overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Name</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Email</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Target</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Level</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">iBT</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">IELTS</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Referred By</th>
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
            ) : students.length === 0 && !error ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={8}>
                  No students yet.
                </td>
              </tr>
            ) : (
              students.map((s) => (
                <tr key={s.id} className="table-row">
                  <td className="px-4 py-3 text-sm font-semibold text-osee-900">{s.display_name}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{s.email}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{s.target_exam ?? '—'}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{s.current_level ?? '—'}</td>
                  <td className="px-4 py-3 text-right text-sm">{s.ibt_latest_score ?? '—'}</td>
                  <td className="px-4 py-3 text-right text-sm">{s.ielts_latest_band ?? '—'}</td>
                  <td className="px-4 py-3 text-sm font-mono text-gray-500">
                    {s.referred_by ? s.referred_by.slice(0, 8) : '—'}
                  </td>
                  <td className="px-4 py-3 text-sm text-osee-500">
                    {new Date(s.created_at).toLocaleDateString('id-ID')}
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