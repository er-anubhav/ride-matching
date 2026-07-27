export interface FareEstimate {
    baseFare: number;
    perKmRate: number;
    perMinRate: number;
    minimumFare: number;
    distanceKm: number;
    durationMin: number;
    estimatedFare: number;
    surgeMultiplier: number;
    estimated: boolean;
    routeSource: 'OLA_MAPS' | 'HAVERSINE_FALLBACK';
}
export declare function getDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number;
export declare class PricingService {
    static calculateFare(pickupLat: number, pickupLng: number, destLat: number, destLng: number, vehicleType: string, cityId: string): Promise<FareEstimate>;
}
