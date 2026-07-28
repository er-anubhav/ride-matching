import React from 'react';
import { Home, Users, CreditCard, Car, LogOut, Activity, DollarSign, UserCheck } from 'lucide-react';

interface User {
  id: string;
  name: string;
  role: string;
  email: string;
}

interface SidebarProps {
  user: User | null;
  onLogout: () => void;
}

const navItems = [
  { icon: Home, label: 'Dashboard', section: 'dashboard' },
  { icon: Activity, label: 'Live Dispatch', section: 'live-dispatch' },
  { icon: Users, label: 'KYC Management', section: 'kyc' },
  { icon: DollarSign, label: 'Pricing Rules', section: 'pricing' },
  { icon: UserCheck, label: 'User Accounts', section: 'users' },
  { icon: CreditCard, label: 'Payments', section: 'payments' },
  { icon: Car, label: 'Trip Reports', section: 'trips' },
];


const Sidebar: React.FC<SidebarProps> = ({ user, onLogout }) => {
  const currentPath = window.location.pathname;

  const getInitials = (name: string | undefined) => {
    if (!name) return 'A';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  };

  const handleNavClick = (section: string) => {
    window.location.href = `/${section}`;
  };

  return (
    <aside
      className="w-[--sidebar-width] min-h-screen bg-[var(--surface-raised)] border-r border-[var(--border)] flex flex-col sticky top-0 h-screen overflow-y-auto flex-shrink-0 z-10"
      style={{ boxShadow: '2px 0 6px rgba(0,0,0,0.06)' }}
      role="navigation"
      aria-label="Admin navigation"
    >
      {/* Header */}
      <div className="px-4 py-5 border-b font-sans border-[var(--border)]" style={{ background: 'linear-gradient(180deg, #fff 0%, #f8f5f0 100%)' }}>
        <div className="flex items-center gap-3">
          <div>
            <div className="text-[1.5rem] text-[var(--text-primary)] leading-[1.2]">UrbanPulse</div>
            <div className="text-[0.6rem] text-[var(--text-muted)] uppercase tracking-[0.08em]">Admin Panel</div>
          </div>
        </div>
      </div>

      {/* Nav */}
      <nav className="flex-1 px-2.5 py-3 flex flex-col gap-0.5">
        <span className="text-[0.6375rem]  text-[var(--text-muted)] uppercase tracking-[0.1em] px-2 pt-2.5 pb-1 mt-1">
          Main
        </span>
        {navItems.map(item => {
          const Icon = item.icon;
          const isActive = currentPath.includes(item.section);
          return (
            <button
              key={item.section}
              id={`nav-${item.section}`}
              className={`flex items-center gap-2.5 px-3 py-[0.5625rem] rounded-[--r-sm] text-[0.875rem] font-medium cursor-pointer transition-all duration-[120ms] border border-transparent bg-none font-sans w-full text-left ${
                isActive
                  ? 'bg-[var(--surface-inset)] text-[var(--brand-dark)]  border-[var(--border-strong)]'
                  : 'text-[var(--text-secondary)] hover:bg-[var(--bg)] hover:text-[var(--text-primary)] hover:border-[var(--border)]'
              }`}
              style={
                isActive
                  ? { boxShadow: '0 1px 3px rgba(0,0,0,0.1) inset, 0 1px 0 rgba(255,255,255,0.7)' }
                  : { boxShadow: isActive ? undefined : undefined }
              }
              onClick={() => handleNavClick(item.section)}
              aria-current={isActive ? 'page' : undefined}
            >
              <span className="w-[18px] text-center flex-shrink-0 flex items-center justify-center">
                <Icon size={18} />
              </span>
              <span className="flex-1">{item.label}</span>
            </button>
          );
        })}
      </nav>

      {/* Footer */}
      <div
        className="px-2.5 py-3 border-t border-[var(--border)]"
        style={{ background: 'linear-gradient(0deg, #f3efe8 0%, #f8f5f0 100%)' }}
      >
        {user && (
          <div className="flex items-center gap-2.5 px-2.5 py-2 rounded-[--r-sm] bg-[var(--bg)] border border-[var(--border)] mb-2" style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.14) inset, 0 1px 0 #ffffff' }}>
            <div
              className="w-8 h-8 rounded-full flex items-center justify-center text-[0.75rem]  text-white flex-shrink-0"
              style={{
                background: 'linear-gradient(145deg, #f0c07a, var(--brand))',
                boxShadow: '0 1px 0 rgba(255,255,255,0.4) inset, 0 1px 3px rgba(0,0,0,0.18)',
              }}
              aria-hidden="true"
            >
              {getInitials(user.name)}
            </div>
            <div>
              <div className="text-[0.8125rem]  text-[var(--text-primary)]">{user.name || 'Admin'}</div>
              <div className="text-[0.675rem] text-[var(--text-muted)]">{user.role || 'Administrator'}</div>
            </div>
          </div>
        )}
        <button
          id="nav-logout"
          className="flex items-center gap-2.5 px-3 py-[0.5625rem] rounded-[--r-sm] text-[0.875rem] font-medium cursor-pointer transition-all duration-[120ms] border border-transparent bg-none font-sans w-full text-left text-[var(--danger)] hover:bg-[var(--danger-bg)] hover:border-[rgba(192,57,43,0.2)]"
          onClick={onLogout}
        >
          <span className="w-[18px] text-center flex-shrink-0 flex items-center justify-center">
            <LogOut size={18} />
          </span>
          <span className="flex-1">Sign out</span>
        </button>
      </div>
    </aside>
  );
};

export default Sidebar;
