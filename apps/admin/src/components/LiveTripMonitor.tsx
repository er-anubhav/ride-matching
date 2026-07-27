import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Car, MapPin, RefreshCw, Clock, User, AlertCircle } from 'lucide-react';

interface ActiveTrip {
  id: string;
  status: string;
  riderId: string;
  driverId?: string | null;
  pickupLat: number;
  pickupLng: number;
  dropoffLat: number;
  dropoffLng: number;
  estimatedFare: number;
  createdAt: string;
}

export function LiveTripMonitor() {
  const [trips, setTrips] = useState<ActiveTrip[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchActiveTrips = async () => {
    setLoading(true);
    setError(null);
    try {
      const res = await axios.get('/api/admin/trips/reports');
      setTrips(res.data.trips || []);
    } catch (err: any) {
      setError(err.response?.data?.error || 'Failed to fetch active trips');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchActiveTrips();
    const interval = setInterval(fetchActiveTrips, 10000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-semibold text-[var(--text-primary)]">Live Trip Dispatch Monitor</h1>
          <p className="text-sm text-[var(--text-muted)]">Real-time status of active rides across all operational zones.</p>
        </div>
        <button
          onClick={fetchActiveTrips}
          className="flex items-center gap-2 px-3.5 py-2 bg-[var(--surface-raised)] border border-[var(--border-strong)] rounded-lg text-sm font-medium hover:bg-[var(--bg)] transition-colors"
        >
          <RefreshCw size={16} className={loading ? 'animate-spin' : ''} />
          Refresh
        </button>
      </div>

      {error && (
        <div className="p-4 bg-red-50 border border-red-200 text-red-700 rounded-lg flex items-center gap-2 text-sm">
          <AlertCircle size={16} />
          {error}
        </div>
      )}

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {trips.length === 0 && !loading ? (
          <div className="col-span-full py-12 text-center text-[var(--text-muted)] border border-dashed rounded-xl">
            No active trips in progress.
          </div>
        ) : (
          trips.map((trip) => (
            <div key={trip.id} className="p-4 bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl space-y-3 shadow-sm">
              <div className="flex justify-between items-center">
                <span className="text-xs font-mono text-[var(--text-muted)]">#{trip.id.slice(-8)}</span>
                <span className="px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-50 text-amber-700 border border-amber-200 uppercase tracking-wide">
                  {trip.status}
                </span>
              </div>

              <div className="space-y-1.5 text-sm">
                <div className="flex items-center gap-2 text-[var(--text-primary)] font-medium">
                  <User size={14} className="text-gray-400" />
                  <span>Rider: {trip.riderId.slice(-8)}</span>
                </div>
                {trip.driverId && (
                  <div className="flex items-center gap-2 text-[var(--text-primary)]">
                    <Car size={14} className="text-gray-400" />
                    <span>Driver: {trip.driverId.slice(-8)}</span>
                  </div>
                )}
                <div className="flex items-center gap-2 text-xs text-[var(--text-muted)]">
                  <Clock size={14} />
                  <span>{new Date(trip.createdAt).toLocaleTimeString()}</span>
                </div>
              </div>

              <div className="pt-2 border-t border-[var(--border)] flex justify-between items-center text-sm">
                <div className="flex items-center gap-1.5 text-[var(--text-secondary)]">
                  <MapPin size={14} />
                  <span>Coordinates: ({trip.pickupLat.toFixed(2)}, {trip.pickupLng.toFixed(2)})</span>
                </div>
                <span className="font-semibold text-[var(--brand-dark)]">₹{trip.estimatedFare ?? 0}</span>
              </div>
            </div>
          ))
        )}
      </div>
    </div>
  );
}

export default LiveTripMonitor;
