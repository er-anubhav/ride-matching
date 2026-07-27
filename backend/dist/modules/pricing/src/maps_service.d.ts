export interface RouteEstimate {
    distanceKm: number;
    durationMin: number;
    estimated: boolean;
    routeSource: 'OLA_MAPS' | 'HAVERSINE_FALLBACK';
}
export declare class MapsService {
    /**
     * Fetches route data from Ola Maps. Falls back to Haversine straight-line distance if it fails.
     */
    static getRoute(originLat: number, originLng: number, destLat: number, destLng: number, cityId: string): Promise<RouteEstimate>;
    private static getFallbackEstimate;
}
