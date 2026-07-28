import { TripState } from '../../../state/memory_store';
export declare class TripService {
    static createTrip(params: {
        riderId: string;
        pickupLat: number;
        pickupLng: number;
        pickupAddress: string;
        dropoffLat: number;
        dropoffLng: number;
        dropoffAddress: string;
        price: number;
        vehicleType: string;
    }): Promise<TripState>;
    static acceptTrip(tripId: string, driverId: string): Promise<TripState>;
    static rejectTrip(tripId: string, driverId: string): Promise<void>;
    static driverArrived(tripId: string, driverId: string): Promise<TripState>;
    static startTrip(tripId: string, driverId: string, otp: string): Promise<TripState>;
    static completeTrip(tripId: string, driverId: string): Promise<TripState>;
    static cancelTrip(tripId: string, reason: string, actorId?: string): Promise<TripState>;
}
