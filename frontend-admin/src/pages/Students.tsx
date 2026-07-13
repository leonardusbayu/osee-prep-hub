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
      <h2 className="mb-4 text-2xl font-bold">Students</h2>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}

      <div className="overflow-hidden rounded-lg bg-white shadow">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Name</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Email</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Target</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Level</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">iBT</th>
              <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">IELTS</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Referred By</th>
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
            ) : students.length === 0 && !error ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={8}>
                  No students yet.
                </td>
              </tr>
            ) : (
              students.map((s) => (
                <tr key={s.id}>
                  <td className="px-4 py-3 text-sm font-medium text-gray-900">{s.display_name}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">{s.email}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">{s.target_exam ?? '—'}</td>
                  <td className="px-4 py-3 text-sm text-gray-600">{s.current_level ?? '—'}</td>
                  <td className="px-4 py-3 text-right text-sm">{s.ibt_latest_score ?? '—'}</td>
                  <td className="px-4 py-3 text-right text-sm">{s.ielts_latest_band ?? '—'}</td>
                  <td className="px-4 py-3 text-sm font-mono text-gray-500">
                    {s.referred_by ? s.referred_by.slice(0, 8) : '—'}
                  </td>
                  <td className="px-4 py-3 text-sm text-gray-600">
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