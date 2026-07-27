import { logger } from '../shared/logger';

export interface DriverState {
  driverId: string;
  name: string;
  phone: string;
  vehicleNumber: string;
  vehicleName: string;
  vehicleType: string; // bike | auto | cab
  lat: number;
  lng: number;
  status: 'ONLINE' | 'IDLE' | 'NOTIFIED' | 'ON_TRIP' | 'OFFLINE';
  rating: number;
  acceptanceRate: number;
  cancellationRate: number;
  lastSeen: number;
}

export interface TripState {
  id: string;
  riderId: string;
  riderName: string;
  riderPhone: string;
  driverId?: string;
  status: 'REQUESTED' | 'ASSIGNED' | 'ARRIVED' | 'IN_PROGRESS' | 'COMPLETED' | 'CANCELLED';
  pickupLat: number;
  pickupLng: number;
  pickupAddress: string;
  dropoffLat: number;
  dropoffLng: number;
  dropoffAddress: string;
  price: number;
  otp: string;
  createdAt: number;
  startedAt?: number;
  completedAt?: number;
}

class MemoryStore {
  // Map of userId/driverId -> WS Socket on this specific Node.js instance
  public readonly localSockets = new Map<string, any>();
  
  constructor() {
    logger.info('MemoryStore singleton initialized.');
  }

  getSocket(id: string): any {
    return this.localSockets.get(id);
  }

  setSocket(id: string, socket: any): void {
    this.localSockets.set(id, socket);
    logger.debug(`Socket registered for ID: ${id}`);
  }

  removeSocket(id: string): void {
    this.localSockets.delete(id);
    logger.debug(`Socket removed for ID: ${id}`);
  }
}

export const memoryStore = new MemoryStore();
export default memoryStore;
