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
    apiFetch<{ valid: boolean }>('/auth/verify', { method: 'POST' })
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
      <aside className="flex w-64 flex-shrink-0 flex-col bg-osee-900 text-white">
        <div className="flex items-center justify-between p-5">
          <div>
            <h1 className="text-xl font-extrabold tracking-tight">OSEE</h1>
            <p className="text-xs text-osee-400">Admin Panel</p>
          </div>
          <button
            type="button"
            className="rounded-lg bg-white/10 p-2 text-xs text-white transition-colors hover:bg-white/20"
            onClick={() => {
              adminLogout();
              setIsAuthed(false);
            }}
            title="Logout"
          >
            <svg className="h-4 w-4" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
            </svg>
          </button>
        </div>
        <nav className="flex-1 space-y-0.5 px-3">
          {navItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              end={item.end}
              className={({ isActive }) =>
                `block rounded-xl px-3 py-2.5 text-sm font-medium transition-all ${
                  isActive
                    ? 'bg-osee-600 text-white shadow-lg shadow-osee-600/30'
                    : 'text-osee-400 hover:bg-white/10 hover:text-white'
                }`
              }
            >
              {item.label}
            </NavLink>
          ))}
        </nav>
        <div className="p-4 text-xs text-osee-400/60">
          OSEE Education Hub<br />v1.0
        </div>
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
    <main className="flex min-h-screen items-center justify-center bg-osee-50 p-6">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-3xl font-extrabold tracking-tight text-osee-900">OSEE</h1>
          <p className="mt-1 text-sm font-medium text-osee-400">Admin Panel</p>
        </div>
        <form onSubmit={handleSubmit} className="card p-8">
          <div className="space-y-5">
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Email</span>
              <input
                className="input mt-1.5 w-full"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
                type="email"
                placeholder="admin@osee.co.id"
                required
              />
            </label>
            <label className="block">
              <span className="text-xs font-semibold uppercase tracking-wider text-osee-400">Password</span>
              <input
                className="input mt-1.5 w-full"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                type="password"
                placeholder="••••••••"
                required
              />
            </label>
          </div>
          {error ? <p className="mt-4 rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{error}</p> : null}
          <button
            className="btn-primary mt-6 w-full"
            disabled={loading}
            type="submit"
          >
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
        </form>
        <p className="mt-6 text-center text-xs text-osee-400">
          Official ETS Test Center · Since 2014
        </p>
      </div>
    </main>
  );
}