/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{js,jsx,ts,tsx}",
    "./public/index.html",
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ['Varela Round', 'Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        sans: ['Varela Round', 'Inter', '-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'sans-serif'],
        mono: ['SF Mono', 'Fira Code', 'Consolas', 'monospace'],
      },
      colors: {
        surface: {
          DEFAULT: '#f8f5f0',
          raised: '#ffffff',
          inset: '#e8e4dc',
        },
        bg: {
          DEFAULT: '#f0ece4',
        },
        border: {
          DEFAULT: '#d4cfc6',
          strong: '#bbb5aa',
        },
        text: {
          primary: '#2a2520',
          secondary: '#6b6560',
          muted: '#9e9890',
        },
        brand: {
          DEFAULT: '#c97b2e',
          dark: '#a8631f',
          light: '#e9a95a',
          bg: '#fdf3e7',
        },
        success: {
          DEFAULT: '#3a7d44',
          bg: '#edf6ef',
        },
        danger: {
          DEFAULT: '#c0392b',
          bg: '#fcecea',
        },
        warning: {
          DEFAULT: '#9c6a00',
          bg: '#fdf6e3',
        },
        info: {
          DEFAULT: '#1a6ea8',
          bg: '#e8f3fb',
        },
      },
      boxShadow: {
        'raised': '0 1px 0 #ffffff inset, 0 -1px 0 rgba(0,0,0,0.06) inset, 0 2px 4px rgba(0,0,0,0.10), 0 1px 2px rgba(0,0,0,0.08)',
        'sunken': '0 1px 3px rgba(0,0,0,0.14) inset, 0 1px 0 #ffffff',
        'card': '0 1px 0 #ffffff inset, 0 2px 8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06)',
        'deep': '0 4px 16px rgba(0,0,0,0.12), 0 1px 4px rgba(0,0,0,0.08)',
        'brand-glow': '0 1px 2px rgba(249, 115, 22, 0.28), 0 4px 14px rgba(249, 115, 22, 0.24)',
        'brand-glow-hover': '0 2px 4px rgba(234, 88, 12, 0.32), 0 8px 22px rgba(234, 88, 12, 0.28)',
      },
      borderRadius: {
        'sm': '6px',
        'md': '10px',
        'lg': '14px',
      },
      transitionTimingFunction: {
        'fast': '120ms ease',
        'base': '200ms ease',
      },
      keyframes: {
        'login-card-in': {
          from: { opacity: '0', transform: 'translateY(16px) scale(0.98)' },
          to: { opacity: '1', transform: 'translateY(0) scale(1)' },
        },
        'shake-error': {
          '0%,100%': { transform: 'translateX(0)' },
          '20%': { transform: 'translateX(-5px)' },
          '40%': { transform: 'translateX(5px)' },
          '60%': { transform: 'translateX(-3px)' },
          '80%': { transform: 'translateX(3px)' },
        },
        'tab-fade-in': {
          from: { opacity: '0', transform: 'translateY(4px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        'modal-in': {
          from: { opacity: '0', transform: 'scale(0.96) translateY(8px)' },
          to: { opacity: '1', transform: 'scale(1) translateY(0)' },
        },
        'fade-overlay': {
          from: { opacity: '0' },
          to: { opacity: '1' },
        },
        'spin-slow': {
          to: { transform: 'rotate(360deg)' },
        },
      },
      animation: {
        'login-card': 'login-card-in 300ms cubic-bezier(0.16, 1, 0.3, 1) both',
        'shake': 'shake-error 320ms cubic-bezier(0.36, 0.07, 0.19, 0.97) both',
        'tab-in': 'tab-fade-in 200ms ease forwards',
        'modal-in': 'modal-in 200ms ease',
        'fade-overlay': 'fade-overlay 150ms ease',
        'spin-slow': 'spin-slow 0.65s linear infinite',
      },
    },
  },
  plugins: [],
};
