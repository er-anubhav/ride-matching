import axios from 'axios';

// API base URL - proxy configured in package.json
const API_BASE = '/api';

// Types
export interface Driver {
  id: string;
  name: string | null;
  phone: string;
  vehicleType: string;
  kycStatus: string;
  createdAt: string;
}

export interface Payment {
  id: string;
  tripId: string;
  riderId: string;
  amount: number;
  status: string;
  createdAt: string;
}

export interface Trip {
  id: string;
  status: string;
  riderId: string;
  createdAt: string;
  estimatedFare: number | null;
  finalFare: number | null;
}

export interface KycPendingResponse {
  drivers: Driver[];
  total: number;
  page: number;
  limit: number;
}

// Helper to get auth token from localStorage
const getAuthToken = () => localStorage.getItem('adminToken');

// API Calls
export const api = {
  // KYC
  getPendingKyc: async (page = 1, limit = 10): Promise<KycPendingResponse> => {
    const token = getAuthToken();
    const response = await axios.get(`${API_BASE}/admin/kyc/pending`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { page, limit },
    });
    return response.data.data;
  },

  approveDriver: async (driverId: string): Promise<void> => {
    const token = getAuthToken();
    await axios.post(
      `${API_BASE}/admin/kyc/${driverId}/approve`,
      {},
      { headers: { Authorization: `Bearer ${token}` } }
    );
  },

  rejectDriver: async (driverId: string, reason: string): Promise<void> => {
    const token = getAuthToken();
    await axios.post(
      `${API_BASE}/admin/kyc/${driverId}/reject`,
      { reason },
      { headers: { Authorization: `Bearer ${token}` } }
    );
  },

  requestResubmission: async (driverId: string, reason: string): Promise<void> => {
    const token = getAuthToken();
    await axios.post(
      `${API_BASE}/admin/kyc/${driverId}/resubmit`,
      { reason },
      { headers: { Authorization: `Bearer ${token}` } }
    );
  },

  // Payments
  searchPayments: async (riderId = '', status = ''): Promise<Payment[]> => {
    const token = getAuthToken();
    const response = await axios.get(`${API_BASE}/admin/payments/search`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { riderId, status },
    });
    return response.data.payments;
  },

  // Trips
  getTripReports: async (cityId = '', dateRange = ''): Promise<Trip[]> => {
    const token = getAuthToken();
    const response = await axios.get(`${API_BASE}/admin/trips/reports`, {
      headers: { Authorization: `Bearer ${token}` },
      params: { cityId, dateRange },
    });
    return response.data.trips;
  },
};