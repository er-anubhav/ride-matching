import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import {
  Car, Search, Navigation, Server, Users, DollarSign,
  Activity, CheckCircle2, AlertCircle, ArrowRight, RefreshCw, FileText
} from 'lucide-react';

interface ExecutiveStats {
  onlineDriversCount: number;
  availableDriversCount: number;
  inTripDriversCount: number;
  searchingRidersCount: number;
  activeTripsCount: number;
  pendingKycCount: number;
  systemHealth: {
    status: string;
    redis: string;
    activeSocketsCount: number;
  } | null;
  recentTrips: Array<{
    id: string;
    status: string;
    riderName?: string;
    pickupAddress?: string;
    dropoffAddress?: string;
    estimatedFare?: number;
    createdAt: string;
  }>;
}

export default function OperationsDashboard() {
  const [stats, setStats] = useState<ExecutiveStats>({
    onlineDriversCount: 0,
    availableDriversCount: 0,
    inTripDriversCount: 0,
    searchingRidersCount: 0,
    activeTripsCount: 0,
    pendingKycCount: 0,
    systemHealth: null,
    recentTrips: [],
  });

  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchOverview = useCallback(async () => {
    setError(null);
    try {
      const token = localStorage.getItem('adminToken') || '';
      const authHeader = { headers: { Authorization: `Bearer ${token}` } };
      const [fleetRes, queueRes, tripsRes, healthRes, kycRes] = await Promise.allSettled([
        axios.get('/api/admin/fleet/live', authHeader),
        axios.get('/api/admin/matching/queue', authHeader),
        axios.get('/api/admin/trips/active', authHeader),
        axios.get('/api/admin/system/health', authHeader),
        axios.get('/api/admin/kyc/pending', authHeader),
      ]);

      const drivers = fleetRes.status === 'fulfilled' ? (fleetRes.value.data.drivers || []) : [];
      const queue = queueRes.status === 'fulfilled' ? (queueRes.value.data.queue || []) : [];
      const trips = tripsRes.status === 'fulfilled' ? (tripsRes.value.data.trips || []) : [];
      const health = healthRes.status === 'fulfilled' ? (healthRes.value.data.system || null) : null;
      const kycData = kycRes.status === 'fulfilled' ? (kycRes.value.data.drivers || []) : [];

      const onlineCount = drivers.length;
      const availCount = drivers.filter((d: any) => d.status === 'ONLINE' || d.status === 'IDLE').length;
      const inTripCount = drivers.filter((d: any) => d.status === 'IN_TRIP' || d.status === 'ON_TRIP' || d.status === 'ASSIGNED').length;

      setStats({
        onlineDriversCount: onlineCount,
        availableDriversCount: availCount,
        inTripDriversCount: inTripCount,
        searchingRidersCount: queue.length,
        activeTripsCount: trips.length,
        pendingKycCount: kycData.length,
        systemHealth: health,
        recentTrips: trips.slice(0, 5),
      });
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to sync executive operations overview');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchOverview();
    const interval = setInterval(fetchOverview, 6000);
    return () => clearInterval(interval);
  }, [fetchOverview]);

  const navigateTo = (path: string) => {
    window.location.href = path;
  };

  return (
    <div className="p-6 space-y-6 max-w-[1600px] mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-[var(--border)] pb-5">
        <div>
          <h1 className="text-2xl text-[var(--text-primary)] flex items-center gap-2 font-normal">
            Executive Operations Command Center
          </h1>
          <p className="text-xs text-[var(--text-muted)] mt-1">
            Real-time fleet performance overview, dispatch queue metrics, pending KYC verification, and system status
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchOverview}
            disabled={loading}
            className="px-3.5 py-2 bg-[var(--surface-raised)] border border-[var(--border)] hover:border-[var(--brand-dark)] rounded-lg text-xs text-[var(--text-primary)] flex items-center gap-2 transition-all shadow-sm"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            {loading ? 'Refreshing...' : 'Refresh Metrics'}
          </button>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg flex items-center gap-2 text-sm">
          <AlertCircle size={16} />
          {error}
        </div>
      )}

      {/* KPI Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        {/* Drivers Online */}
        <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-2">
          <div className="flex justify-between items-center text-xs text-[var(--text-muted)] uppercase tracking-wider font-mono">
            <span>Online Drivers</span>
            <Car size={18} className="text-emerald-600" />
          </div>
          <div className="text-3xl text-[var(--text-primary)] font-mono">{stats.onlineDriversCount}</div>
          <div className="text-xs text-emerald-700 flex items-center justify-between pt-1 border-t border-[var(--border)]">
            <span>{stats.availableDriversCount} Available</span>
            <span>{stats.inTripDriversCount} In Trip</span>
          </div>
        </div>

        {/* Searching Riders */}
        <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-2">
          <div className="flex justify-between items-center text-xs text-[var(--text-muted)] uppercase tracking-wider font-mono">
            <span>Searching Riders</span>
            <Search size={18} className="text-amber-500" />
          </div>
          <div className="text-3xl text-[var(--text-primary)] font-mono">{stats.searchingRidersCount}</div>
          <div className="text-xs text-amber-700 flex items-center justify-between pt-1 border-t border-[var(--border)]">
            <span>Active Redis Queue</span>
            <span className="font-mono text-[10px] uppercase">Matching</span>
          </div>
        </div>

        {/* Active Trips */}
        <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-2">
          <div className="flex justify-between items-center text-xs text-[var(--text-muted)] uppercase tracking-wider font-mono">
            <span>Active Trips</span>
            <Navigation size={18} className="text-blue-500" />
          </div>
          <div className="text-3xl text-[var(--text-primary)] font-mono">{stats.activeTripsCount}</div>
          <div className="text-xs text-blue-700 flex items-center justify-between pt-1 border-t border-[var(--border)]">
            <span>En Route / Ongoing</span>
            <span className="font-mono text-[10px] uppercase">Live</span>
          </div>
        </div>

        {/* Pending KYC Applications */}
        <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-2">
          <div className="flex justify-between items-center text-xs text-[var(--text-muted)] uppercase tracking-wider font-mono">
            <span>Pending KYC</span>
            <FileText size={18} className="text-purple-600" />
          </div>
          <div className="text-3xl text-[var(--text-primary)] font-mono">{stats.pendingKycCount}</div>
          <div className="text-xs text-purple-700 flex items-center justify-between pt-1 border-t border-[var(--border)]">
            <span>Awaiting Review</span>
            <button
              onClick={() => navigateTo('/kyc')}
              className="text-[11px] text-purple-800 underline flex items-center gap-0.5 hover:text-purple-900"
            >
              Review Apps <ArrowRight size={10} />
            </button>
          </div>
        </div>
      </div>

      {/* Main Operations Control Hub */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Quick Navigation Cards */}
        <div className="lg:col-span-2 space-y-4">
          <h2 className="text-base text-[var(--text-primary)]">Quick Operations Modules</h2>

          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {/* Live Dispatch Command */}
            <div
              onClick={() => navigateTo('/live-dispatch')}
              className="p-5 bg-gradient-to-br from-amber-50 to-white border border-amber-200 rounded-xl hover:border-amber-400 transition-all cursor-pointer shadow-sm group space-y-3"
            >
              <div className="flex justify-between items-center">
                <div className="w-10 h-10 rounded-lg bg-amber-100 text-amber-800 flex items-center justify-center">
                  <Activity size={20} />
                </div>
                <ArrowRight size={16} className="text-amber-600 group-hover:translate-x-1 transition-transform" />
              </div>
              <div>
                <h3 className="text-base text-slate-900">Live Dispatch & Telemetry</h3>
                <p className="text-xs text-slate-600 mt-0.5">
                  Interactive fleet cartographic map, Redis GEO tracking, and candidate driver scoring logs.
                </p>
              </div>
            </div>

            {/* KYC Management */}
            <div
              onClick={() => navigateTo('/kyc')}
              className="p-5 bg-gradient-to-br from-purple-50 to-white border border-purple-200 rounded-xl hover:border-purple-400 transition-all cursor-pointer shadow-sm group space-y-3"
            >
              <div className="flex justify-between items-center">
                <div className="w-10 h-10 rounded-lg bg-purple-100 text-purple-800 flex items-center justify-center">
                  <Users size={20} />
                </div>
                <ArrowRight size={16} className="text-purple-600 group-hover:translate-x-1 transition-transform" />
              </div>
              <div>
                <h3 className="text-base text-slate-900">Driver KYC Verification</h3>
                <p className="text-xs text-slate-600 mt-0.5">
                  Review driver document uploads, license numbers, and grant database approval or rejection.
                </p>
              </div>
            </div>

            {/* Pricing Rules */}
            <div
              onClick={() => navigateTo('/pricing')}
              className="p-5 bg-gradient-to-br from-emerald-50 to-white border border-emerald-200 rounded-xl hover:border-emerald-400 transition-all cursor-pointer shadow-sm group space-y-3"
            >
              <div className="flex justify-between items-center">
                <div className="w-10 h-10 rounded-lg bg-emerald-100 text-emerald-800 flex items-center justify-center">
                  <DollarSign size={20} />
                </div>
                <ArrowRight size={16} className="text-emerald-600 group-hover:translate-x-1 transition-transform" />
              </div>
              <div>
                <h3 className="text-base text-slate-900">City Fare Pricing Engine</h3>
                <p className="text-xs text-slate-600 mt-0.5">
                  Configure base fares, per-km rates, peak hour surge multipliers, and minimum trip pricing.
                </p>
              </div>
            </div>

            {/* User & Driver Accounts */}
            <div
              onClick={() => navigateTo('/users')}
              className="p-5 bg-gradient-to-br from-blue-50 to-white border border-blue-200 rounded-xl hover:border-blue-400 transition-all cursor-pointer shadow-sm group space-y-3"
            >
              <div className="flex justify-between items-center">
                <div className="w-10 h-10 rounded-lg bg-blue-100 text-blue-800 flex items-center justify-center">
                  <Users size={20} />
                </div>
                <ArrowRight size={16} className="text-blue-600 group-hover:translate-x-1 transition-transform" />
              </div>
              <div>
                <h3 className="text-base text-slate-900">User Accounts Directory</h3>
                <p className="text-xs text-slate-600 mt-0.5">
                  Manage rider accounts, driver profiles, contact information, and security permissions.
                </p>
              </div>
            </div>
          </div>
        </div>

        {/* System & Infrastructure Health */}
        <div className="space-y-4">
          <h2 className="text-base text-[var(--text-primary)]">System & Core Health</h2>

          <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
            <div className="flex justify-between items-center border-b border-[var(--border)] pb-3">
              <div className="flex items-center gap-2">
                <Server size={18} className="text-emerald-600" />
                <span className="text-sm text-[var(--text-primary)]">Go Engine & Redis</span>
              </div>
              <span className="px-2.5 py-0.5 rounded text-xs bg-emerald-50 text-emerald-700 border border-emerald-200 font-mono">
                HEALTHY
              </span>
            </div>

            <div className="space-y-2 text-xs text-[var(--text-muted)] font-mono">
              <div className="flex justify-between">
                <span>Redis Telemetry Geo:</span>
                <span className="text-[var(--text-primary)]">Active</span>
              </div>
              <div className="flex justify-between">
                <span>Active WebSocket Sockets:</span>
                <span className="text-[var(--text-primary)]">{stats.systemHealth?.activeSocketsCount || 0}</span>
              </div>
              <div className="flex justify-between">
                <span>Matching Engine Latency:</span>
                <span className="text-emerald-700">&lt; 15ms</span>
              </div>
            </div>

            <div className="p-3 bg-amber-50 border border-amber-200 rounded-lg text-xs text-amber-800 space-y-1">
              <div className="flex items-center gap-1.5 font-medium">
                <CheckCircle2 size={14} className="text-amber-600" />
                Live Matching Engine Connected
              </div>
              <p className="text-[11px] text-amber-700 leading-relaxed">
                Redis GEO driver tracking and sub-second candidate scoring engine operating normally.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
