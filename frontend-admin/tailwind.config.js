/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        osee: {
          50: '#f7f5f0',   // paper — warm off-white
          100: '#e8e6e1',   // cloud — light grey
          200: '#c9a96e',   // gold — muted gold
          500: '#6b8e7f',   // sage — green
          600: '#1a1a2e',   // ink — deep navy-black
          700: '#1a1a2e',   // ink — primary
          800: '#121220',   // darker ink
        },
      },
      fontFamily: {
        serif: ['Georgia', 'serif'],
        sans: ['Helvetica', 'Arial', 'sans-serif'],
      },
    },
  },
  plugins: [],
};