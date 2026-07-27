import { DriverState } from '../../../state/memory_store';
export interface ScoredDriver {
    id: string;
    lat: number;
    lng: number;
    score: number;
    distance: number;
    eta: number;
}
export declare class MatchingService {
    /**
     * Spawns Go matching-engine binary or performs local TS fallback scoring
     */
    static findDrivers(pickupLat: number, pickupLng: number, vehicleType: string): Promise<ScoredDriver[]>;
    private static queryGoEngine;
    static updateDriverLocation(driverId: string, lat: number, lng: number, heading?: number): Promise<void>;
    static setDriverAvailability(driverId: string, status: DriverState['status']): Promise<void>;
}
