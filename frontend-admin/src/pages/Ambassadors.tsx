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
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState<string | null>(null);

  function load() {
    setLoading(true);
    setError(null);
    apiFetch<{ ambassadors: Ambassador[] }>('/admin/ambassadors')
      .then((result) => {
        if (result.error) setError(result.error.message);
        else setAmbassadors(result.data?.ambassadors ?? []);
      })
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    load();
  }, []);

  async function revoke(teacherId: string, name: string) {
    setActionLoading(teacherId);
    setActionMsg(null);
    const res = await apiFetch('/admin/ambassadors/revoke', {
      method: 'POST',
      body: JSON.stringify({ teacher_id: teacherId }),
    });
    setActionLoading(null);
    if (res.error) {
      setActionMsg(`Failed to revoke: ${res.error.message}`);
    } else {
      setActionMsg(`Revoked ambassador status from ${name}.`);
      load();
    }
  }

  return (
    <div>
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Ambassadors</h2>
      <p className="mb-6 text-sm text-osee-400">
        OSEE Certified Educators — get unlimited AI, 2x commission, free Pro for life, in exchange
        for recruiting 5 teachers in 3 months + social media posts.
      </p>
      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}
      {actionMsg ? <div className="mb-4 rounded-xl bg-blue-50 p-4 text-sm text-blue-600">{actionMsg}</div> : null}

      {loading ? (
        <div className="flex items-center gap-2 text-gray-500">
          <svg className="h-4 w-4 animate-spin" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path strokeLinecap="round" d="M12 2a10 10 0 1010 10" />
          </svg>
          Loading...
        </div>
      ) : (
        <div className="card overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Name</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Email</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Recruited</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Since</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {ambassadors.length === 0 ? (
                <tr>
                  <td className="px-4 py-6 text-sm text-gray-500" colSpan={5}>
                    No ambassadors yet.
                  </td>
                </tr>
              ) : (
                ambassadors.map((a) => {
                  const profile = a.teacher_profiles?.[0] ?? { ambassador_recruited_at: null };
                  return (
                    <tr key={a.id} className="table-row">
                      <td className="px-4 py-3 text-sm font-semibold text-osee-900">
                        {a.display_name}
                        <span className="ml-2 rounded bg-green-100 px-2 py-0.5 text-xs text-green-700">
                          Certified
                        </span>
                      </td>
                      <td className="px-4 py-3 text-sm text-osee-500">{a.email}</td>
                      <td className="px-4 py-3 text-right text-sm font-semibold">
                        {a.recruited_count}
                      </td>
                      <td className="px-4 py-3 text-sm text-osee-500">
                        {profile.ambassador_recruited_at
                          ? new Date(profile.ambassador_recruited_at).toLocaleDateString('id-ID')
                          : '—'}
                      </td>
                      <td className="px-4 py-3 text-right">
                        <button
                          type="button"
                          className="rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-600 transition-colors hover:bg-red-100 disabled:opacity-50"
                          disabled={actionLoading === a.id}
                          onClick={() => revoke(a.id, a.display_name)}
                        >
                          {actionLoading === a.id ? 'Revoking...' : 'Revoke'}
                        </button>
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