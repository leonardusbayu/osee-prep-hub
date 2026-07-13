import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface Ambassador {
  id: string;
  display_name: string;
  email: string;
  teacher_profiles: Array<{
    is_ambassador: boolean;
    ambassador_recruited_at: string | null;
    ambassador_recruited_by: string | null;
  }>;
  recruited_count: number;
}

export function Ambassadors() {
  const [ambassadors, setAmbassadors] = useState<Ambassador[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    apiFetch<{ ambassadors: Ambassador[] }>('/admin/ambassadors')
      .then((result) => {
        if (cancelled) return;
        if (result.error) setError(result.error.message);
        else setAmbassadors(result.data?.ambassadors ?? []);
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
      <h2 className="mb-4 text-2xl font-bold">Ambassadors</h2>
      <p className="mb-4 text-sm text-gray-600">
        OSEE Certified Educators — get unlimited AI, 2x commission, free Pro for life, in exchange
        for recruiting 5 teachers in 3 months + social media posts.
      </p>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}

      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : (
        <div className="overflow-hidden rounded-lg bg-white shadow">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Name</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Email</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase text-gray-500">Recruited</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Since</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {ambassadors.length === 0 ? (
                <tr>
                  <td className="px-4 py-6 text-sm text-gray-500" colSpan={4}>
                    No ambassadors yet.
                  </td>
                </tr>
              ) : (
                ambassadors.map((a) => {
                  const profile = a.teacher_profiles?.[0] ?? { ambassador_recruited_at: null };
                  return (
                    <tr key={a.id}>
                      <td className="px-4 py-3 text-sm font-medium text-gray-900">
                        {a.display_name}
                        <span className="ml-2 rounded bg-green-100 px-2 py-0.5 text-xs text-green-800">
                          Certified
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600">{a.email}</td>
                      <td className="px-4 py-3 text-right text-sm font-semibold">
                        {a.recruited_count}
                      </td>
                      <td className="px-4 py-3 text-sm text-gray-600">
                        {profile.ambassador_recruited_at
                          ? new Date(profile.ambassador_recruited_at).toLocaleDateString('id-ID')
                          : '—'}
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}