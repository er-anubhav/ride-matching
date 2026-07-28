import React, { useState, useEffect, useCallback, useMemo } from 'react';
import axios from 'axios';
import {
  Car, Bike, MapPin, RefreshCw, Clock, AlertCircle, CheckCircle2,
  XCircle, Radio, Zap, Search, Cpu, Database, Star, Info
} from 'lucide-react';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Fix Leaflet tile loading issue and auto-center map on user's actual location
function MapResizer({ center }: { center?: [number, number] }) {
  const map = useMap();
  useEffect(() => {
    const timer = setTimeout(() => {
      map.invalidateSize();
      if (center && center[0] !== 0 && center[1] !== 0) {
        map.setView(center, 13);
      }
    }, 200);
    return () => clearTimeout(timer);
  }, [map, center]);
  return null;
}

interface FleetDriver {
  driverId: string;
  name: string;
  phone: string;
  vehicleNumber: string;
  vehicleName: string;
  vehicleType: string;
  lat: number;
  lng: number;
  heading: number;
  status: string;
  rating: number;
  acceptanceRate: number;
  cancellationRate: number;
  lastSeen: number;
  hasActiveSocket: boolean;
}

interface ActiveTrip {
  id: string;
  status: string;
  vehicleType: string;
  riderId: string;
  riderName: string;
  riderPhone: string;
  driverId?: string | null;
  driverName?: string | null;
  driverPhone?: string | null;
  pickupLat: number;
  pickupLng: number;
  pickupAddress: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffAddress: string;
  estimatedFare: number;
  riderOtp: string;
  createdAt: string;
  startedAt?: string | null;
}

interface Candidate {
  driverId: string;
  name: string;
  vehicleNumber: string;
  vehicleType: string;
  status: string;
  rating: number;
  distance: number;
  score: number | null;
  eta: number;
  isSelected: boolean;
  exclusionReason: string | null;
}

interface QueueItem {
  tripId: string;
  riderId: string;
  riderName: string;
  riderPhone: string;
  vehicleType: string;
  pickupAddress: string;
  dropoffAddress: string;
  pickupLat: number;
  pickupLng: number;
  estimatedFare: number;
  createdAt: string;
  candidatesCount: number;
  topMatchedDriver: any;
  allCandidates: Candidate[];
}

interface TimelineStep {
  step: string;
  timestamp: string;
  detail: string;
  status: string;
}

interface SystemHealth {
  redis: string;
  database: string;
  goMatchingEngine: string;
  activeSocketsCount: number;
  activeRiderSubscriptionsCount: number;
  serverUptime: number;
  nodeVersion: string;
}

export function LiveTripMonitor() {
  const [activeTab, setActiveTab] = useState<'map' | 'drivers' | 'queue' | 'timeline' | 'system'>('map');
  const [drivers, setDrivers] = useState<FleetDriver[]>([]);
  const [activeTrips, setActiveTrips] = useState<ActiveTrip[]>([]);
  const [matchingQueue, setMatchingQueue] = useState<QueueItem[]>([]);
  const [systemHealth, setSystemHealth] = useState<SystemHealth | null>(null);
  
  const [selectedDriver, setSelectedDriver] = useState<FleetDriver | null>(null);
  const [selectedTrip, setSelectedTrip] = useState<QueueItem | ActiveTrip | null>(null);
  const [timeline, setTimeline] = useState<TimelineStep[]>([]);
  
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);
  const [filterVehicle, setFilterVehicle] = useState<string>('all');
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [driverSearchQuery, setDriverSearchQuery] = useState<string>('');

  const fetchData = useCallback(async () => {
    setError(null);
    try {
      const token = localStorage.getItem('adminToken') || '';
      const authHeader = { headers: { Authorization: `Bearer ${token}` } };
      const [fleetRes, tripsRes, queueRes, healthRes] = await Promise.allSettled([
        axios.get('/api/admin/fleet/live', authHeader),
        axios.get('/api/admin/trips/active', authHeader),
        axios.get('/api/admin/matching/queue', authHeader),
        axios.get('/api/admin/system/health', authHeader),
      ]);

      if (fleetRes.status === 'fulfilled') setDrivers(fleetRes.value.data.drivers || []);
      if (tripsRes.status === 'fulfilled') setActiveTrips(tripsRes.value.data.trips || []);
      if (queueRes.status === 'fulfilled') setMatchingQueue(queueRes.value.data.queue || []);
      if (healthRes.status === 'fulfilled') setSystemHealth(healthRes.value.data.system || null);

    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to sync live operations data');
    } finally {
      setLoading(false);
    }
  }, []);

  const fetchTimeline = async (tripId: string) => {
    try {
      const token = localStorage.getItem('adminToken') || '';
      const authHeader = { headers: { Authorization: `Bearer ${token}` } };
      const res = await axios.get(`/api/admin/trips/${tripId}/timeline`, authHeader);
      setTimeline(res.data.timeline || []);
    } catch (_) {}
  };

  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 5000);
    return () => clearInterval(interval);
  }, [fetchData]);

  // Create custom Leaflet icons for driver markers
  const createDriverIcon = (color: string, vType: string) => {
    const emoji = (vType === 'cab' || vType === 'sedan' || vType === 'hatchback') ? '🚗' : (vType === 'bike' || vType === 'motorcycle' || vType === 'scooter') ? '🏍' : '⚡';
    return L.divIcon({
      className: '',
      html: `<div style="background:${color};width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;color:white;font-size:16px;border:2px solid white;box-shadow:0 2px 8px rgba(0,0,0,0.3);">${emoji}</div>`,
      iconSize: [32, 32],
      iconAnchor: [16, 16],
      popupAnchor: [0, -20],
    });
  };

  const pickupIcon = useMemo(() => L.divIcon({
    className: '',
    html: '<div style="background:#10B981;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 0 6px rgba(16,185,129,0.6);"></div>',
    iconSize: [12, 12],
    iconAnchor: [6, 6],
  }), []);

  const dropoffIcon = useMemo(() => L.divIcon({
    className: '',
    html: '<div style="background:#EF4444;width:12px;height:12px;border-radius:50%;border:2px solid white;box-shadow:0 0 6px rgba(239,68,68,0.6);"></div>',
    iconSize: [12, 12],
    iconAnchor: [6, 6],
  }), []);

  // User location detection for map centering
  const [userLocation, setUserLocation] = useState<[number, number] | null>(null);

  useEffect(() => {
    if (typeof window !== 'undefined' && 'geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          if (pos.coords.latitude && pos.coords.longitude) {
            setUserLocation([pos.coords.latitude, pos.coords.longitude]);
          }
        },
        (err) => {
          console.log('Browser geolocation notice:', err.message);
        },
        { enableHighAccuracy: true, timeout: 5000 }
      );
    }
  }, []);

  const activeMapCenter = useMemo((): [number, number] => {
    if (userLocation) return userLocation;
    if (drivers.length > 0 && drivers[0].lat && drivers[0].lng && !isNaN(drivers[0].lat)) {
      return [drivers[0].lat, drivers[0].lng];
    }
    return [28.6139, 77.2090]; // Delhi NCR default
  }, [userLocation, drivers]);

  const MAP_ZOOM = 13;

  // Color helper for driver status pins
  const getDriverStatusColor = (status: string) => {
    switch (status?.toUpperCase()) {
      case 'ONLINE':
      case 'IDLE':
        return { bg: 'bg-emerald-500', hex: '#10B981', text: 'text-emerald-700', border: 'border-emerald-300', badge: 'bg-emerald-50 text-emerald-700 border-emerald-200' };
      case 'NOTIFIED':
        return { bg: 'bg-amber-500', hex: '#F59E0B', text: 'text-amber-700', border: 'border-amber-300', badge: 'bg-amber-50 text-amber-700 border-amber-200' };
      case 'ASSIGNED':
      case 'ON_TRIP':
        return { bg: 'bg-blue-500', hex: '#3B82F6', text: 'text-blue-700', border: 'border-blue-300', badge: 'bg-blue-50 text-blue-700 border-blue-200' };
      case 'ARRIVED':
        return { bg: 'bg-orange-500', hex: '#F97316', text: 'text-orange-700', border: 'border-orange-300', badge: 'bg-orange-50 text-orange-700 border-orange-200' };
      case 'IN_TRIP':
        return { bg: 'bg-rose-500', hex: '#F43F5E', text: 'text-rose-700', border: 'border-rose-300', badge: 'bg-rose-50 text-rose-700 border-rose-200' };
      default:
        return { bg: 'bg-gray-400', hex: '#9CA3AF', text: 'text-gray-600', border: 'border-gray-300', badge: 'bg-gray-50 text-gray-600 border-gray-200' };
    }
  };

  const filteredDrivers = drivers.filter(d => {
    if (filterVehicle !== 'all' && d.vehicleType.toLowerCase() !== filterVehicle.toLowerCase()) return false;
    if (filterStatus !== 'all' && d.status.toLowerCase() !== filterStatus.toLowerCase()) return false;
    if (driverSearchQuery) {
      const q = driverSearchQuery.toLowerCase();
      const matchName = d.name?.toLowerCase().includes(q);
      const matchPlate = d.vehicleNumber?.toLowerCase().includes(q);
      const matchPhone = d.phone?.toLowerCase().includes(q);
      if (!matchName && !matchPlate && !matchPhone) return false;
    }
    return true;
  });

  return (
    <div className="p-6 space-y-6 max-w-[1600px] mx-auto">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-[var(--text-primary)] flex items-center gap-2">
            Operations Command & Live Matching Monitor
          </h1>
          <p className="text-sm text-[var(--text-muted)]">
            Real-time fleet telemetry, Redis GEO driver tracking, and Go matching algorithm scoring engine
          </p>
        </div>

        <div className="flex items-center gap-3">
          <button
            onClick={fetchData}
            disabled={loading}
            className="px-3.5 py-2 bg-[var(--surface-raised)] border border-[var(--border)] hover:border-[var(--brand-dark)] rounded-lg text-xs font-semibold text-[var(--text-primary)] flex items-center gap-2 transition-all shadow-sm"
          >
            <RefreshCw size={14} className={loading ? 'animate-spin' : ''} />
            {loading ? 'Syncing...' : 'Sync Telemetry'}
          </button>
        </div>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg flex items-center gap-2 text-sm">
          <AlertCircle size={16} />
          {error}
        </div>
      )}

      {/* Main Tabs Navigation */}
      <div className="border-b border-[var(--border)] flex flex-wrap gap-6">
        <button
          onClick={() => setActiveTab('map')}
          className={`pb-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-colors ${
            activeTab === 'map' ? 'border-[var(--brand-dark)] text-[var(--brand-dark)]' : 'border-transparent text-[var(--text-muted)] hover:text-[var(--text-primary)]'
          }`}
        >
          <MapPin size={18} />
          Fleet & Live Map ({drivers.length})
        </button>

        <button
          onClick={() => setActiveTab('drivers')}
          className={`pb-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-colors ${
            activeTab === 'drivers' ? 'border-[var(--brand-dark)] text-[var(--brand-dark)]' : 'border-transparent text-[var(--text-muted)] hover:text-[var(--text-primary)]'
          }`}
        >
          <Car size={18} />
          Online Drivers Table ({drivers.length})
        </button>

        <button
          onClick={() => setActiveTab('queue')}
          className={`pb-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-colors ${
            activeTab === 'queue' ? 'border-[var(--brand-dark)] text-[var(--brand-dark)]' : 'border-transparent text-[var(--text-muted)] hover:text-[var(--text-primary)]'
          }`}
        >
          <Cpu size={18} />
          Matching Queue & Candidates ({matchingQueue.length})
        </button>

        <button
          onClick={() => setActiveTab('timeline')}
          className={`pb-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-colors ${
            activeTab === 'timeline' ? 'border-[var(--brand-dark)] text-[var(--brand-dark)]' : 'border-transparent text-[var(--text-muted)] hover:text-[var(--text-primary)]'
          }`}
        >
          <Clock size={18} />
          Dispatch Audit Timeline
        </button>

        <button
          onClick={() => setActiveTab('system')}
          className={`pb-3 text-sm font-semibold flex items-center gap-2 border-b-2 transition-colors ${
            activeTab === 'system' ? 'border-[var(--brand-dark)] text-[var(--brand-dark)]' : 'border-transparent text-[var(--text-muted)] hover:text-[var(--text-primary)]'
          }`}
        >
          <Database size={18} />
          Infrastructure Health
        </button>
      </div>

      {/* TAB 1: FLEET MAP */}
      {activeTab === 'map' && (
        <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
            {/* Status Color Legend */}
            <div className="flex flex-wrap items-center gap-3 text-xs px-3 py-1.5 rounded-lg border bg-white border-[var(--border)] text-[var(--text-primary)] shadow-sm">
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-emerald-500 shadow-[0_0_6px_rgba(16,185,129,0.6)]"></span> Available (Online)</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-amber-500 shadow-[0_0_6px_rgba(245,158,11,0.6)]"></span> Dispatching (Matching)</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-blue-500 shadow-[0_0_6px_rgba(59,130,246,0.6)]"></span> En Route to Pickup</span>
              <span className="flex items-center gap-1.5"><span className="w-2.5 h-2.5 rounded-full bg-rose-500 shadow-[0_0_6px_rgba(244,63,94,0.6)]"></span> In Trip (Rider Onboard)</span>
            </div>
          </div>

          {/* Real Leaflet Map - Delhi NCR */}
          <div className="w-full h-[580px] rounded-xl overflow-hidden border border-[var(--border)] shadow-lg">
            <MapContainer
              center={activeMapCenter}
              zoom={MAP_ZOOM}
              style={{ height: '100%', width: '100%' }}
              zoomControl={true}
              scrollWheelZoom={true}
            >
              <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              />
              <MapResizer center={activeMapCenter} />

              {/* Driver Markers */}
              {drivers.map((d) => {
                const lat = Number(d.lat);
                const lng = Number(d.lng);
                if (isNaN(lat) || isNaN(lng) || lat === 0 || lng === 0) return null;

                const colors = getDriverStatusColor(d.status);
                const vType = (d.vehicleType || 'bike').toLowerCase();
                const icon = createDriverIcon(colors.hex, vType);

                return (
                  <Marker
                    key={d.driverId}
                    position={[lat, lng]}
                    icon={icon}
                    eventHandlers={{ click: () => setSelectedDriver(d) }}
                  >
                    <Popup>
                      <div style={{ minWidth: 180, fontFamily: 'system-ui' }}>
                        <div style={{ fontWeight: 600, fontSize: 14, marginBottom: 4 }}>{d.name}</div>
                        <div style={{ fontSize: 12, color: '#64748b', marginBottom: 4 }}>{d.phone}</div>
                        <div style={{ fontSize: 12, marginBottom: 6 }}>
                          {d.vehicleName || d.vehicleType} &middot; {d.vehicleNumber || 'N/A'}
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 4, fontSize: 11, borderTop: '1px solid #e2e8f0', paddingTop: 6 }}>
                          <div>Status: <strong>{d.status}</strong></div>
                          <div>Rating: <strong>{d.rating?.toFixed(1) || '4.8'}</strong></div>
                          <div>Accept: <strong>{Math.round((d.acceptanceRate || 0.95) * 100)}%</strong></div>
                          <div>Socket: <strong>{d.hasActiveSocket ? 'ACTIVE' : 'OFF'}</strong></div>
                        </div>
                      </div>
                    </Popup>
                  </Marker>
                );
              })}

              {/* Active Trip Pickup & Dropoff Markers */}
              {activeTrips.map((t) => {
                const pLat = Number(t.pickupLat);
                const pLng = Number(t.pickupLng);
                const dLat = Number(t.dropoffLat);
                const dLng = Number(t.dropoffLng);
                return (
                  <React.Fragment key={t.id}>
                    {!isNaN(pLat) && !isNaN(pLng) && pLat !== 0 && (
                      <Marker position={[pLat, pLng]} icon={pickupIcon}>
                        <Popup>Pickup: Trip {t.id.slice(0, 8)}</Popup>
                      </Marker>
                    )}
                    {!isNaN(dLat) && !isNaN(dLng) && dLat !== 0 && (
                      <Marker position={[dLat, dLng]} icon={dropoffIcon}>
                        <Popup>Dropoff: Trip {t.id.slice(0, 8)}</Popup>
                      </Marker>
                    )}
                  </React.Fragment>
                );
              })}
            </MapContainer>
          </div>

          <div className="text-xs text-[var(--text-muted)] flex flex-wrap justify-between items-center gap-2 pt-1">
            <span className="font-mono text-slate-600">
              Displaying <strong className="text-[var(--text-primary)]">{filteredDrivers.length}</strong> of <strong className="text-[var(--text-primary)]">{drivers.length}</strong> drivers online
            </span>
            <span className="text-[11px] text-[var(--brand-dark)] font-medium flex items-center gap-1">
              <Info size={12} /> Click driver pin to view details
            </span>
          </div>
        </div>
      )}

      {/* TAB 2: ONLINE DRIVERS TABLE */}
      {activeTab === 'drivers' && (
        <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
          <div className="flex flex-col sm:flex-row justify-between sm:items-center gap-3">
            <div>
              <h3 className="text-lg text-[var(--text-primary)] font-semibold">Online Drivers Directory</h3>
              <p className="text-xs text-[var(--text-muted)]">Live connected fleet telemetry & duty status ({filteredDrivers.length} active)</p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
              <input
                type="text"
                placeholder="Search driver name, plate, phone..."
                value={driverSearchQuery}
                onChange={(e) => setDriverSearchQuery(e.target.value)}
                className="px-3 py-1.5 bg-[var(--bg)] border border-[var(--border)] rounded-lg text-xs text-[var(--text-primary)] w-64 focus:outline-none focus:border-[var(--brand-dark)] shadow-sm"
              />

              <select
                value={filterVehicle}
                onChange={(e) => setFilterVehicle(e.target.value)}
                className="px-3 py-1.5 bg-[var(--bg)] border border-[var(--border)] rounded-lg text-xs text-[var(--text-primary)] shadow-sm"
              >
                <option value="all">All Vehicle Types</option>
                <option value="bike">Bike</option>
                <option value="auto">Auto</option>
                <option value="cab">Cab</option>
              </select>

              <select
                value={filterStatus}
                onChange={(e) => setFilterStatus(e.target.value)}
                className="px-3 py-1.5 bg-[var(--bg)] border border-[var(--border)] rounded-lg text-xs text-[var(--text-primary)] shadow-sm"
              >
                <option value="all">All Duty Statuses</option>
                <option value="online">Online / Idle</option>
                <option value="in_trip">In Trip</option>
                <option value="offline">Offline</option>
              </select>
            </div>
          </div>

          <div className="overflow-x-auto border border-[var(--border)] rounded-xl">
            <table className="w-full text-xs text-left border-collapse">
              <thead>
                <tr className="bg-[var(--bg)] border-b border-[var(--border)] text-[var(--text-muted)] font-mono">
                  <th className="p-3">Driver Name & Phone</th>
                  <th className="p-3">Vehicle Details</th>
                  <th className="p-3">Current Location</th>
                  <th className="p-3">Rating</th>
                  <th className="p-3">Acceptance</th>
                  <th className="p-3">WebSocket</th>
                  <th className="p-3">Duty Status</th>
                  <th className="p-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--border)] bg-white">
                {filteredDrivers.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="p-8 text-center text-xs text-[var(--text-muted)]">
                      No drivers matching current search or filter options.
                    </td>
                  </tr>
                ) : (
                  filteredDrivers.map((d) => {
                    const colors = getDriverStatusColor(d.status);
                    const isSelected = selectedDriver?.driverId === d.driverId;

                    return (
                      <tr
                        key={d.driverId}
                        onClick={() => setSelectedDriver(d)}
                        className={`hover:bg-amber-50/50 cursor-pointer transition-colors ${
                          isSelected ? 'bg-amber-50' : ''
                        }`}
                      >
                        <td className="p-3">
                          <div className="text-[var(--text-primary)] font-medium text-sm">{d.name}</div>
                          <div className="text-[11px] font-mono text-[var(--text-muted)]">{d.phone || 'No phone'}</div>
                        </td>
                        <td className="p-3">
                          <div className="uppercase font-mono text-xs text-[var(--brand-dark)] font-semibold">{d.vehicleType}</div>
                          <div className="text-[11px] text-[var(--text-muted)]">{d.vehicleName} ({d.vehicleNumber})</div>
                        </td>
                        <td className="p-3 font-mono text-[11px] text-slate-600">
                          {Number(d.lat).toFixed(4)}°, {Number(d.lng).toFixed(4)}°
                        </td>
                        <td className="p-3">
                          <span className="flex items-center gap-1 font-medium">
                            <Star size={12} className="text-amber-500 fill-amber-500" />
                            {d.rating ? d.rating.toFixed(1) : '4.8'}
                          </span>
                        </td>
                        <td className="p-3 font-mono text-emerald-700 font-semibold">
                          {Math.round((d.acceptanceRate || 0.95) * 100)}%
                        </td>
                        <td className="p-3 font-mono">
                          {d.hasActiveSocket ? (
                            <span className="px-2 py-0.5 text-[10px] rounded bg-emerald-100 text-emerald-800 font-semibold">ACTIVE</span>
                          ) : (
                            <span className="px-2 py-0.5 text-[10px] rounded bg-gray-100 text-gray-600">OFFLINE</span>
                          )}
                        </td>
                        <td className="p-3">
                          <span className={`px-2.5 py-1 text-[10px] font-semibold uppercase rounded-full border ${colors.badge}`}>
                            {d.status}
                          </span>
                        </td>
                        <td className="p-3 text-right">
                          <button
                            onClick={async (e) => {
                              e.stopPropagation();
                              try {
                                const token = localStorage.getItem('adminToken') || '';
                                await axios.post(`/api/admin/users/${d.driverId}/activate`, {}, { headers: { Authorization: `Bearer ${token}` } });
                                fetchData();
                              } catch (err: any) {
                                alert('Failed to activate driver');
                              }
                            }}
                            className="px-2.5 py-1 text-[11px] font-semibold text-emerald-700 bg-emerald-50 border border-emerald-300 rounded hover:bg-emerald-100 transition-colors cursor-pointer shadow-sm"
                          >
                            Activate
                          </button>
                        </td>
                      </tr>
                    );
                  })
                )}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {/* TAB 2: MATCHING QUEUE & CANDIDATE SCORING DEBUGGER */}
      {activeTab === 'queue' && (
        <div className="space-y-6">
          <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
            <div className="flex justify-between items-center">
              <div>
                <h3 className="font-semibold text-[var(--text-primary)]">Active Ride Requests & Scoring Queue</h3>
                <p className="text-xs text-[var(--text-muted)]">Live candidate driver scores calculated by Go Matching Engine PRD algorithm</p>
              </div>
              <span className="px-2.5 py-1 text-xs font-mono rounded bg-amber-50 text-amber-700 border border-amber-200">
                {matchingQueue.length} Active Searches
              </span>
            </div>

            {matchingQueue.length === 0 ? (
              <div className="py-12 text-center text-[var(--text-muted)] border border-dashed rounded-xl space-y-2">
                <Search size={32} className="mx-auto text-gray-300" />
                <p className="text-sm font-medium">No active ride requests searching in queue.</p>
                <p className="text-xs">When a rider searches for a ride, candidate scores will populate here in real-time.</p>
              </div>
            ) : (
              <div className="space-y-6">
                {matchingQueue.map((item) => (
                  <div key={item.tripId} className="p-4 bg-[var(--bg)] border border-[var(--border)] rounded-xl space-y-4">
                    {/* Trip Info Header */}
                    <div className="flex flex-wrap justify-between items-center border-b border-[var(--border)] pb-3 gap-2">
                      <div>
                        <div className="flex items-center gap-2">
                          <span className="font-mono text-xs font-bold text-[var(--brand-dark)]">Trip #{item.tripId.slice(-8)}</span>
                          <span className="px-2 py-0.5 rounded text-xs font-semibold bg-amber-100 text-amber-800 uppercase">
                            Searching ({item.vehicleType})
                          </span>
                        </div>
                        <p className="text-xs text-[var(--text-muted)] mt-0.5">
                          Rider: <strong className="text-[var(--text-primary)]">{item.riderName}</strong> ({item.riderPhone}) • ₹{item.estimatedFare}
                        </p>
                      </div>

                      <div className="text-right text-xs">
                        <div className="font-medium text-[var(--text-primary)]">{item.pickupAddress} $\rightarrow$ {item.dropoffAddress}</div>
                        <div className="text-[var(--text-muted)]">{new Date(item.createdAt).toLocaleTimeString()}</div>
                      </div>
                    </div>

                    {/* Candidate Scoring Matrix Table */}
                    <div className="space-y-2">
                      <h4 className="text-xs font-semibold text-[var(--text-muted)] uppercase tracking-wider">
                        Evaluated Candidate Drivers ({item.allCandidates.length} in 5km radius)
                      </h4>

                      <div className="overflow-x-auto">
                        <table className="w-full text-xs text-left border-collapse">
                          <thead>
                            <tr className="bg-[var(--surface-raised)] border-b text-[var(--text-muted)] font-mono">
                              <th className="p-2">Driver Name</th>
                              <th className="p-2">Vehicle</th>
                              <th className="p-2">Distance</th>
                              <th className="p-2">ETA</th>
                              <th className="p-2">Rating</th>
                              <th className="p-2">Final Weighted Score</th>
                              <th className="p-2">Outcome / Diagnostics</th>
                            </tr>
                          </thead>
                          <tbody className="divide-y divide-[var(--border)]">
                            {item.allCandidates.length === 0 ? (
                              <tr>
                                <td colSpan={7} className="p-4 text-center text-gray-400">No candidate drivers found within 5km radius.</td>
                              </tr>
                            ) : (
                              item.allCandidates.map((c) => (
                                <tr key={c.driverId} className={c.isSelected ? 'bg-emerald-50/60 font-medium' : ''}>
                                  <td className="p-2 text-[var(--text-primary)]">
                                    {c.name} <span className="text-[10px] text-gray-400">({c.vehicleNumber})</span>
                                  </td>
                                  <td className="p-2 uppercase font-mono">{c.vehicleType}</td>
                                  <td className="p-2 font-mono">{c.distance} km</td>
                                  <td className="p-2 font-mono">{c.eta} min</td>
                                  <td className="p-2 flex items-center gap-1">
                                    <Star size={12} className="text-amber-500 fill-amber-500" /> {c.rating.toFixed(1)}
                                  </td>
                                  <td className="p-2 font-mono font-bold text-emerald-700">
                                    {c.score !== null ? (c.score * 100).toFixed(1) + '%' : 'N/A'}
                                  </td>
                                  <td className="p-2">
                                    {c.isSelected ? (
                                      <span className="px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-100 text-emerald-800 flex items-center gap-1 w-fit">
                                        <CheckCircle2 size={12} /> Selected Dispatch
                                      </span>
                                    ) : c.exclusionReason ? (
                                      <span className="text-[11px] text-rose-600 font-medium flex items-center gap-1">
                                        <XCircle size={12} /> {c.exclusionReason}
                                      </span>
                                    ) : (
                                      <span className="text-[11px] text-gray-500">Ranked Candidate</span>
                                    )}
                                  </td>
                                </tr>
                              ))
                            )}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 3: DISPATCH TIMELINE INSPECTOR */}
      {activeTab === 'timeline' && (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
            <h3 className="font-semibold text-[var(--text-primary)]">Select Trip for Event Timeline</h3>
            <div className="space-y-2 max-h-[450px] overflow-y-auto pr-1">
              {activeTrips.length === 0 ? (
                <div className="text-center py-8 text-xs text-[var(--text-muted)]">No active trips available.</div>
              ) : (
                activeTrips.map((t) => (
                  <div
                    key={t.id}
                    onClick={() => {
                      setSelectedTrip(t);
                      fetchTimeline(t.id);
                    }}
                    className={`p-3 bg-[var(--bg)] border rounded-lg hover:border-[var(--brand-dark)] transition-all cursor-pointer space-y-1 ${
                      selectedTrip && (('id' in selectedTrip ? selectedTrip.id : selectedTrip.tripId) === t.id) ? 'border-[var(--brand-dark)] ring-1 ring-[var(--brand-dark)]' : 'border-[var(--border)]'
                    }`}
                  >
                    <div className="flex justify-between items-center">
                      <span className="font-mono text-xs font-bold text-[var(--brand-dark)]">#{t.id.slice(-8)}</span>
                      <span className="text-[10px] font-semibold px-2 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-200 uppercase">
                        {t.status}
                      </span>
                    </div>
                    <div className="text-xs text-[var(--text-primary)] font-medium">Rider: {t.riderName}</div>
                    <div className="text-[11px] text-[var(--text-muted)]">{t.pickupAddress} $\rightarrow$ {t.dropoffAddress}</div>
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="lg:col-span-2 p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
            <div>
              <h3 className="font-semibold text-[var(--text-primary)]">Sub-Second Dispatch Event Log</h3>
              <p className="text-xs text-[var(--text-muted)]">Chronological audit trail of matching decisioning and lifecycle events</p>
            </div>

            {timeline.length === 0 ? (
              <div className="py-16 text-center text-[var(--text-muted)] border border-dashed rounded-xl text-xs">
                Select a trip from the left panel to inspect its event timeline.
              </div>
            ) : (
              <div className="relative border-l-2 border-slate-200 ml-4 space-y-6 py-2">
                {timeline.map((event, idx) => (
                  <div key={idx} className="relative pl-6">
                    <div className={`absolute -left-[9px] top-1 w-4 h-4 rounded-full border-2 border-white ${
                      event.status === 'completed' ? 'bg-emerald-500' : event.status === 'in_progress' ? 'bg-amber-500 animate-pulse' : 'bg-rose-500'
                    }`}></div>

                    <div className="p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg space-y-1">
                      <div className="flex justify-between items-center">
                        <span className="font-semibold text-xs text-[var(--text-primary)]">{event.step}</span>
                        <span className="font-mono text-[11px] text-[var(--text-muted)]">{new Date(event.timestamp).toLocaleTimeString()}</span>
                      </div>
                      <p className="text-xs text-[var(--text-muted)]">{event.detail}</p>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>
      )}

      {/* TAB 4: INFRASTRUCTURE & WEBSOCKET HEALTH */}
      {activeTab === 'system' && (
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
            <h3 className="font-semibold text-[var(--text-primary)] flex items-center gap-2">
              <Database className="text-emerald-500" size={18} />
              Service Status Overview
            </h3>

            <div className="space-y-3 text-xs">
              <div className="flex justify-between items-center p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg">
                <span className="font-medium text-[var(--text-primary)]">Redis In-Memory Data Store</span>
                <span className="px-2.5 py-0.5 rounded font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200 uppercase">
                  {systemHealth?.redis || 'healthy'}
                </span>
              </div>

              <div className="flex justify-between items-center p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg">
                <span className="font-medium text-[var(--text-primary)]">PostgreSQL Primary Database</span>
                <span className="px-2.5 py-0.5 rounded font-semibold text-emerald-700 bg-emerald-50 border border-emerald-200 uppercase">
                  {systemHealth?.database || 'healthy'}
                </span>
              </div>

              <div className="flex justify-between items-center p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg">
                <span className="font-medium text-[var(--text-primary)]">Go Matching Engine Binary</span>
                <span className="px-2.5 py-0.5 rounded font-semibold text-purple-700 bg-purple-50 border border-purple-200">
                  {systemHealth?.goMatchingEngine || 'Active'}
                </span>
              </div>
            </div>
          </div>

          <div className="p-5 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl shadow-sm space-y-4">
            <h3 className="font-semibold text-[var(--text-primary)] flex items-center gap-2">
              <Radio className="text-blue-500" size={18} />
              WebSocket Connection Metrics
            </h3>

            <div className="space-y-3 text-xs">
              <div className="flex justify-between items-center p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg">
                <span className="font-medium text-[var(--text-primary)]">Active Socket Connections</span>
                <span className="font-mono font-bold text-sm text-[var(--brand-dark)]">
                  {systemHealth?.activeSocketsCount || 0}
                </span>
              </div>

              <div className="flex justify-between items-center p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg">
                <span className="font-medium text-[var(--text-primary)]">Live Rider Map Subscriptions</span>
                <span className="font-mono font-bold text-sm text-blue-600">
                  {systemHealth?.activeRiderSubscriptionsCount || 0}
                </span>
              </div>

              <div className="flex justify-between items-center p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg">
                <span className="font-medium text-[var(--text-primary)]">Server Process Uptime</span>
                <span className="font-mono font-semibold text-[var(--text-muted)]">
                  {systemHealth?.serverUptime ? `${Math.round(systemHealth.serverUptime / 60)} mins` : 'N/A'}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* DRIVER DETAIL DRAWER MODAL */}
      {selectedDriver && (
        <div className="fixed inset-0 bg-black/40 backdrop-blur-sm flex justify-end z-50">
          <div className="w-full max-w-md bg-[var(--surface-raised)] h-full shadow-2xl p-6 space-y-6 overflow-y-auto border-l border-[var(--border)]">
            <div className="flex justify-between items-center border-b border-[var(--border)] pb-4">
              <div>
                <h3 className="text-lg font-bold text-[var(--text-primary)]">{selectedDriver.name}</h3>
                <p className="text-xs text-[var(--text-muted)] font-mono">ID: {selectedDriver.driverId}</p>
              </div>
              <button
                onClick={() => setSelectedDriver(null)}
                className="p-1 rounded-lg hover:bg-gray-100 text-gray-500 transition-colors"
                title="Close Drawer"
              >
                <XCircle size={18} />
              </button>
            </div>

            <div className="space-y-4 text-xs">
              <div className="p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg space-y-2">
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Duty Status</span>
                  <span className="font-semibold text-emerald-700 uppercase">{selectedDriver.status}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Vehicle Category</span>
                  <span className="font-semibold uppercase">{selectedDriver.vehicleType}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Vehicle License Plate</span>
                  <span className="font-mono font-medium">{selectedDriver.vehicleNumber}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">WebSocket Socket State</span>
                  <span className="font-semibold text-emerald-600">
                    {selectedDriver.hasActiveSocket ? 'CONNECTED' : 'DISCONNECTED'}
                  </span>
                </div>
              </div>

              <div className="p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg space-y-2">
                <h4 className="font-semibold text-[var(--text-primary)]">Performance & Ratings</h4>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Driver Rating</span>
                  <span className="font-medium flex items-center gap-1">
                    <Star size={12} className="text-amber-500 fill-amber-500" />
                    {selectedDriver.rating.toFixed(1)} / 5.0
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Acceptance Rate</span>
                  <span className="font-medium">{Math.round(selectedDriver.acceptanceRate * 100)}%</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-[var(--text-muted)]">Cancellation Rate</span>
                  <span className="font-medium">{Math.round(selectedDriver.cancellationRate * 100)}%</span>
                </div>
              </div>

              <div className="p-3 bg-[var(--bg)] border border-[var(--border)] rounded-lg space-y-1 font-mono text-[11px]">
                <div className="text-[var(--text-muted)] font-sans">Current Coordinates</div>
                <div>Lat: {selectedDriver.lat.toFixed(4)}, Lng: {selectedDriver.lng.toFixed(4)}</div>
                <div className="text-gray-400">Last Seen: {new Date(selectedDriver.lastSeen).toLocaleTimeString()}</div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default LiveTripMonitor;
