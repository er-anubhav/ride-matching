import { Prisma } from '@prisma/client';
import { prisma } from '../../../shared/prisma';
import { logger } from '../../../shared/logger';
import { eventBus } from '../../../shared/event_bus';
import { TripState } from '../../../state/memory_store';
import { BadRequestError, NotFoundError } from '../../../shared/errors';
import { redisClient } from '../../../shared/redis';
import { receiptQueue, tripTimeoutQueue } from '../../../shared/queues';
import { FcmService } from '../../notification';
import { CashPaymentProvider } from '../../payment/src/payment_service';

function mapTripToState(dbTrip: any, rider: any): TripState {
  return {
    id: dbTrip.id,
    riderId: dbTrip.riderId,
    riderName: rider?.name || 'Rider Name',
    riderPhone: rider?.phone || '+919999999999',
    driverId: dbTrip.driverId || undefined,
    status: dbTrip.status as any,
    pickupLat: dbTrip.pickupLat,
    pickupLng: dbTrip.pickupLng,
    pickupAddress: dbTrip.pickupAddress,
    dropoffLat: dbTrip.dropoffLat,
    dropoffLng: dbTrip.dropoffLng,
    dropoffAddress: dbTrip.dropoffAddress,
    price: Number(dbTrip.estimatedFare),
    otp: dbTrip.riderOtp,
    createdAt: dbTrip.createdAt.getTime(),
    startedAt: dbTrip.startedAt?.getTime(),
    completedAt: dbTrip.completedAt?.getTime(),
  };
}

export class TripService {
  public static async createTrip(params: {
    riderId: string;
    pickupLat: number;
    pickupLng: number;
    pickupAddress: string;
    dropoffLat: number;
    dropoffLng: number;
    dropoffAddress: string;
    price: number;
    vehicleType: string;
  }): Promise<TripState> {
    const rider = await prisma.user.findUnique({ where: { id: params.riderId } });
    if (!rider) {
      throw new NotFoundError(`Rider not found: ${params.riderId}`);
    }

    const dbTrip = await prisma.trip.create({
      data: {
        riderId: params.riderId,
        cityId: 'Lucknow',
        vehicleType: params.vehicleType,
        status: 'REQUESTED',
        pickupLat: params.pickupLat,
        pickupLng: params.pickupLng,
        pickupAddress: params.pickupAddress,
        dropoffLat: params.dropoffLat,
        dropoffLng: params.dropoffLng,
        dropoffAddress: params.dropoffAddress,
        estimatedFare: params.price,
        riderOtp: '4820',
      },
    });

    logger.info({ tripId: dbTrip.id }, 'Trip successfully written to PostgreSQL');

    const trip = mapTripToState(dbTrip, rider);
    eventBus.emit('trip.requested', trip);

    // Background Job: Check for trip dispatch timeout after 60 seconds
    await tripTimeoutQueue.add('check-timeout', { tripId: dbTrip.id }, { delay: 60000 });

    return trip;
  }

  public static async acceptTrip(tripId: string, driverId: string): Promise<TripState> {
    // 1. Atomic update to prevent race conditions
    const updateResult = await prisma.trip.updateMany({
      where: { id: tripId, status: 'REQUESTED' },
      data: {
        status: 'ASSIGNED',
        driverId,
      },
    });

    if (updateResult.count === 0) {
      const currentTrip = await prisma.trip.findUnique({ where: { id: tripId } });
      if (!currentTrip) {
        throw new NotFoundError(`Trip not found for id: ${tripId}`);
      }
      throw new BadRequestError(`Trip is no longer available. Current status: ${currentTrip.status}`);
    }

    // 2. Fetch the updated trip to return the state
    const updatedTrip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!updatedTrip) throw new NotFoundError('Trip not found after update');

    const rider = await prisma.user.findUnique({ where: { id: updatedTrip.riderId } });
    const trip = mapTripToState(updatedTrip, rider);

    // Get driver details for event
    const driverData = await redisClient.hgetall(`driver:data:${driverId}`);
    const driver = Object.keys(driverData).length > 0 ? (driverData as any) : null;
    const driverName = driver?.name || 'Vikram Singh';
    const driverPhone = driver?.phone || '+918888888888';

    // 3. Mark driver as IN_TRIP in Redis
    await redisClient.hset(`driver:data:${driverId}`, { status: 'IN_TRIP' });

    eventBus.emit('trip.accepted', {
      tripId,
      riderId: trip.riderId,
      driverId,
      driverName,
      driverPhone,
      vehicleNumber: driver?.vehicleNumber || 'UP32-AB-9999',
      vehicleModel: driver?.vehicleName || 'Maruti Swift',
      otp: trip.otp,
      eta: '3 mins',
      driverLat: driver?.lat ? parseFloat(driver.lat) : trip.pickupLat,
      driverLng: driver?.lng ? parseFloat(driver.lng) : trip.pickupLng,
    });

    return trip;
  }

  public static async rejectTrip(tripId: string, driverId: string): Promise<void> {
    const dbTrip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!dbTrip) throw new NotFoundError('Trip not found');

    if (dbTrip.status !== 'REQUESTED') {
      throw new BadRequestError(`Trip is already ${dbTrip.status}`);
    }

    // Trigger re-dispatch logic via event bus
    eventBus.emit('trip.rejected', { tripId, driverId });
    logger.info({ tripId, driverId }, 'Driver rejected trip. Re-dispatch triggered.');
  }

  public static async driverArrived(tripId: string, driverId: string): Promise<TripState> {
    const currentTrip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!currentTrip) throw new NotFoundError(`Trip not found: ${tripId}`);
    
    if (currentTrip.driverId !== driverId) throw new BadRequestError('Unauthorized to update this trip');
    if (currentTrip.status !== 'ASSIGNED') throw new BadRequestError(`Invalid transition from ${currentTrip.status} to ARRIVED`);

    const dbTrip = await prisma.trip.update({
      where: { id: tripId },
      data: { status: 'ARRIVED' },
    });

    const rider = await prisma.user.findUnique({ where: { id: dbTrip.riderId } });
    const trip = mapTripToState(dbTrip, rider);
    eventBus.emit('trip.arrived', trip);

    FcmService.sendPushNotification(
      trip.riderId,
      'Driver Arrived',
      'Your driver has arrived at the pickup location.',
      { tripId }
    ).catch(e => logger.error(e));

    return trip;
  }

  public static async startTrip(tripId: string, driverId: string, otp: string): Promise<TripState> {
    const dbTrip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!dbTrip) throw new NotFoundError(`Trip not found: ${tripId}`);

    if (dbTrip.driverId !== driverId) throw new BadRequestError('Unauthorized to update this trip');
    if (dbTrip.status !== 'ARRIVED') throw new BadRequestError(`Invalid transition from ${dbTrip.status} to IN_PROGRESS`);
    if (dbTrip.riderOtp !== otp) throw new BadRequestError('Invalid OTP code entered by driver');

    const updatedTrip = await prisma.trip.update({
      where: { id: tripId },
      data: {
        status: 'IN_PROGRESS',
        startedAt: new Date(),
      },
    });

    const rider = await prisma.user.findUnique({ where: { id: updatedTrip.riderId } });
    const trip = mapTripToState(updatedTrip, rider);
    eventBus.emit('trip.started', trip);

    FcmService.sendPushNotification(
      trip.riderId,
      'Trip Started',
      'Have a safe journey!',
      { tripId }
    ).catch(e => logger.error(e));

    return trip;
  }

  public static async completeTrip(tripId: string, driverId: string): Promise<TripState> {
    const dbTrip = await prisma.trip.findUnique({ where: { id: tripId } });
    if (!dbTrip) throw new NotFoundError(`Trip not found: ${tripId}`);

    if (dbTrip.driverId !== driverId) throw new BadRequestError('Unauthorized to update this trip');
    if (dbTrip.status !== 'IN_PROGRESS') throw new BadRequestError(`Invalid transition from ${dbTrip.status} to COMPLETED`);

    const updatedTrip = await prisma.trip.update({
      where: { id: tripId },
      data: {
        status: 'COMPLETED',
        completedAt: new Date(),
        finalFare: dbTrip.estimatedFare,
      },
    });

    const rider = await prisma.user.findUnique({ where: { id: updatedTrip.riderId } });
    const trip = mapTripToState(updatedTrip, rider);

    // Create payment record for cash payment
    const paymentId = await CashPaymentProvider.instance.createPayment(
      tripId,
      Number(dbTrip.estimatedFare),
      'CASH'
    );

    // Emit trip.completed event
    eventBus.emit('trip.completed', trip);

    // Set driver back to ONLINE
    await redisClient.hset(`driver:data:${driverId}`, { status: 'ONLINE' });

    // Background Job: Process receipt and notify rider
    await receiptQueue.add('generate-receipt', { tripId, paymentId });

    FcmService.sendPushNotification(
      trip.riderId,
      'Trip Completed',
      'Your trip has ended. Thank you for riding with Mr. Rideo!',
      { tripId }
    ).catch(e => logger.error(e));

    return trip;
  }

  public static async cancelTrip(tripId: string, reason: string, actorId: string): Promise<TripState> {
    let dbTrip;
    try {
      dbTrip = await prisma.trip.update({
        where: { id: tripId },
        data: {
          status: 'CANCELLED',
          cancelledBy: actorId,
          cancellationReason: reason,
        },
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
        throw new NotFoundError(`Trip not found: ${tripId}`);
      }
      throw err;
    }

    const rider = await prisma.user.findUnique({ where: { id: dbTrip.riderId } });
    const trip = mapTripToState(dbTrip, rider);
    eventBus.emit('trip.cancelled', { tripId, reason, actorId });
    return trip;
  }
}
