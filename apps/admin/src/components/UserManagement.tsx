import React, { useState } from 'react';
import { Search, UserCheck, UserX } from 'lucide-react';


interface ManagedUser {
  id: string;
  name: string;
  phone: string;
  role: 'RIDER' | 'DRIVER' | 'ADMIN';
  status: 'ACTIVE' | 'SUSPENDED';
  joinedAt: string;
}

export function UserManagement() {
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<ManagedUser[]>([
    { id: 'usr_101', name: 'Rahul Sharma', phone: '+919876543210', role: 'RIDER', status: 'ACTIVE', joinedAt: '2026-06-15' },
    { id: 'drv_202', name: 'Vikram Singh', phone: '+919812345678', role: 'DRIVER', status: 'ACTIVE', joinedAt: '2026-06-20' },
    { id: 'drv_203', name: 'Amit Patel', phone: '+919711223344', role: 'DRIVER', status: 'SUSPENDED', joinedAt: '2026-07-01' },
  ]);

  const toggleStatus = (id: string) => {
    setUsers(users.map(u => {
      if (u.id === id) {
        return { ...u, status: u.status === 'ACTIVE' ? 'SUSPENDED' : 'ACTIVE' };
      }
      return u;
    }));
  };

  const filtered = users.filter(u =>
    u.name.toLowerCase().includes(query.toLowerCase()) ||
    u.phone.includes(query) ||
    u.id.includes(query)
  );

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-semibold text-[var(--text-primary)]">User & Driver Management</h1>
          <p className="text-sm text-[var(--text-muted)]">Search, review profiles, and manage platform account statuses.</p>
        </div>
      </div>

      <div className="relative max-w-md">
        <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="Search by name, phone, or ID..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="w-full pl-10 pr-4 py-2 bg-[var(--surface-raised)] border border-[var(--border)] rounded-lg text-sm focus:outline-none focus:border-[var(--brand)]"
        />
      </div>

      <div className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl overflow-hidden shadow-sm">
        <table className="w-full text-left text-sm">
          <thead className="bg-[var(--bg)] border-b border-[var(--border)] text-xs text-[var(--text-muted)] uppercase tracking-wider">
            <tr>
              <th className="px-6 py-3.5 font-medium">User</th>
              <th className="px-6 py-3.5 font-medium">Phone</th>
              <th className="px-6 py-3.5 font-medium">Role</th>
              <th className="px-6 py-3.5 font-medium">Status</th>
              <th className="px-6 py-3.5 font-medium text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[var(--border)]">
            {filtered.map((u) => (
              <tr key={u.id} className="hover:bg-gray-50/50">
                <td className="px-6 py-4">
                  <div className="font-semibold text-[var(--text-primary)]">{u.name}</div>
                  <div className="text-xs text-[var(--text-muted)] font-mono">{u.id}</div>
                </td>
                <td className="px-6 py-4 text-[var(--text-secondary)]">{u.phone}</td>
                <td className="px-6 py-4">
                  <span className={`px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                    u.role === 'DRIVER' ? 'bg-purple-50 text-purple-700 border-purple-200' : 'bg-blue-50 text-blue-700 border-blue-200'
                  }`}>
                    {u.role}
                  </span>
                </td>
                <td className="px-6 py-4">
                  <span className={`px-2.5 py-0.5 rounded-full text-xs font-medium border ${
                    u.status === 'ACTIVE' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-red-50 text-red-700 border-red-200'
                  }`}>
                    {u.status}
                  </span>
                </td>
                <td className="px-6 py-4 text-right">
                  <button
                    onClick={() => toggleStatus(u.id)}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium border transition-colors ${
                      u.status === 'ACTIVE'
                        ? 'border-red-200 text-red-700 bg-red-50 hover:bg-red-100'
                        : 'border-emerald-200 text-emerald-700 bg-emerald-50 hover:bg-emerald-100'
                    }`}
                  >
                    {u.status === 'ACTIVE' ? <UserX size={14} /> : <UserCheck size={14} />}
                    {u.status === 'ACTIVE' ? 'Suspend' : 'Activate'}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default UserManagement;
