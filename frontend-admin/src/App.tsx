import { Routes, Route, NavLink } from 'react-router-dom';
import { Dashboard } from './pages/Dashboard';
import { Users } from './pages/Users';
import { Content } from './pages/Content';
import { Commission } from './pages/Commission';
import { Analytics } from './pages/Analytics';

const navItems = [
  { to: '/', label: 'Dashboard', end: true },
  { to: '/users', label: 'Users' },
  { to: '/content', label: 'Content' },
  { to: '/commission', label: 'Commission' },
  { to: '/analytics', label: 'Analytics' },
];

export function App() {
  return (
    <div className="min-h-screen bg-gray-50 flex">
      {/* Sidebar */}
      <aside className="w-64 bg-osee-700 text-white p-4 flex-shrink-0">
        <h1 className="text-xl font-bold mb-6">OSEE Admin</h1>
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