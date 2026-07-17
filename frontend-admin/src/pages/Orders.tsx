import { useEffect, useState } from 'react';
import { apiFetch } from '../api/client';
import { formatRupiah } from '../utils/format';

interface OrderItem {
  id: string;
  item_type: string;
  quantity: number;
  unit_price: number;
  fulfillment_status: string;
  assigned_student_id: string | null;
}
interface Order {
  id: string;
  user_id: string;
  user?: { email: string; display_name: string; role: string };
  order_type: string;
  status: string;
  total_amount: number;
  payment_method: string | null;
  created_at: string;
  order_items: OrderItem[];
}

const STATUS_COLORS: Record<string, string> = {
  pending: 'bg-yellow-100 text-yellow-700',
  paid: 'bg-blue-100 text-blue-700',
  fulfilled: 'bg-green-100 text-green-700',
  cancelled: 'bg-gray-100 text-gray-600',
  refunded: 'bg-red-100 text-red-700',
};

export function Orders() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState('');
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [actionMsg, setActionMsg] = useState<string | null>(null);

  function load() {
    setLoading(true);
    setError(null);
    const path = statusFilter ? `/admin/orders?status=${statusFilter}` : '/admin/orders';
    apiFetch<{ orders: Order[] }>(path)
      .then((result) => {
        if (result.error) setError(result.error.message);
        else setOrders(result.data?.orders ?? []);
      })
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    load();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [statusFilter]);

  async function refund(orderId: string) {
    if (!confirm('Refund this order and void its vouchers? This cannot be undone.')) return;
    setActionLoading(orderId);
    setActionMsg(null);
    const res = await apiFetch(`/admin/orders/${orderId}/refund`, { method: 'POST' });
    setActionLoading(null);
    if (res.error) setActionMsg(`Refund failed: ${res.error.message}`);
    else { setActionMsg('Order refunded.'); load(); }
  }

  async function retry(orderId: string) {
    setActionLoading(orderId);
    setActionMsg(null);
    const res = await apiFetch<{ retried: number }>(`/admin/orders/${orderId}/retry-fulfill`, { method: 'POST' });
    setActionLoading(null);
    if (res.error) setActionMsg(`Retry failed: ${res.error.message}`);
    else { setActionMsg(`Retried ${res.data?.retried ?? 0} item(s).`); load(); }
  }

  async function markPaid(orderId: string) {
    if (!confirm('Mark this order as paid (manual/offline payment)? It will be fulfilled immediately.')) return;
    setActionLoading(orderId);
    setActionMsg(null);
    const res = await apiFetch(`/admin/orders/${orderId}/mark-paid`, {
      method: 'POST',
      body: JSON.stringify({ payment_method: 'manual' }),
    });
    setActionLoading(null);
    if (res.error) setActionMsg(`Mark paid failed: ${res.error.message}`);
    else { setActionMsg('Order marked paid + fulfilled.'); load(); }
  }

  async function cancel(orderId: string) {
    if (!confirm('Cancel this order? Vouchers will be voided.')) return;
    setActionLoading(orderId);
    setActionMsg(null);
    const res = await apiFetch(`/admin/orders/${orderId}/cancel`, { method: 'POST' });
    setActionLoading(null);
    if (res.error) setActionMsg(`Cancel failed: ${res.error.message}`);
    else { setActionMsg('Order cancelled.'); load(); }
  }

  const totalOrders = orders.length;
  const pending = orders.filter((o) => o.status === 'pending').length;
  const paid = orders.filter((o) => o.status === 'paid').length;
  const fulfilled = orders.filter((o) => o.status === 'fulfilled').length;
  const refunded = orders.filter((o) => o.status === 'refunded').length;

  return (
    <div>
      <h2 className="mb-1 text-2xl font-extrabold tracking-tight text-osee-900">Orders</h2>
      <p className="mb-6 text-sm text-osee-400">
        All orders across teachers and institutions. Mark pending orders as paid (manual payment), refund, retry fulfillment, or cancel.
      </p>

      {error ? <div className="mb-4 rounded-xl bg-red-50 p-4 text-sm text-red-600">{error}</div> : null}
      {actionMsg ? <div className="mb-4 rounded-xl bg-blue-50 p-4 text-sm text-blue-600">{actionMsg}</div> : null}

      <div className="mb-6 grid grid-cols-2 gap-3 sm:grid-cols-5">
        {[
          { label: 'Total', value: totalOrders, color: 'text-gray-700' },
          { label: 'Pending', value: pending, color: 'text-yellow-600' },
          { label: 'Paid', value: paid, color: 'text-blue-600' },
          { label: 'Fulfilled', value: fulfilled, color: 'text-green-600' },
          { label: 'Refunded', value: refunded, color: 'text-red-600' },
        ].map((s) => (
          <div key={s.label} className="card p-4">
            <div className={`text-2xl font-bold ${s.color}`}>{s.value}</div>
            <div className="text-xs uppercase tracking-wider text-osee-400">{s.label}</div>
          </div>
        ))}
      </div>

      <div className="mb-4 flex items-center gap-2">
        <label className="text-sm font-medium text-osee-400">Filter:</label>
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value)}
          className="rounded-lg border border-gray-200 px-3 py-1.5 text-sm"
        >
          <option value="">All</option>
          <option value="pending">Pending</option>
          <option value="paid">Paid</option>
          <option value="fulfilled">Fulfilled</option>
          <option value="cancelled">Cancelled</option>
          <option value="refunded">Refunded</option>
        </select>
      </div>

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
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Order ID</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Customer</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Items</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Total</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Status</th>
                <th className="px-4 py-3 text-left text-xs font-semibold uppercase tracking-wider text-osee-400">Date</th>
                <th className="px-4 py-3 text-right text-xs font-semibold uppercase tracking-wider text-osee-400">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100">
              {orders.length === 0 ? (
                <tr><td className="px-4 py-6 text-sm text-gray-500" colSpan={7}>No orders found.</td></tr>
              ) : orders.map((o) => (
                <tr key={o.id} className="table-row">
                  <td className="px-4 py-3 text-xs font-mono text-osee-500">{o.id.slice(0, 8)}…</td>
                  <td className="px-4 py-3 text-sm">
                    <div className="font-semibold text-osee-900">{o.user?.display_name ?? '—'}</div>
                    <div className="text-xs text-osee-400">{o.user?.email ?? ''}</div>
                  </td>
                  <td className="px-4 py-3 text-sm">
                    {o.order_items?.map((it, i) => (
                      <div key={i} className="text-xs">
                        {it.quantity}× {it.item_type}
                        <span className="ml-1 text-osee-400">({it.fulfillment_status})</span>
                      </div>
                    ))}
                  </td>
                  <td className="px-4 py-3 text-right text-sm font-semibold">{formatRupiah(o.total_amount)}</td>
                  <td className="px-4 py-3">
                    <span className={`rounded px-2 py-0.5 text-xs font-semibold ${STATUS_COLORS[o.status] ?? 'bg-gray-100 text-gray-600'}`}>
                      {o.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs text-osee-500">
                    {new Date(o.created_at).toLocaleDateString('id-ID')}
                  </td>
                  <td className="px-4 py-3 text-right">
                    <div className="flex justify-end gap-2">
                      {o.status === 'pending' ? (
                        <>
                          <button
                            type="button"
                            className="rounded-lg bg-green-50 px-3 py-1.5 text-xs font-semibold text-green-600 transition-colors hover:bg-green-100 disabled:opacity-50"
                            disabled={actionLoading === o.id}
                            onClick={() => markPaid(o.id)}
                            title="Mark as paid (manual/offline payment)"
                          >
                            {actionLoading === o.id ? '…' : 'Mark Paid'}
                          </button>
                          <button
                            type="button"
                            className="rounded-lg bg-gray-50 px-3 py-1.5 text-xs font-semibold text-gray-600 transition-colors hover:bg-gray-100 disabled:opacity-50"
                            disabled={actionLoading === o.id}
                            onClick={() => cancel(o.id)}
                            title="Cancel this order"
                          >
                            Cancel
                          </button>
                        </>
                      ) : null}
                      {['paid', 'fulfilled'].includes(o.status) ? (
                        <>
                          <button
                            type="button"
                            className="rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-600 transition-colors hover:bg-red-100 disabled:opacity-50"
                            disabled={actionLoading === o.id}
                            onClick={() => refund(o.id)}
                          >
                            {actionLoading === o.id ? '…' : 'Refund'}
                          </button>
                          {o.status === 'paid' ? (
                            <button
                              type="button"
                              className="rounded-lg bg-blue-50 px-3 py-1.5 text-xs font-semibold text-blue-600 transition-colors hover:bg-blue-100 disabled:opacity-50"
                              disabled={actionLoading === o.id}
                              onClick={() => retry(o.id)}
                              title="Retry fulfillment for failed items"
                            >
                              Retry fulfill
                            </button>
                          ) : null}
                        </>
                      ) : null}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}