import { prisma } from '../../../shared/prisma';
import { logger } from '../../../shared/logger';
import { MapsService } from './maps_service';

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

// Keep this export since MapsService uses it for fallback
export function getDistanceKm(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371.0;
  const dLat = ((lat2 - lat1) * Math.PI) / 180.0;
  const dLon = ((lon2 - lon1) * Math.PI) / 180.0;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180.0) *
      Math.cos((lat2 * Math.PI) / 180.0) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

export class PricingService {
  public static async calculateFare(
    pickupLat: number,
    pickupLng: number,
    destLat: number,
    destLng: number,
    vehicleType: string,
    cityId: string
  ): Promise<FareEstimate> {
    
    // 1. Fetch DB pricing configuration
    let config = await prisma.cityConfig.findFirst({
      where: {
        cityId: cityId,
        vehicleType: vehicleType,
        isActive: true,
      }
    });

    if (!config) {
      logger.warn({ cityId, vehicleType }, 'City configuration not found. Falling back to default hardcoded rates.');
      // Fallback constants if DB lacks config
      let baseFare = 40.0;
      let perKmRate = 12.0;
      let perMinRate = 2.0;
      let minimumFare = 50.0;

      switch (vehicleType.toLowerCase()) {
        case 'auto':
          baseFare = 30.0;
          perKmRate = 10.0;
          perMinRate = 1.5;
          minimumFare = 40.0;
          break;
        case 'cab':
        case 'sedan':
        case 'suv':
          baseFare = 60.0;
          perKmRate = 18.0;
          perMinRate = 3.0;
          minimumFare = 80.0;
          break;
        case 'bike':
        default:
          baseFare = 20.0;
          perKmRate = 8.0;
          perMinRate = 1.0;
          minimumFare = 30.0;
          break;
      }

      config = {
        baseFare: baseFare as any,
        perKmRate: perKmRate as any,
        perMinRate: perMinRate as any,
        minimumFare: minimumFare as any,
      } as any;
    }

    const baseFare = Number(config!.baseFare);
    const perKmRate = Number(config!.perKmRate);
    const perMinRate = Number(config!.perMinRate);
    const minimumFare = Number(config!.minimumFare);

    // 2. Fetch routing and duration
    const route = await MapsService.getRoute(pickupLat, pickupLng, destLat, destLng, cityId);

    // 3. Compute Fare
    const surgeMultiplier = 1.0;
    
    const timeFare = route.durationMin * perMinRate;
    const distanceFare = route.distanceKm * perKmRate;
    let rawFare = baseFare + distanceFare + timeFare;

    if (rawFare < minimumFare) {
      rawFare = minimumFare;
    }

    const estimatedFare = Math.round(rawFare * surgeMultiplier * 100) / 100;

    return {
      baseFare,
      perKmRate,
      perMinRate,
      minimumFare,
      distanceKm: route.distanceKm,
      durationMin: route.durationMin,
      estimatedFare,
      surgeMultiplier,
      estimated: route.estimated,
      routeSource: route.routeSource,
    };
  }
}
