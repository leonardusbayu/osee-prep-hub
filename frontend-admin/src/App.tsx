import { Routes, Route, NavLink } from 'react-router-dom';
import { FormEvent, useEffect, useState } from 'react';
import { Dashboard } from './pages/Dashboard';
import { Users } from './pages/Users';
import { Content } from './pages/Content';
import { Commission } from './pages/Commission';
import { Analytics } from './pages/Analytics';
import { Pricing } from './pages/Pricing';
import { Ambassadors } from './pages/Ambassadors';
import { Teachers } from './pages/Teachers';
import { Students } from './pages/Students';
import { adminLogin, adminLogout, setUnauthorizedHandler, apiFetch } from './api/client';

const navItems = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/users', label: 'Users' },
  { to: '/teachers', label: 'Teachers' },
  { to: '/students', label: 'Students' },
  { to: '/pricing', label: 'Pricing' },
  { to: '/content', label: 'Knowledge Base' },
  { to: '/commission', label: 'Commission' },
  { to: '/ambassadors', label: 'Ambassadors' },
  { to: '/analytics', label: 'Analytics' },
];

export function App() {
  const [isAuthed, setIsAuthed] = useState(() => Boolean(localStorage.getItem('osee_admin_token')));
  const [authChecked, setAuthChecked] = useState(false);

  // Register global 401 handler — clear token + redirect to login
  useEffect(() => {
    setUnauthorizedHandler(() => {
      adminLogout();
      setIsAuthed(false);
    });
  }, []);

  // Validate token on mount — if invalid/expired, force login
  useEffect(() => {
    if (!isAuthed) {
      setAuthChecked(true);
      return;
    }
    apiFetch<{ valid: boolean }>('/auth/verify')
      .then((res) => {
        if (res.error || res.data?.valid === false) {
          adminLogout();
          setIsAuthed(false);
        }
      })
      .finally(() => setAuthChecked(true));
  }, [isAuthed]);

  if (!authChecked) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-gray-50">
        <p className="text-gray-500">Checking session...</p>
      </main>
    );
  }

  if (!isAuthed) {
    return <LoginScreen onLogin={() => setIsAuthed(true)} />;
  }

  return (
    <div className="flex min-h-screen bg-gray-50">
      {/* Sidebar */}
      <aside className="w-64 flex-shrink-0 bg-osee-700 p-4 text-white">
        <div className="mb-6 flex items-center justify-between gap-3">
          <h1 className="text-xl font-bold">OSEE Admin</h1>
          <button
            type="button"
            className="rounded bg-osee-600 px-2 py-1 text-xs text-white hover:bg-osee-500"
            onClick={() => {
              adminLogout();
              setIsAuthed(false);
            }}
          >
            Logout
          </button>
        </div>
        <nav className="space-y-1">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `block rounded px-3 py-2 text-sm ${
                  isActive ? 'bg-osee-600 text-white' : 'text-osee-50 hover:bg-osee-600'
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
      </aside>

      {/* Main content */}
      <main className="flex-1 overflow-x-auto p-6">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/users" element={<Users />} />
          <Route path="/teachers" element={<Teachers />} />
          <Route path="/students" element={<Students />} />
          <Route path="/pricing" element={<Pricing />} />
          <Route path="/content" element={<Content />} />
          <Route path="/commission" element={<Commission />} />
          <Route path="/ambassadors" element={<Ambassadors />} />
          <Route path="/analytics" element={<Analytics />} />
          <Route path="*" element={<NotFound />} />
        </Routes>
      </main>
    </div>
  );
}

function NotFound(): JSX.Element {
  return (
    <div className="text-center">
      <h1 className="text-3xl font-bold text-gray-700">404</h1>
      <p className="mt-2 text-gray-500">Page not found.</p>
      <a href="/" className="mt-4 inline-block text-osee-700 underline">
        Go to Dashboard
      </a>
    </div>
  );
}

function LoginScreen({ onLogin }: { onLogin: () => void }): JSX.Element {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>): Promise<void> {
    event.preventDefault();
    setLoading(true);
    setError(null);
    const result = await adminLogin(email, password);
    setLoading(false);
    if (result.error) {
      setError(result.error.message);
      return;
    }
    onLogin();
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-gray-50 p-6">
      <form onSubmit={handleSubmit} className="w-full max-w-sm rounded-lg bg-white p-6 shadow">
        <h1 className="text-2xl font-bold text-gray-900">OSEE Admin</h1>
        <div className="mt-6 space-y-4">
          <label className="block">
            <span className="text-sm font-medium text-gray-700">Email</span>
            <input
              className="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              placeholder="admin@osee.co.id"
              required
            />
          </label>
          <label className="block">
            <span className="text-sm font-medium text-gray-700">Password</span>
            <input
              className="mt-1 w-full rounded border border-gray-300 px-3 py-2"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              type="password"
              required
            />
          </label>
        </div>
        {error ? <p className="mt-4 text-sm text-red-600">{error}</p> : null}
        <button
          className="mt-6 w-full rounded bg-osee-700 px-4 py-2 font-semibold text-white hover:bg-osee-600 disabled:opacity-60"
          disabled={loading}
          type="submit"
        >
          {loading ? 'Signing in...' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}