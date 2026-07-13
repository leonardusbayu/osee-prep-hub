import { Routes, Route, NavLink } from 'react-router-dom';
import { FormEvent, useState } from 'react';
import { Dashboard } from './pages/Dashboard';
import { Users } from './pages/Users';
import { Content } from './pages/Content';
import { Commission } from './pages/Commission';
import { Analytics } from './pages/Analytics';
import { adminLogin, adminLogout } from './api/client';

const navItems = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/users', label: 'Users' },
  { to: '/content', label: 'Content' },
  { to: '/commission', label: 'Commission' },
  { to: '/analytics', label: 'Analytics' },
];

export function App() {
  const [isAuthed, setIsAuthed] = useState(() => Boolean(localStorage.getItem('osee_admin_token')));

  if (!isAuthed) {
    return <LoginScreen onLogin={() => setIsAuthed(true)} />;
  }

  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Sidebar */}
      <aside className="w-64 bg-osee-700 text-white p-4 flex-shrink-0">
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
                `block px-3 py-2 rounded ${
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
      <main className="flex-1 p-6 overflow-x-auto">
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/users" element={<Users />} />
          <Route path="/content" element={<Content />} />
          <Route path="/commission" element={<Commission />} />
          <Route path="/analytics" element={<Analytics />} />
        </Routes>
      </main>
    </div>
  );
}

function LoginScreen({ onLogin }: { onLogin: () => void }) {
  const [email, setEmail] = useState('admin@test.com');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
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
    <main className="min-h-screen bg-gray-50 flex items-center justify-center p-6">
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
