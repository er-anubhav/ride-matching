import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import {
  CreditCard, Car, CheckCircle, AlertTriangle,
  RefreshCw, Download
} from 'lucide-react';

import LiveTripMonitor from './LiveTripMonitor';
import PricingConfigurator from './PricingConfigurator';
import UserManagement from './UserManagement';

const API_BASE = '/api/admin';


interface Driver {
  id: string;
  name: string | null;
  phone: string;
  vehicleType: string;
  kycStatus: string;
  createdAt: string;
}

interface KycResponse {
  drivers: Driver[];
  total: number;
  page: number;
  limit: number;
}

interface PaymentRecord {
  id: string;
  tripId: string;
  riderId: string;
  amount: number;
  status: string;
  createdAt: string;
}

interface TripReport {
  id: string;
  status: string;
  riderId: string;
  createdAt: string;
  estimatedFare: number | null;
  finalFare: number | null;
}

/* ---- Helpers ---- */
function StatusBadge({ status }: { status: string }) {
  const s = status?.toLowerCase() || '';
  const colorMap: Record<string, string> = {
    pending: 'bg-[var(--warning-bg)] text-[var(--warning)] border-[rgba(156,106,0,0.2)]',
    approved: 'bg-[var(--success-bg)] text-[var(--success)] border-[rgba(58,125,68,0.2)]',
    completed: 'bg-[var(--success-bg)] text-[var(--success)] border-[rgba(58,125,68,0.2)]',
    success: 'bg-[var(--success-bg)] text-[var(--success)] border-[rgba(58,125,68,0.2)]',
    rejected: 'bg-[var(--danger-bg)] text-[var(--danger)] border-[rgba(192,57,43,0.2)]',
    failed: 'bg-[var(--danger-bg)] text-[var(--danger)] border-[rgba(192,57,43,0.2)]',
    cancelled: 'bg-[var(--danger-bg)] text-[var(--danger)] border-[rgba(192,57,43,0.2)]',
  };
  const badgeStyle = colorMap[s] || 'bg-[var(--info-bg)] text-[var(--info)] border-[rgba(26,110,168,0.2)]';
  return (
    <span className={`inline-flex items-center gap-1 px-2 py-[0.2rem] rounded-[--r-sm] text-[0.7rem]  border ${badgeStyle}`} style={{ boxShadow: '0 1px 2px rgba(0,0,0,0.08) inset' }}>
      <span className="w-[5px] h-[5px] rounded-full bg-current flex-shrink-0" />
      {status}
    </span>
  );
}

function shortId(id: string) {
  return id?.length > 10 ? `\u2026${id.slice(-8)}` : id;
}

/* ---- Rejection Modal ---- */
interface RejectModalProps {
  driverName: string;
  onConfirm: (reason: string) => void;
  onCancel: () => void;
}

function RejectModal({ driverName, onConfirm, onCancel }: RejectModalProps) {
  const [reason, setReason] = useState('');
  return (
    <div
      className="fixed inset-0 bg-[rgba(42,37,32,0.45)] z-[100] flex items-center justify-center p-6 animate-fade-overlay"
      role="dialog"
      aria-modal="true"
      aria-labelledby="modal-title"
      onClick={onCancel}
    >
      <div
        className="bg-[var(--surface-raised)] border border-[var(--border-strong)] rounded-[--r-lg] p-7 w-full max-w-[420px] animate-modal-in"
        style={{
          boxShadow: '0 1px 0 rgba(255,255,255,0.9) inset, 0 8px 32px rgba(0,0,0,0.2), 0 2px 8px rgba(0,0,0,0.12)',
        }}
        onClick={e => e.stopPropagation()}
      >
        <h2 className="text-[1rem]  text-[var(--text-primary)] mb-1.5" id="modal-title">Reject KYC Application</h2>
        <p className="text-[0.8125rem] text-[var(--text-muted)] mb-[1.125rem] leading-6">
          You are about to reject the KYC application for <strong>{driverName || 'this driver'}</strong>. Please provide a reason.
        </p>
        <textarea
          className="w-full px-3.5 py-2.5 bg-[var(--surface-inset)] border border-[var(--border-strong)] rounded-[--r-sm] text-[var(--text-primary)] font-sans text-[0.875rem] resize-y min-h-[90px] outline-none transition-[border-color,box-shadow] duration-[120ms] mb-[1.125rem] focus:border-[var(--brand)]"
          style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.12) inset' }}
          placeholder="Enter rejection reason..."
          value={reason}
          onChange={e => setReason(e.target.value)}
          autoFocus
          aria-label="Rejection reason"
        />
        <div className="flex gap-2.5 justify-end">
          <button
            className="px-4 py-2 bg-gradient-to-b from-white to-[#f0ece4] text-[var(--text-secondary)] border border-[var(--border-strong)] rounded-[--r-sm] font-sans text-[0.8125rem] font-medium cursor-pointer flex items-center gap-1.5 transition-all duration-[120ms] hover:from-white hover:to-[#e8e4dc] hover:text-[var(--text-primary)] active:bg-[var(--surface-inset)]"
            style={{ boxShadow: '0 1px 0 #ffffff inset, 0 -1px 0 rgba(0,0,0,0.06) inset, 0 2px 4px rgba(0,0,0,0.10), 0 1px 2px rgba(0,0,0,0.08)' }}
            onClick={onCancel}
          >
            Cancel
          </button>
          <button
            className={`px-5 py-2.5 bg-gradient-to-b from-[#e86258] to-[var(--danger)] text-white border border-[#9b2d22] rounded-[--r-sm] font-sans text-[0.875rem]  cursor-pointer transition-all duration-[120ms] hover:from-[#ec6e65] hover:to-[#a82f24] active:translate-y-px ${!reason.trim() ? 'opacity-60 cursor-not-allowed' : ''}`}
            style={{ boxShadow: '0 1px 0 rgba(255,255,255,0.22) inset, 0 1px 3px rgba(0,0,0,0.2)' }}
            onClick={() => reason.trim() && onConfirm(reason.trim())}
            disabled={!reason.trim()}
          >
            Confirm Rejection
          </button>
        </div>
      </div>
    </div>
  );
}

/* ---- Derive section from URL ---- */
function getSectionFromPath(): 'kyc' | 'payments' | 'trips' | 'live-dispatch' | 'pricing' | 'users' {
  const path = window.location.pathname.toLowerCase();
  if (path.includes('live-dispatch')) return 'live-dispatch';
  if (path.includes('pricing')) return 'pricing';
  if (path.includes('users')) return 'users';
  if (path.includes('payment')) return 'payments';
  if (path.includes('trip')) return 'trips';
  return 'kyc'; // default
}


/* ---- Main Dashboard ---- */
export default function Dashboard() {
  const [kycData, setKycData] = useState<KycResponse | null>(null);
  const [payments, setPayments] = useState<PaymentRecord[]>([]);
  const [trips, setTrips] = useState<TripReport[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [rejectTarget, setRejectTarget] = useState<Driver | null>(null);

  const section = getSectionFromPath();
  const token = localStorage.getItem('adminToken') || '';
  const authHeader = { headers: { Authorization: `Bearer ${token}` } };

  const fetchKycData = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await axios.get<KycResponse>(`${API_BASE}/kyc/pending`, authHeader);
      setKycData(res.data);
    } catch (err: any) {
      setError(err.response?.data?.message || err.message);
    }
    setLoading(false);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [token]);

  const fetchPayments = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await axios.get<{ payments: PaymentRecord[] }>(`${API_BASE}/payments/search`, authHeader);
      setPayments(res.data.payments);
    } catch (err: any) {
      setError(err.response?.data?.message || err.message);
    }
    setLoading(false);
  };

  const fetchTrips = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await axios.get<{ trips: TripReport[] }>(`${API_BASE}/trips/reports`, authHeader);
      setTrips(res.data.trips);
    } catch (err: any) {
      setError(err.response?.data?.message || err.message);
    }
    setLoading(false);
  };

  const handleApprove = async (driverId: string) => {
    await axios.post(`${API_BASE}/kyc/${driverId}/approve`, {}, authHeader);
    fetchKycData();
  };

  const handleReject = async (driverId: string, reason: string) => {
    await axios.post(`${API_BASE}/kyc/${driverId}/reject`, { reason }, authHeader);
    setRejectTarget(null);
    fetchKycData();
  };

  /* Fetch data for the current section */
  useEffect(() => {
    if (section === 'kyc') fetchKycData();
    else if (section === 'payments') fetchPayments();
    else fetchTrips();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [section, token]);

  /* Also eagerly fetch KYC data in background for stat cards */
  useEffect(() => {
    fetchKycData();
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const handleExportCSV = () => {
    let csvRows: string[] = [];
    if (section === 'payments') {
      csvRows.push('Payment ID,Trip ID,Rider ID,Amount (INR),Status,Created At');
      payments.forEach((p) => {
        csvRows.push(`"${p.id}","${p.tripId}","${p.riderId}","${p.amount}","${p.status}","${p.createdAt}"`);
      });
    } else if (section === 'trips') {
      csvRows.push('Trip ID,Rider ID,Status,Estimated Fare (INR),Final Fare (INR),Created At');
      trips.forEach((t) => {
        csvRows.push(`"${t.id}","${t.riderId}","${t.status}","${t.estimatedFare || 0}","${t.finalFare || 0}","${t.createdAt}"`);
      });
    } else {
      csvRows.push('Driver ID,Driver Name,Phone,Vehicle Type,KYC Status,Created At');
      (kycData?.drivers || []).forEach((d) => {
        csvRows.push(`"${d.id}","${d.name || ''}","${d.phone}","${d.vehicleType}","${d.kycStatus}","${d.createdAt}"`);
      });
    }
    const blob = new Blob([csvRows.join('\n')], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `mr_rideo_${section}_report_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const handleRefresh = () => {
    if (section === 'kyc') fetchKycData();
    else if (section === 'payments') fetchPayments();
    else fetchTrips();
  };

  const completedTrips = trips.filter(t => t.status?.toLowerCase() === 'completed').length;
  const totalRevenue = payments.reduce((sum, p) => sum + (p.amount || 0), 0);

  if (section === 'live-dispatch') return <LiveTripMonitor />;
  if (section === 'pricing') return <PricingConfigurator />;
  if (section === 'users') return <UserManagement />;

  return (
    <>
      {rejectTarget && (
        <RejectModal
          driverName={rejectTarget.name || 'Unknown Driver'}
          onConfirm={reason => handleReject(rejectTarget.id, reason)}
          onCancel={() => setRejectTarget(null)}
        />
      )}

      <div className="p-7 flex-1">

        {/* Header */}
        <div className="mb-7">
          <div className="flex items-start justify-between gap-4 flex-wrap mb-6">
            <div>
              <h1 className="text-[1.375rem]  text-[var(--text-primary)] tracking-[-0.025em]">
                {section === 'kyc' ? 'KYC Management' : section === 'payments' ? 'Payments' : 'Trip Reports'}
              </h1>
              <p className="text-[0.8125rem] text-[var(--text-muted)] mt-0.5">
                {section === 'kyc'
                  ? 'Review and manage driver KYC verification applications'
                  : section === 'payments'
                    ? 'View payment history and transaction records'
                    : 'Browse completed and ongoing trip reports'}
              </p>
            </div>
            <div className="flex gap-3">
              <button
                id="export-csv-btn"
                className="px-4 py-2 bg-emerald-50 text-emerald-700 border border-emerald-300 rounded-[--r-sm] font-sans text-[0.8125rem] font-medium cursor-pointer flex items-center gap-1.5 transition-all duration-[120ms] hover:bg-emerald-100 whitespace-nowrap shadow-sm"
                onClick={handleExportCSV}
                aria-label="Export report to CSV"
              >
                <Download size={16} />
                Export CSV
              </button>
              <button
                id="refresh-btn"
                className="px-4 py-2 bg-gradient-to-b from-white to-[#f0ece4] text-[var(--text-secondary)] border border-[var(--border-strong)] rounded-[--r-sm] font-sans text-[0.8125rem] font-medium cursor-pointer flex items-center gap-1.5 transition-all duration-[120ms] hover:from-white hover:to-[#e8e4dc] hover:text-[var(--text-primary)] active:bg-[var(--surface-inset)] active:translate-y-px whitespace-nowrap"
                style={{ boxShadow: '0 1px 0 #ffffff inset, 0 -1px 0 rgba(0,0,0,0.06) inset, 0 2px 4px rgba(0,0,0,0.10), 0 1px 2px rgba(0,0,0,0.08)' }}
                onClick={handleRefresh}
                disabled={loading}
                aria-label="Refresh current view"
              >
                <RefreshCw size={16} />
                Refresh
              </button>
            </div>
          </div>

          {/* Stats cards */}
          <div className="grid grid-cols-[repeat(auto-fit,minmax(175px,1fr))] gap-4 mb-7">
            {[
              { label: 'Pending KYC', value: kycData?.total ?? '\u2014' },
              { label: 'Total Payments', value: payments.length > 0 ? `\u20B9${totalRevenue.toLocaleString('en-IN')}` : '\u2014' },
              { label: 'Total Trips', value: trips.length > 0 ? trips.length : '\u2014' },
              { label: 'Completed Trips', value: trips.length > 0 ? completedTrips : '\u2014' },
            ].map((stat, i) => (
              <div
                key={i}
                className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-[--r-md] px-5 py-[1.125rem] relative overflow-hidden transition-shadow duration-200 hover:shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_4px_14px_rgba(0,0,0,0.12),0_2px_4px_rgba(0,0,0,0.08)]"
                style={{ boxShadow: '0 1px 0 #ffffff inset, 0 2px 8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.06)' }}
              >
                {/* Bevel highlight */}
                <div className="absolute top-0 left-4 right-4 h-px bg-white/90" />
                <div className="text-[1.625rem]  text-[var(--text-primary)] tracking-[-0.04em] leading-none mb-0.5">{stat.value}</div>
                <div className="text-[0.75rem] text-[var(--text-muted)] font-medium uppercase tracking-[0.05em]">{stat.label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Alerts */}
        {error && (
          <div className="mx-0 mb-4 px-4 py-3 bg-[var(--danger-bg)] border border-[rgba(192,57,43,0.25)] rounded-[--r-sm] text-[var(--danger)] text-[0.8125rem] flex items-center gap-2" style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.14) inset, 0 1px 0 #ffffff' }} role="alert">
            <AlertTriangle size={16} style={{ flexShrink: 0 }} />
            <strong>Error:</strong>&nbsp;{error}
          </div>
        )}

        {/* ---- KYC Section ---- */}
        {section === 'kyc' && (
          <div className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-[--r-md] overflow-hidden animate-tab-in">
            <div className="px-5 py-4 border-b border-[var(--border)] flex items-center justify-between gap-3 flex-wrap" style={{ background: 'linear-gradient(180deg, #fff 0%, #faf7f3 100%)' }}>
              <div>
                <h2 className="text-[0.9375rem]  text-[var(--text-primary)]">Pending KYC Approvals</h2>
                {kycData?.total !== undefined && (
                  <span className="text-[0.8rem] text-[var(--text-muted)]">{kycData.total} application{kycData.total !== 1 ? 's' : ''} awaiting review</span>
                )}
              </div>
            </div>

            {loading ? (
              <div className="flex flex-col items-center justify-center py-12 gap-3.5 text-[var(--text-muted)] text-[0.875rem]" aria-live="polite" aria-busy="true">
                <div className="w-7 h-7 border-[2.5px] border-[var(--border-strong)] border-t-[var(--brand)] rounded-full animate-spin" aria-hidden="true" />
                Loading KYC applications...
              </div>
            ) : kycData?.drivers && kycData.drivers.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-[0.8125rem]" aria-label="KYC applications">
                  <thead style={{ background: 'linear-gradient(180deg, #f5f2ec 0%, #ede9e1 100%)' }}>
                    <tr className="border-b border-[var(--border-strong)]">
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Driver</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Phone</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Vehicle</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Status</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem] text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Applied</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {kycData.drivers.map((driver, idx) => (
                      <tr key={driver.id} className={`border-b border-[var(--border)] last:border-b-0 ${idx % 2 === 1 ? 'bg-[rgba(0,0,0,0.012)]' : ''} hover:bg-[var(--brand-bg)]`}>
                        <td className="px-4 py-3 text-[var(--text-primary)] font-medium">{driver.name || 'Unknown'}</td>
                        <td className="px-4 py-3 text-[var(--text-secondary)]">{driver.phone}</td>
                        <td className="px-4 py-3">
                          <span className="inline-flex items-center px-2 py-[0.175rem] bg-[var(--bg)] border border-[var(--border)] rounded-[--r-sm] text-[0.725rem] font-medium text-[var(--text-secondary)]" style={{ boxShadow: '0 1px 3px rgba(0,0,0,0.14) inset, 0 1px 0 #ffffff' }}>
                            {driver.vehicleType}
                          </span>
                        </td>
                        <td className="px-4 py-3"><StatusBadge status={driver.kycStatus} /></td>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">
                          {new Date(driver.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                        </td>
                        <td className="px-4 py-3">
                          <div className="flex items-center gap-2">
                            <button
                              id={`approve-${driver.id}`}
                              className="px-3 py-[0.3125rem] bg-gradient-to-b from-[#6ec87e] to-[var(--success)] text-white border border-[#2d6b37] rounded-[--r-sm] font-sans text-[0.725rem] er transition-all duration-[120ms] hover:from-[#7dd490] hover:to-[#30703f] active:translate-y-px"
                              style={{ boxShadow: '0 1px 0 rgba(255,255,255,0.25) inset, 0 1px 3px rgba(0,0,0,0.2)' }}
                              onClick={() => handleApprove(driver.id)}
                              aria-label={`Approve KYC for ${driver.name || 'driver'}`}
                            >
                              ✓ Approve
                            </button>
                            <button
                              id={`reject-${driver.id}`}
                              className="px-3 py-[0.3125rem] bg-gradient-to-b from-[#e86258] to-[var(--danger)] text-white border border-[#9b2d22] rounded-[--r-sm] font-sans text-[0.725rem]  cursor-pointer transition-all duration-[120ms] hover:from-[#ec6e65] hover:to-[#a82f24] active:translate-y-px"
                              style={{ boxShadow: '0 1px 0 rgba(255,255,255,0.22) inset, 0 1px 3px rgba(0,0,0,0.2)' }}
                              onClick={() => setRejectTarget(driver)}
                              aria-label={`Reject KYC for ${driver.name || 'driver'}`}
                            >
                              ✕ Reject
                            </button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 gap-2.5 text-[var(--text-muted)] text-center">
                <span className="opacity-45" aria-hidden="true"><CheckCircle size={32} /></span>
                <p className="text-[0.9375rem]  text-[var(--text-secondary)]">All caught up!</p>
                <p className="text-[0.8125rem]">No pending KYC applications at the moment.</p>
              </div>
            )}
          </div>
        )}

        {/* ---- Payments Section ---- */}
        {section === 'payments' && (
          <div className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-[--r-md] overflow-hidden animate-tab-in">
            <div className="px-5 py-4 border-b border-[var(--border)] flex items-center justify-between gap-3 flex-wrap" style={{ background: 'linear-gradient(180deg, #fff 0%, #faf7f3 100%)' }}>
              <div>
                <h2 className="text-[0.9375rem]  text-[var(--text-primary)]">Payment History</h2>
                {payments.length > 0 && (
                  <span className="text-[0.8rem] text-[var(--text-muted)]">{payments.length} transaction{payments.length !== 1 ? 's' : ''}</span>
                )}
              </div>
            </div>

            {loading ? (
              <div className="flex flex-col items-center justify-center py-12 gap-3.5 text-[var(--text-muted)] text-[0.875rem]" aria-live="polite" aria-busy="true">
                <div className="w-7 h-7 border-[2.5px] border-[var(--border-strong)] border-t-[var(--brand)] rounded-full animate-spin" aria-hidden="true" />
                Loading payment records...
              </div>
            ) : payments.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-[0.8125rem]" aria-label="Payment history">
                  <thead style={{ background: 'linear-gradient(180deg, #f5f2ec 0%, #ede9e1 100%)' }}>
                    <tr className="border-b border-[var(--border-strong)]">
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Payment ID</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Trip ID</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Rider</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Amount</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Status</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {payments.map((payment, idx) => (
                      <tr key={payment.id} className={`border-b border-[var(--border)] last:border-b-0 ${idx % 2 === 1 ? 'bg-[rgba(0,0,0,0.012)]' : ''} hover:bg-[var(--brand-bg)]`}>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">{shortId(payment.id)}</td>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">{shortId(payment.tripId)}</td>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">{shortId(payment.riderId)}</td>
                        <td className="px-4 py-3 font-mono  text-[var(--success)]">₹{payment.amount.toLocaleString('en-IN')}</td>
                        <td className="px-4 py-3"><StatusBadge status={payment.status} /></td>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">
                          {new Date(payment.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 gap-2.5 text-[var(--text-muted)] text-center">
                <span className="opacity-45" aria-hidden="true"><CreditCard size={32} /></span>
                <p className="text-[0.9375rem]  text-[var(--text-secondary)]">No payments found</p>
                <p className="text-[0.8125rem]">Payment records will appear here once transactions are made.</p>
              </div>
            )}
          </div>
        )}

        {/* ---- Trips Section ---- */}
        {section === 'trips' && (
          <div className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-[--r-md] overflow-hidden animate-tab-in">
            <div className="px-5 py-4 border-b border-[var(--border)] flex items-center justify-between gap-3 flex-wrap" style={{ background: 'linear-gradient(180deg, #fff 0%, #faf7f3 100%)' }}>
              <div>
                <h2 className="text-[0.9375rem]  text-[var(--text-primary)]">Trip Reports</h2>
                {trips.length > 0 && (
                  <span className="text-[0.8rem] text-[var(--text-muted)]">{trips.length} trip{trips.length !== 1 ? 's' : ''} recorded</span>
                )}
              </div>
            </div>

            {loading ? (
              <div className="flex flex-col items-center justify-center py-12 gap-3.5 text-[var(--text-muted)] text-[0.875rem]" aria-live="polite" aria-busy="true">
                <div className="w-7 h-7 border-[2.5px] border-[var(--border-strong)] border-t-[var(--brand)] rounded-full animate-spin" aria-hidden="true" />
                Loading trip reports...
              </div>
            ) : trips.length > 0 ? (
              <div className="overflow-x-auto">
                <table className="w-full border-collapse text-[0.8125rem]" aria-label="Trip reports">
                  <thead style={{ background: 'linear-gradient(180deg, #f5f2ec 0%, #ede9e1 100%)' }}>
                    <tr className="border-b border-[var(--border-strong)]">
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Trip ID</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Status</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Rider</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Est. Fare</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Final Fare</th>
                      <th className="px-4 py-2.5 text-left text-[0.7rem]  text-[var(--text-muted)] uppercase tracking-[0.07em] whitespace-nowrap">Date</th>
                    </tr>
                  </thead>
                  <tbody>
                    {trips.map((trip, idx) => (
                      <tr key={trip.id} className={`border-b border-[var(--border)] last:border-b-0 ${idx % 2 === 1 ? 'bg-[rgba(0,0,0,0.012)]' : ''} hover:bg-[var(--brand-bg)]`}>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">{shortId(trip.id)}</td>
                        <td className="px-4 py-3"><StatusBadge status={trip.status} /></td>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">{shortId(trip.riderId)}</td>
                        <td className="px-4 py-3">
                          {trip.estimatedFare != null
                            ? <span className="font-mono  text-[var(--success)]">₹{trip.estimatedFare.toLocaleString('en-IN')}</span>
                            : <span style={{ color: 'var(--text-muted)' }}>—</span>}
                        </td>
                        <td className="px-4 py-3">
                          {trip.finalFare != null
                            ? <span className="font-mono  text-[var(--success)]">₹{trip.finalFare.toLocaleString('en-IN')}</span>
                            : <span style={{ color: 'var(--text-muted)' }}>—</span>}
                        </td>
                        <td className="px-4 py-3 font-mono text-[0.75rem] text-[var(--text-muted)]">
                          {new Date(trip.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            ) : (
              <div className="flex flex-col items-center justify-center py-12 gap-2.5 text-[var(--text-muted)] text-center">
                <span className="opacity-45" aria-hidden="true"><Car size={32} /></span>
                <p className="text-[0.9375rem]  text-[var(--text-secondary)]">No trips found</p>
                <p className="text-[0.8125rem]">Trip reports will appear here once rides are completed.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </>
  );
}
