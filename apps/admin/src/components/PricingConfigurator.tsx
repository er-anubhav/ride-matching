import React, { useState, useEffect } from 'react';
import { Save } from 'lucide-react';
import axios from 'axios';

interface PricingTier {
  vehicleType: string;
  baseFare: number;
  perKmRate: number;
  perMinuteRate: number;
  minimumFare: number;
}

export function PricingConfigurator() {
  const [tiers, setTiers] = useState<PricingTier[]>([
    { vehicleType: 'BIKE', baseFare: 25, perKmRate: 8, perMinuteRate: 1.5, minimumFare: 30 },
    { vehicleType: 'AUTO', baseFare: 35, perKmRate: 12, perMinuteRate: 2, minimumFare: 40 },
    { vehicleType: 'CAB_ECONOMY', baseFare: 60, perKmRate: 15, perMinuteRate: 2.5, minimumFare: 80 },
    { vehicleType: 'CAB_PREMIUM', baseFare: 100, perKmRate: 22, perMinuteRate: 4, minimumFare: 120 },
  ]);
  const [saved, setSaved] = useState(false);

  const token = localStorage.getItem('adminToken') || '';
  const authHeader = { headers: { Authorization: `Bearer ${token}` } };

  useEffect(() => {
    fetchPricing();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const fetchPricing = async () => {
    try {
      const res = await axios.get('/api/admin/pricing', authHeader);
      if (res.data && res.data.tiers && res.data.tiers.length > 0) {
        setTiers(res.data.tiers);
      }
    } catch (err) {
      console.error('Failed to fetch pricing config:', err);
    }
  };

  const handleUpdate = (index: number, field: keyof PricingTier, value: number) => {
    const next = [...tiers];
    next[index] = { ...next[index], [field]: value };
    setTiers(next);
    setSaved(false);
  };

  const handleSave = async () => {
    try {
      await axios.put('/api/admin/pricing', { tiers }, authHeader);
      setSaved(true);
      setTimeout(() => setSaved(false), 3000);
    } catch (err) {
      console.error('Failed to save pricing matrix:', err);
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex justify-between items-center">
        <div>
          <h1 className="text-xl font-semibold text-[var(--text-primary)]">City Pricing Configuration</h1>
          <p className="text-sm text-[var(--text-muted)]">Configure base fares, per-kilometer rates, and minimum pricing per vehicle category.</p>
        </div>
        <button
          onClick={handleSave}
          className="flex items-center gap-2 px-4 py-2 bg-[var(--brand)] text-white font-medium rounded-lg hover:bg-emerald-600 transition-colors shadow-sm"
        >
          <Save size={16} />
          {saved ? 'Saved Successfully!' : 'Save Pricing Matrix'}
        </button>
      </div>

      <div className="bg-[var(--surface-raised)] border border-[var(--border)] rounded-xl overflow-hidden shadow-sm">
        <table className="w-full text-left text-sm">
          <thead className="bg-[var(--bg)] border-b border-[var(--border)] text-xs text-[var(--text-muted)] uppercase tracking-wider">
            <tr>
              <th className="px-6 py-3.5 font-medium">Vehicle Category</th>
              <th className="px-6 py-3.5 font-medium">Base Fare (₹)</th>
              <th className="px-6 py-3.5 font-medium">Per Km Rate (₹)</th>
              <th className="px-6 py-3.5 font-medium">Per Minute Rate (₹)</th>
              <th className="px-6 py-3.5 font-medium">Minimum Fare (₹)</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-[var(--border)]">
            {tiers.map((tier, idx) => (
              <tr key={tier.vehicleType} className="hover:bg-gray-50/50">
                <td className="px-6 py-4 font-semibold text-[var(--text-primary)]">{tier.vehicleType}</td>
                <td className="px-6 py-4">
                  <input
                    type="number"
                    value={tier.baseFare}
                    onChange={(e) => handleUpdate(idx, 'baseFare', Number(e.target.value))}
                    className="w-24 px-3 py-1.5 bg-[var(--surface-inset)] border border-[var(--border-strong)] rounded text-sm"
                  />
                </td>
                <td className="px-6 py-4">
                  <input
                    type="number"
                    value={tier.perKmRate}
                    onChange={(e) => handleUpdate(idx, 'perKmRate', Number(e.target.value))}
                    className="w-24 px-3 py-1.5 bg-[var(--surface-inset)] border border-[var(--border-strong)] rounded text-sm"
                  />
                </td>
                <td className="px-6 py-4">
                  <input
                    type="number"
                    value={tier.perMinuteRate}
                    onChange={(e) => handleUpdate(idx, 'perMinuteRate', Number(e.target.value))}
                    className="w-24 px-3 py-1.5 bg-[var(--surface-inset)] border border-[var(--border-strong)] rounded text-sm"
                  />
                </td>
                <td className="px-6 py-4">
                  <input
                    type="number"
                    value={tier.minimumFare}
                    onChange={(e) => handleUpdate(idx, 'minimumFare', Number(e.target.value))}
                    className="w-24 px-3 py-1.5 bg-[var(--surface-inset)] border border-[var(--border-strong)] rounded text-sm"
                  />
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default PricingConfigurator;
