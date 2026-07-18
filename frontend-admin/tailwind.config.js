/** @type {import('tailwindcss').Config} */
// osee scale ported to OseeTheme (base theme) — P0-1 theme unification.
// Token names unchanged so every osee-* utility class keeps working;
// only the rendered colors change to match the OseeTheme palette.
//   gold #C9A96E  ·  navy #1A1A2E  ·  cream #F7F5F0  ·  ink #1A1A2E
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        osee: {
          50: '#F7F5F0',   // OseeTheme.paper — page bg
          100: '#F0EEE7',  // OseeTheme.surfaceVariant — surface variant
          200: '#E8E6E1',  // OseeTheme.border — borders
          300: '#D8D2C4',  // neutral between border and muted
          400: '#9B9B9B',  // OseeTheme.textMuted — muted text
          500: '#6D6D7C',  // OseeTheme.textSecondary — secondary text
          600: '#1A1A2E',  // OseeTheme.ink/primary — primary buttons (navy)
          700: '#2E2E4A',  // OseeTheme.primaryLight — hover
          800: '#12122A',  // darker navy — active/pressed
          900: '#1A1A2E',  // OseeTheme.ink — primary text
        },
        // Accent scales preserved for semantic badges (success/warn/danger/info).
        // Primary action color is now OseeTheme navy (osee-600), not indigo.
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