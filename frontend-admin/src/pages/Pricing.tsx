import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';
import { formatRupiah } from '../utils/format';

interface PricingEntry {
  id: string;
  item_type: string;
  role: string;
  price: number;
  is_active: boolean;
  updated_at: string;
}

const ITEM_TYPES = [
  'mock_itp', 'mock_ibt', 'mock_ielts', 'mock_toeic',
  'tutor_bot_premium', 'official_toefl', 'official_toeic',
];
const ROLES = ['student', 'teacher', 'partner', 'admin'];

export function Pricing() {
  const [pricing, setPricing] = useState<PricingEntry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // New entry form
  const [newItemType, setNewItemType] = useState('mock_itp');
  const [newRole, setNewRole] = useState('student');
  const [newPrice, setNewPrice] = useState('0');
  const [saving, setSaving] = useState(false);

  async function load() {
    setLoading(true);
    setError(null);
    const res = await apiFetch<{ pricing: PricingEntry[] }>('/admin/pricing');
    if (res.error) setError(res.error.message);
    else setPricing(res.data?.pricing ?? []);
    setLoading(false);
  }

  useEffect(() => {
    load();
  }, []);

  async function addPricing() {
    const price = parseInt(newPrice, 10);
    if (Number.isNaN(price) || price < 0) {
      setError('Price must be a non-negative number');
      return;
    }
    setSaving(true);
    const res = await apiFetch('/admin/pricing', {
      method: 'POST',
      body: JSON.stringify({ item_type: newItemType, role: newRole, price }),
    });
    setSaving(false);
    if (res.error) {
      setError(res.error.message);
    } else {
      setNewPrice('0');
      load();
    }
  }

  async function deletePricing(itemType: string, role: string) {
    if (!confirm(`Deactivate pricing for ${itemType} / ${role}?`)) return;
    const res = await apiFetch(`/admin/pricing/${itemType}/${role}`, { method: 'DELETE' });
    if (res.error) {
      setError(res.error.message);
    } else {
      load();
    }
  }

  return (
    <div>
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Pricing</h2>
      <p className="mb-6 text-sm text-osee-400">Atur harga item per peran dan nonaktifkan tarif yang tidak dipakai.</p>
      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}

      {/* Add new pricing */}
      <div className="mb-6 card p-5">
        <h3 className="mb-3 text-lg font-semibold">Set Price</h3>
        <div className="flex flex-wrap gap-3">
          <select
            value={newItemType}
            onChange={(e) => setNewItemType(e.target.value)}
            className="input"
          >
            {ITEM_TYPES.map((t) => (
              <option key={t} value={t}>
                {t}
              </option>
            ))}
          </select>
          <select
            value={newRole}
            onChange={(e) => setNewRole(e.target.value)}
            className="input"
          >
            {ROLES.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </select>
          <input
            type="number"
            value={newPrice}
            onChange={(e) => setNewPrice(e.target.value)}
            min="0"
            className="input w-32 text-sm"
            placeholder="Price (IDR)"
          />
          <button
            className="btn-primary text-sm disabled:opacity-50"
            disabled={saving}
            onClick={addPricing}
          >
            {saving ? 'Saving...' : 'Set Price'}
          </button>
        </div>
      </div>

      {/* Pricing list */}
      {loading ? (
        <p className="text-gray-500">Loading...</p>
      ) : (
        <div className="card overflow-hidden">
          <table className="min-w-full divide-y divide-gray-200">
            <thead className="bg-gray-50">
              <tr>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Item Type</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Role</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Price (IDR)</th>
                <th className="px-4 py-3 text-center text-xs font-semibold uppercase tracking-wider text-osee-400">Active</th>
                <th className="px-4 py-3 text-xs font-semibold uppercase tracking-wider text-osee-400">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {pricing.length === 0 ? (
                <tr>
                  <td className="px-4 py-6 text-sm text-gray-500" colSpan={5}>
                    No pricing entries.
                  </td>
                </tr>
              ) : (
                pricing.map((p) => (
                  <tr key={p.id} className="table-row">
                    <td className="px-4 py-3 text-sm font-mono text-osee-900">{p.item_type}</td>
                    <td className="px-4 py-3 text-sm text-osee-500">{p.role}</td>
                    <td className="px-4 py-3 text-right text-sm font-medium">{formatRupiah(p.price)}</td>
                    <td className="px-4 py-3 text-center text-sm">
                      <span className={p.is_active ? 'text-green-600' : 'text-gray-400'}>
                        {p.is_active ? '✓' : '✗'}
                      </span>
                    </td>
                    <td className="px-4 py-3">
                      <button
                        className="rounded-lg bg-red-50 px-2 py-1 text-xs font-semibold text-red-600 hover:bg-red-100"
                        onClick={() => deletePricing(p.item_type, p.role)}
                      >
                        Deactivate
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}

