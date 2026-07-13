import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';

interface AdminUser {
  id: string;
  email: string;
  display_name: string;
  role: string;
  created_at: string;
}

export function Users() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    apiFetch<{ users: AdminUser[] }>('/admin/users').then((result) => {
      if (result.error) {
        setError(result.error.message);
        return;
      }
      setUsers(result.data?.users ?? []);
    });
  }, []);

  return (
    <div>
      <h2 className="text-2xl font-bold mb-4">Users</h2>
      {error ? <p className="mb-4 rounded bg-red-50 p-3 text-sm text-red-700">{error}</p> : null}
      <div className="overflow-hidden rounded-lg bg-white shadow">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Name</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Email</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Role</th>
              <th className="px-4 py-3 text-left text-xs font-semibold uppercase text-gray-500">Created</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {users.map((user) => (
              <tr key={user.id}>
                <td className="px-4 py-3 text-sm font-medium text-gray-900">{user.display_name}</td>
                <td className="px-4 py-3 text-sm text-gray-600">{user.email}</td>
                <td className="px-4 py-3 text-sm text-gray-600">{user.role}</td>
                <td className="px-4 py-3 text-sm text-gray-600">
                  {new Date(user.created_at).toLocaleString('id-ID')}
                </td>
              </tr>
            ))}
            {users.length === 0 && !error ? (
              <tr>
                <td className="px-4 py-6 text-sm text-gray-500" colSpan={4}>
                  No users found.
                </td>
              </tr>
            ) : null}
          </tbody>
        </table>
      </div>
    </div>
  );
}
