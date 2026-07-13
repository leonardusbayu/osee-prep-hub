import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface AdminUser {
  id: string;
  email: string;
  display_name: string;
  role: string;
  created_at: string;
}

const ROLES = ['', 'student', 'teacher', 'partner', 'admin'];

export function Users() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [roleFilter, setRoleFilter] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    setError(null);
    const path = roleFilter ? `/admin/users?role=${roleFilter}` : '/admin/users';
    apiFetch<{ users: AdminUser[] }>(path)
      .then((result) => {
        if (cancelled) return;
        if (result.error) {
          setError(result.error.message);
        } else {
          setUsers(result.data?.users ?? []);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [roleFilter]);

  return (
    <div>
      <div className="mb-4 flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-extrabold tracking-tight text-osee-900">Users</h2>
          <p className="mb-6 text-sm text-osee-400">Kelola dan cari pengguna berdasarkan peran di platform.</p>
        </div>
        <select
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value)}
          className="input"
        >
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {r || 'All roles'}
            </option>
          ))}
        </select>
      </div>

      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}

      <div className="card overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Name</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Email</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Role</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Created</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {loading ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={4}>
                  Loading...
                </td>
              </tr>
            ) : users.length === 0 && !error ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={4}>
                  No users found.
                </td>
              </tr>
            ) : (
              users.map((user) => (
                <tr key={user.id} className="table-row">
                  <td className="px-4 py-3 text-sm font-semibold text-osee-900">{user.display_name}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">{user.email}</td>
                  <td className="px-4 py-3 text-sm text-osee-500">
                    <span className={`rounded px-2 py-0.5 text-xs ${roleBadgeClass(user.role)}`}>
                      {user.role}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-sm text-osee-500">
                    {new Date(user.created_at).toLocaleString('id-ID')}
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

function roleBadgeClass(role: string): string {
  switch (role) {
    case 'admin':
      return 'bg-red-100 text-red-700';
    case 'teacher':
      return 'bg-indigo-100 text-indigo-700';
    case 'partner':
      return 'bg-purple-100 text-purple-700';
    case 'student':
      return 'bg-green-100 text-green-700';
    default:
      return 'bg-gray-100 text-gray-800';
  }
}