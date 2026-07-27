import { config } from '../../../shared/config';
import { logger } from '../../../shared/logger';
import { getDistanceKm } from './pricing_service';

export interface RouteEstimate {
  distanceKm: number;
  durationMin: number;
  estimated: boolean;
  routeSource: 'OLA_MAPS' | 'HAVERSINE_FALLBACK';
}

export class MapsService {
  /**
   * Fetches route data from Ola Maps. Falls back to Haversine straight-line distance if it fails.
   */
  public static async getRoute(
    originLat: number,
    originLng: number,
    destLat: number,
    destLng: number,
    cityId: string
  ): Promise<RouteEstimate> {
    const fallbackEstimate = this.getFallbackEstimate(originLat, originLng, destLat, destLng, cityId);

    if (!config.OLA_MAPS_API_KEY) {
      logger.warn({ cityId, reason: 'MISSING_API_KEY' }, 'Route estimation fallback triggered');
      return fallbackEstimate;
    }

    try {
      const url = `https://api.olamaps.io/routing/v1/directions?origin=${originLat},${originLng}&destination=${destLat},${destLng}&api_key=${config.OLA_MAPS_API_KEY}`;
      
      // Use AbortController for 3-second timeout
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 3000);

      const response = await fetch(url, { signal: controller.signal });
      clearTimeout(timeoutId);

      if (!response.ok) {
        logger.warn({ cityId, status: response.status, reason: 'OLA_MAPS_API_ERROR' }, 'Route estimation fallback triggered');
        return fallbackEstimate;
      }

      const data = await response.json();
      
      // Basic Ola Maps response parsing (assumes typical OSRM/Google Maps style structure)
      if (data.routes && data.routes.length > 0) {
        const route = data.routes[0];
        // Ensure properties exist, sometimes it's under legs[0]
        const distanceMeters = route.distance || (route.legs?.[0]?.distance) || 0;
        const durationSeconds = route.duration || (route.legs?.[0]?.duration) || 0;

        if (distanceMeters > 0) {
          return {
            distanceKm: distanceMeters / 1000,
            durationMin: Math.ceil(durationSeconds / 60),
            estimated: false,
            routeSource: 'OLA_MAPS'
          };
        }
      }

      logger.warn({ cityId, reason: 'INVALID_OLA_MAPS_RESPONSE' }, 'Route estimation fallback triggered');
      return fallbackEstimate;
    } catch (err: any) {
      const reason = err.name === 'AbortError' ? 'OLA_MAPS_TIMEOUT' : 'OLA_MAPS_EXCEPTION';
      logger.warn({ cityId, reason, err: err.message }, 'Route estimation fallback triggered');
      return fallbackEstimate;
    }
  }

  private static getFallbackEstimate(
    originLat: number,
    originLng: number,
    destLat: number,
    destLng: number,
    cityId: string
  ): RouteEstimate {
    const distanceKm = getDistanceKm(originLat, originLng, destLat, destLng);
    
    // Read configurable speed or fallback to 30 km/h
    const envVar = `AVG_SPEED_KMPH_${cityId.toUpperCase()}`;
    const configuredSpeed = process.env[envVar] ? parseInt(process.env[envVar] as string, 10) : 30;
    const avgSpeedKmph = isNaN(configuredSpeed) ? 30 : configuredSpeed;

    // Time = Distance / Speed
    const durationHours = distanceKm / avgSpeedKmph;
    const durationMin = Math.ceil(durationHours * 60);

    return {
      distanceKm: parseFloat(distanceKm.toFixed(2)),
      durationMin: durationMin > 0 ? durationMin : 1, // Minimum 1 minute
      estimated: true,
      routeSource: 'HAVERSINE_FALLBACK'
    };
  }
}
