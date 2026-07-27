export interface DriverState {
    driverId: string;
    name: string;
    phone: string;
    vehicleNumber: string;
    vehicleName: string;
    vehicleType: string;
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
declare class MemoryStore {
    readonly localSockets: Map<string, any>;
    constructor();
    getSocket(id: string): any;
    setSocket(id: string, socket: any): void;
    removeSocket(id: string): void;
}
export declare const memoryStore: MemoryStore;
export default memoryStore;
