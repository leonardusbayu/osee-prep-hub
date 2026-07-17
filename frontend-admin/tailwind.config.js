/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        osee: {
          50: '#f8fafc',   // slate-50 — page bg
          100: '#f1f5f9',   // slate-100 — surface variant
          200: '#e2e8f0',   // slate-200 — borders
          300: '#cbd5e1',   // slate-300
          400: '#94a3b8',   // slate-400 — muted text
          500: '#64748b',   // slate-500 — secondary text
          600: '#4f46e5',   // indigo-600 — primary
          700: '#4338ca',   // indigo-700
          800: '#3730a3',   // indigo-800 — primary dark
          900: '#0f172a',   // slate-900 — primary text
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        xl: '12px',
        '2xl': '16px',
      },
      boxShadow: {
        card: '0 2px 8px 0 rgba(15, 23, 42, 0.04)',
        'card-hover': '0 4px 16px 0 rgba(15, 23, 42, 0.08)',
      },
    },
  },
  plugins: [],
};