import { useState, useEffect } from 'react';
import axios from 'axios';
import { useAuth } from './useAuth';

export interface KycPendingResponse {
  drivers: any[];
  total: number;
  page: number;
  limit: number;
}

const API_BASE = '/api';

export const useAdminDashboard = () => {
  const { user } = useAuth();
  const [kycData, setKycData] = useState<KycPendingResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadKycData = async () => {
      try {
        const token = localStorage.getItem('adminToken');
        const response = await axios.get(`${API_BASE}/admin/kyc/pending`, {
          headers: { Authorization: `Bearer ${token}` },
          params: { page: 1, limit: 10 }
        });
        setKycData(response.data.data);
        setLoading(false);
      } catch (err) {
        setError('Failed to load KYC data');
        setLoading(false);
      }
      loadKycData();
    };
    loadKycData();
  }, [user]);

  return { kycData, loading, error };
};