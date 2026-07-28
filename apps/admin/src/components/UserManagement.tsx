import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import { Search, UserCheck, UserX, RefreshCw, AlertCircle } from 'lucide-react';

interface ManagedUser {
  id: string;
  name: string;
  phone: string;
  role: 'RIDER' | 'DRIVER' | 'ADMIN';
  status: 'ACTIVE' | 'SUSPENDED';
  kycStatus?: string;
  joinedAt: string;
}

export function UserManagement() {
  const [query, setQuery] = useState('');
  const [users, setUsers] = useState<ManagedUser[]>([]);
  const [loading, setLoading] = useState(false);
  const [actionLoading, setActionLoading] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const token = localStorage.getItem('adminToken') || '';
  const authHeader = { headers: { Authorization: `Bearer ${token}` } };

  const fetchUsers = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await axios.get<{ status: string; users: ManagedUser[] }>('/api/admin/users', authHeader);
      setUsers(res.data.users || []);
    } catch (err: any) {
      setError(err.response?.data?.error || err.message);
    }
    setLoading(false);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  const toggleStatus = async (user: ManagedUser) => {
    setActionLoading(user.id);
    try {
      const endpoint = user.status === 'ACTIVE'
        ? `/api/admin/users/${user.id}/suspend`
        : `/api/admin/users/${user.id}/activate`;
      
      await axios.post(endpoint, {}, authHeader);
      await fetchUsers();
    } catch (err: any) {
      alert(`Failed to update status: ${err.response?.data?.error || err.message}`);
    }
    setActionLoading(null);
  };

  const filtered = users.filter(u =>
    (u.name || '').toLowerCase().includes(query.toLowerCase()) ||
    (u.phone || '').includes(query) ||
    (u.id || '').includes(query) ||
    (u.role || '').toLowerCase().includes(query.toLowerCase())
  );

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center flex-wrap gap-4">
        <div>
          <h1 className="text-xl font-semibold text-[var(--text-primary)]">User & Driver Accounts</h1>
          <p className="text-sm text-[var(--text-muted)]">Real-time database records & platform account activation controls.</p>
        </div>
        <button
          onClick={fetchUsers}
          disabled={loading}
          className="px-3.5 py-2 bg-[var(--surface-raised)] border border-[var(--border)] rounded-lg text-xs font-medium text-[var(--text-primary)] hover:bg-[var(--bg)] flex items-center gap-2 shadow-sm"
        >
          <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
          Refresh Users
        </button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 rounded-xl text-red-700 text-sm flex items-center gap-2">
          <AlertCircle size={16} />
          <span>{error}</span>
        </div>
      )}

      <div className="relative max-w-md">
        <Search size={18} className="absolute left-3.5 top-1/2 -translate-y-1/2 text-gray-400" />
        <input
          type="text"
          placeholder="Search by name, phone, ID, or role..."
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          className="w-full pl-10 pr-4 py-2 bg-[var(--surface-raised)] border border-[var(--border)] rounded-lg text-sm focus:outline-none focus:border-[var(--brand)] shadow-sm"
        />
      </div>

      <div className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl overflow-hidden shadow-sm">
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="bg-[var(--bg)] border-b border-[var(--border)] text-xs text-[var(--text-muted)] uppercase tracking-wider font-mono">
              <tr>
                <th className="px-6 py-3.5 font-medium">User Details</th>
                <th className="px-6 py-3.5 font-medium">Phone</th>
                <th className="px-6 py-3.5 font-medium">Role</th>
                <th className="px-6 py-3.5 font-medium">Account Status</th>
                <th className="px-6 py-3.5 font-medium">KYC Status</th>
                <th className="px-6 py-3.5 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--border)] bg-white">
              {loading && users.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-xs text-[var(--text-muted)]">
                    Loading users from database...
                  </td>
                </tr>
              ) : filtered.length === 0 ? (
                <tr>
                  <td colSpan={6} className="px-6 py-12 text-center text-xs text-[var(--text-muted)]">
                    No users found matching query.
                  </td>
                </tr>
              ) : (
                filtered.map((u) => (
                  <tr key={u.id} className="hover:bg-amber-50/30 transition-colors">
                    <td className="px-6 py-4">
                      <div className="font-semibold text-[var(--text-primary)]">{u.name}</div>
                      <div className="text-xs text-[var(--text-muted)] font-mono">{u.id}</div>
                    </td>
                    <td className="px-6 py-4 text-[var(--text-secondary)] font-mono">{u.phone}</td>
                    <td className="px-6 py-4">
                      <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${
                        u.role === 'DRIVER' ? 'bg-purple-50 text-purple-700 border-purple-200' : u.role === 'ADMIN' ? 'bg-amber-50 text-amber-700 border-amber-200' : 'bg-blue-50 text-blue-700 border-blue-200'
                      }`}>
                        {u.role}
                      </span>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${
                        u.status === 'ACTIVE' ? 'bg-emerald-50 text-emerald-700 border-emerald-200' : 'bg-red-50 text-red-700 border-red-200'
                      }`}>
                        {u.status}
                      </span>
                    </td>
                    <td className="px-6 py-4 font-mono text-xs text-[var(--text-muted)]">
                      {u.kycStatus || 'N/A'}
                    </td>
                    <td className="px-6 py-4 text-right">
                      <button
                        onClick={() => toggleStatus(u)}
                        disabled={actionLoading === u.id}
                        className={`inline-flex items-center gap-1.5 px-3.5 py-1.5 rounded-lg text-xs font-semibold border transition-all cursor-pointer shadow-sm ${
                          u.status === 'ACTIVE'
                            ? 'border-red-200 text-red-700 bg-red-50 hover:bg-red-100'
                            : 'border-emerald-300 text-emerald-700 bg-emerald-50 hover:bg-emerald-100'
                        }`}
                      >
                        {actionLoading === u.id ? (
                          <RefreshCw size={14} className="animate-spin" />
                        ) : u.status === 'ACTIVE' ? (
                          <UserX size={14} />
                        ) : (
                          <UserCheck size={14} />
                        )}
                        {u.status === 'ACTIVE' ? 'Suspend' : 'Activate Driver / User'}
                      </button>
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}

export default UserManagement;
