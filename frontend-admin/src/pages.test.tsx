import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';

import { Dashboard } from './pages/Dashboard';
import { Users } from './pages/Users';
import { Teachers } from './pages/Teachers';
import { Students } from './pages/Students';
import { Pricing } from './pages/Pricing';
import { KnowledgeBase } from './pages/KnowledgeBase';
import { Commission } from './pages/Commission';
import { Ambassadors } from './pages/Ambassadors';
import { Analytics } from './pages/Analytics';
import { Orders } from './pages/Orders';
import { App } from './App';

/** Render a page wrapped in the router it needs (NavLink etc.). */
function renderPage(el: React.ReactElement) {
  return render(<MemoryRouter>{el}</MemoryRouter>);
}

/** Stub fetch to return a canned JSON body for any call. */
function stubFetch(responses: Record<string, unknown> = {}, status = 200) {
  const fetchMock = vi.fn(async (url: string) => {
    const path = String(url).replace(/^https?:\/\/[^/]+/, '').replace(/^\/api/, '');
    const body = responses[path] ?? responses['default'] ?? {};
    return new Response(JSON.stringify(body), {
      status,
      headers: { 'Content-Type': 'application/json' },
    });
  });
  vi.stubGlobal('fetch', fetchMock);
  return fetchMock;
}

describe('admin pages render', () => {
  beforeEach(() => {
    localStorage.setItem('osee_admin_token', 'fake-admin-token');
  });

  it('Dashboard fetches stats and renders them', async () => {
    const fetchMock = stubFetch({
      '/admin/stats': {
        total_users: 100,
        active_teachers: 20,
        total_students: 80,
        total_revenue: 5000000,
        commission_paid: 200000,
        commission_pending: 50000,
        ai_usage: 1234,
        total_bookings: 42,
      },
    });
    renderPage(<Dashboard />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    // Stats should appear once the async state resolves.
    await waitFor(() => expect(screen.getByText('100')).toBeInTheDocument());
  });

  it('Dashboard shows error when API fails', async () => {
    stubFetch({ default: { error: { code: 'X', message: 'boom' } } });
    renderPage(<Dashboard />);
    await waitFor(() => expect(screen.getByText(/boom/i)).toBeInTheDocument());
  });

  it('Users renders user rows with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/users': { users: [{ id: 'u1', email: 'a@b.com', role: 'teacher', display_name: 'A' }] },
    });
    renderPage(<Users />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('a@b.com')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('A')).toBeInTheDocument());
  });

  it('Teachers renders teacher rows with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/teachers': { teachers: [{ id: 't1', display_name: 'T', email: 't@e.com' }] },
    });
    renderPage(<Teachers />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('t@e.com')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('T')).toBeInTheDocument());
  });

  it('Students renders student rows with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/students': { students: [{ id: 's1', display_name: 'S', email: 's@e.com' }] },
    });
    renderPage(<Students />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('s@e.com')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('S')).toBeInTheDocument());
  });

  it('Pricing renders pricing rows with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/pricing': [{ id: 'p1', item_type: 'mock_ibt', role: 'student', price: 150000 }],
    });
    renderPage(<Pricing />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('mock_ibt')).toBeInTheDocument());
  });

  it('Knowledge Base renders and loads documents on refresh', async () => {
    const fetchMock = stubFetch({
      '/admin/knowledge-base/documents': { documents: [{ id: 'kb1', title: 'Grammar ref' }] },
    });
    renderPage(<KnowledgeBase />);
    // Knowledge Base only fetches when the Refresh button is clicked (no fetch on mount).
    const refreshButtons = screen.getAllByText(/^Refresh$/i);
    fireEvent.click(refreshButtons[0]);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('Grammar ref')).toBeInTheDocument());
  });

  it('Commission renders totals with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/commission': { total_paid: 100000, total_pending: 5000, by_teacher: [] },
    });
    renderPage(<Commission />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText(/100.000|100000/i)).toBeInTheDocument());
  });

  it('Ambassadors renders ambassador rows with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/ambassadors': { ambassadors: [{ id: 'a1', display_name: 'Amb', recruited_count: 3, teacher_profiles: [{ is_ambassador: true, ambassador_recruited_at: null, ambassador_recruited_by: null }], email: 'amb@e.com' }] },
    });
    renderPage(<Ambassadors />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('Amb')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('amb@e.com')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('3')).toBeInTheDocument());
  });

  it('Analytics renders stats with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/analytics': { total_teachers: 5, total_students: 50, total_bookings: 7, revenue: 999 },
    });
    renderPage(<Analytics />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('5')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('50')).toBeInTheDocument());
  });

  it('Orders renders order rows with real content', async () => {
    const fetchMock = stubFetch({
      '/admin/orders': { orders: [{ id: 'ord-1', user: { email: 'teacher@e.com', display_name: 'Pak Budi', role: 'teacher' }, order_type: 'voucher_resale', status: 'paid', total_amount: 150000, created_at: '2026-01-01T00:00:00Z', order_items: [{ id: 'oi1', item_type: 'mock_ibt', quantity: 1, unit_price: 150000, fulfillment_status: 'voucher_generated', assigned_student_id: null }] }] },
    });
    renderPage(<Orders />);
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('Pak Budi')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText('teacher@e.com')).toBeInTheDocument());
    await waitFor(() => expect(screen.getByText(/mock_ibt/)).toBeInTheDocument());
  });
});

describe('App auth flow', () => {
  it('shows login screen when no token is present', async () => {
    localStorage.removeItem('osee_admin_token');
    // Stub fetch so /auth/verify (if it runs) returns invalid.
    stubFetch({ default: { valid: false } });
    render(
      <MemoryRouter>
        <App />
      </MemoryRouter>
    );
    // The login screen shows a sign-in prompt.
    await waitFor(() => expect(screen.getByText(/sign in/i)).toBeInTheDocument());
  });

  it('401 response triggers logout (token cleared)', async () => {
    localStorage.setItem('osee_admin_token', 'expired');
    const fetchMock = vi.fn(async () =>
      new Response('{"error":{"code":"UNAUTHORIZED","message":"expired"}}', {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      })
    );
    vi.stubGlobal('fetch', fetchMock);
    render(
      <MemoryRouter>
        <App />
      </MemoryRouter>
    );
    await waitFor(() => expect(fetchMock).toHaveBeenCalled());
    // After a 401, the token should be cleared and login shown.
    await waitFor(() => {
      expect(localStorage.getItem('osee_admin_token')).toBeNull();
    }, { timeout: 2000 });
  });
});