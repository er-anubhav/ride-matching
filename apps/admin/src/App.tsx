import React, { useState, useEffect, useRef } from 'react';
import './App.css';
import Sidebar from './components/Sidebar';
import Dashboard from './components/Dashboard';
import { useAuth } from './hooks/useAuth';
import { User, Lock, Eye, EyeOff, AlertCircle } from 'lucide-react';

const DEFAULT_USERNAME = process.env.REACT_APP_ADMIN_USERNAME || '';
const DEFAULT_PASSWORD = process.env.REACT_APP_ADMIN_PASSWORD || '';

function App() {
  const { user, login, logout, isAuthenticated } = useAuth();
  const [loginError, setLoginError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [rememberMe, setRememberMe] = useState(false);
  const [username, setUsername] = useState(DEFAULT_USERNAME);
  const [password, setPassword] = useState(DEFAULT_PASSWORD);
  const usernameRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!isAuthenticated && usernameRef.current && !DEFAULT_USERNAME) {
      usernameRef.current.focus();
    }
  }, [isAuthenticated]);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoginError('');
    setIsLoading(true);

    const credentials = {
      username: username.trim(),
      password,
    };

    if (!credentials.username || !credentials.password) {
      setLoginError('Please enter both username and password.');
      setIsLoading(false);
      return;
    }

    const success = await login(credentials);
    setIsLoading(false);

    if (!success) {
      setLoginError('Invalid credentials. Please check and try again.');
    }
  };

  if (!isAuthenticated) {
    return (
      <div className="min-h-screen w-full grid place-items-center bg-[#FAFAFA] p-6 relative z-[1]">
        {/* Dot-grid background */}
        <div
          className="fixed inset-0 pointer-events-none z-0"
          style={{ backgroundImage: 'radial-gradient(#E5E7EB 1px, transparent 1px)', backgroundSize: '24px 24px' }}
        />

        <div
          className="relative z-[1] w-full max-w-[460px] bg-white rounded-[20px] border border-[#E5E7EB] px-8 py-8 pb-7 animate-login-card"
          role="main"
          style={{
            boxShadow: '0 1px 3px rgba(0,0,0,0.04), 0 8px 24px rgba(0,0,0,0.06), 0 32px 56px rgba(0,0,0,0.04)',
          }}
        >
          {/* Brand heading */}
          <header className="text-center mb-5">
            <h1 className="text-2xl  text-[#111827] tracking-[-0.03em] leading-[1.15] mb-1">
              Admin Portal
            </h1>
            <p className="text-[13.5px] text-[#6B7280] leading-5 font-normal">
              Sign in to continue to your dashboard.
            </p>
          </header>

          {/* Error banner */}
          {loginError && (
            <div
              id="login-error"
              className="flex items-start gap-2.5 mb-3.5 px-3 py-2 bg-[#FFF1F2] border border-[#FECDD3] rounded-[10px] text-[#BE123C] text-[13.5px] leading-[1.45] animate-shake"
              role="alert"
              aria-live="assertive"
            >
              <span className="flex-shrink-0 flex mt-0.5">
                <AlertCircle size={15} />
              </span>
              {loginError}
            </div>
          )}

          {/* Form */}
          <form
            className="flex flex-col gap-3"
            onSubmit={handleLogin}
            noValidate
            aria-label="Admin sign-in"
            aria-describedby={loginError ? 'login-error' : undefined}
          >
            {/* Username */}
            <div className="flex flex-col gap-1">
              <label className="text-[13.5px] font-medium text-[#374151]" htmlFor="username">
                Username
              </label>
              <div className="relative flex items-center group">
                <span className="absolute left-4 flex items-center text-[#9CA3AF] pointer-events-none z-[1] transition-colors duration-200 group-focus-within:text-[#F97316]" aria-hidden="true">
                  <User size={16} />
                </span>
                <input
                  id="username"
                  ref={usernameRef}
                  className="w-full h-11 pl-11 pr-4 bg-white border-[1.5px] border-[#E5E7EB] rounded-xl text-[#111827] font-sans text-[15px] outline-none transition-[border-color,box-shadow] duration-200 placeholder:text-[#9CA3AF] focus:border-[#F97316] focus:shadow-[0_0_0_3px_rgba(249,115,22,0.12)] disabled:bg-[#F9FAFB] disabled:text-[#9CA3AF] disabled:cursor-not-allowed"
                  type="text"
                  name="username"
                  value={username}
                  onChange={e => setUsername(e.target.value)}
                  placeholder="Enter your username"
                  autoComplete="username"
                  spellCheck={false}
                  autoCapitalize="none"
                  required
                  disabled={isLoading}
                  aria-required="true"
                />
              </div>
            </div>

            {/* Password */}
            <div className="flex flex-col gap-1">
              <label className="text-[13.5px] font-medium text-[#374151]" htmlFor="password">
                Password
              </label>
              <div className="relative flex items-center group">
                <span className="absolute left-4 flex items-center text-[#9CA3AF] pointer-events-none z-[1] transition-colors duration-200 group-focus-within:text-[#F97316]" aria-hidden="true">
                  <Lock size={16} />
                </span>
                <input
                  id="password"
                  className="w-full h-11 pl-11 pr-12 bg-white border-[1.5px] border-[#E5E7EB] rounded-xl text-[#111827] font-sans text-[15px] outline-none transition-[border-color,box-shadow] duration-200 placeholder:text-[#9CA3AF] focus:border-[#F97316] focus:shadow-[0_0_0_3px_rgba(249,115,22,0.12)] disabled:bg-[#F9FAFB] disabled:text-[#9CA3AF] disabled:cursor-not-allowed"
                  type={showPassword ? 'text' : 'password'}
                  name="password"
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="Enter your password"
                  autoComplete="current-password"
                  required
                  disabled={isLoading}
                  aria-required="true"
                />
                <button
                  type="button"
                  className="absolute right-1 top-1 bottom-1 w-11 bg-none border-none cursor-pointer flex items-center justify-center text-[#9CA3AF] rounded-lg transition-[color,background] duration-200 hover:text-[#6B7280] hover:bg-[#F3F4F6] disabled:opacity-40 disabled:cursor-not-allowed"
                  onClick={() => setShowPassword(v => !v)}
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  disabled={isLoading}
                >
                  {showPassword
                    ? <EyeOff size={16} />
                    : <Eye size={16} />}
                </button>
              </div>
            </div>

            {/* Remember me + Forgot */}
            <div className="flex items-center justify-between mt-0.5">
              <label className="flex items-center gap-2 cursor-pointer select-none text-[13.5px] text-[#6B7280]">
                <input
                  type="checkbox"
                  className="w-4 h-4 accent-[#F97316] cursor-pointer flex-shrink-0 m-0"
                  checked={rememberMe}
                  onChange={e => setRememberMe(e.target.checked)}
                  disabled={isLoading}
                />
                Remember me
              </label>
              <button
                type="button"
                className="text-[13.5px] text-[#F97316] font-medium bg-none border-none cursor-pointer p-0 font-sans transition-colors duration-200 hover:text-[#EA580C] hover:underline"
                onClick={() => alert('Contact your system administrator to reset your password.')}
                disabled={isLoading}
              >
                Forgot password?
              </button>
            </div>

            {/* Submit */}
            <button
              id="login-submit-btn"
              className="w-full h-11 flex items-center justify-center gap-2 bg-gradient-to-r from-[#FB923C] to-[#F97316] text-white border-none rounded-xl font-sans text-[15px]  tracking-[-0.01em] cursor-pointer mt-1 transition-[transform,box-shadow,background] duration-200 hover:from-[#F97316] hover:to-[#EA580C] hover:-translate-y-0.5 active:translate-y-px active:scale-[0.99] active:duration-[80ms] disabled:opacity-60 disabled:cursor-not-allowed disabled:transform-none"
              type="submit"
              disabled={isLoading}
              aria-busy={isLoading}
              style={{
                boxShadow: isLoading ? 'none' : '0 1px 2px rgba(249, 115, 22, 0.28), 0 4px 14px rgba(249, 115, 22, 0.24)',
              }}
            >
              {isLoading ? (
                <>
                  <span className="w-4 h-4 border-2 border-white/35 border-t-white rounded-full animate-spin-slow flex-shrink-0" aria-hidden="true" />
                  Signing in...
                </>
              ) : (
                'Sign in'
              )}
            </button>
          </form>

          <p className="mt-4 text-center text-xs text-[#9CA3AF] leading-[1.6]">
            Authorised personnel only · All activity is monitored and logged
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="flex min-h-screen relative z-[1]">
      <Sidebar user={user} onLogout={logout} />
      <main className="flex-1 min-w-0 relative z-[1]" id="main-content" tabIndex={-1}>
        <Dashboard />
      </main>
    </div>
  );
}

export default App;
