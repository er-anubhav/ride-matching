"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TripService = void 0;
const client_1 = require("@prisma/client");
const prisma_1 = require("../../../shared/prisma");
const logger_1 = require("../../../shared/logger");
const event_bus_1 = require("../../../shared/event_bus");
const errors_1 = require("../../../shared/errors");
const redis_1 = require("../../../shared/redis");
const queues_1 = require("../../../shared/queues");
const notification_1 = require("../../notification");
const payment_service_1 = require("../../payment/src/payment_service");
function mapTripToState(dbTrip, rider) {
    return {
        id: dbTrip.id,
        riderId: dbTrip.riderId,
        riderName: rider?.name || 'Rider Name',
        riderPhone: rider?.phone || '+919999999999',
        driverId: dbTrip.driverId || undefined,
        status: dbTrip.status,
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
class TripService {
    static async createTrip(params) {
        const rider = await prisma_1.prisma.user.findUnique({ where: { id: params.riderId } });
        if (!rider) {
            throw new errors_1.NotFoundError(`Rider not found: ${params.riderId}`);
        }
        const dbTrip = await prisma_1.prisma.trip.create({
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
        logger_1.logger.info({ tripId: dbTrip.id }, 'Trip successfully written to PostgreSQL');
        const trip = mapTripToState(dbTrip, rider);
        event_bus_1.eventBus.emit('trip.requested', trip);
        // Background Job: Check for trip dispatch timeout after 60 seconds
        await queues_1.tripTimeoutQueue.add('check-timeout', { tripId: dbTrip.id }, { delay: 60000 });
        return trip;
    }
    static async acceptTrip(tripId, driverId) {
        // 1. Atomic update to prevent race conditions
        const updateResult = await prisma_1.prisma.trip.updateMany({
            where: { id: tripId, status: 'REQUESTED' },
            data: {
                status: 'ASSIGNED',
                driverId,
            },
        });
        if (updateResult.count === 0) {
            const currentTrip = await prisma_1.prisma.trip.findUnique({ where: { id: tripId } });
            if (!currentTrip) {
                throw new errors_1.NotFoundError(`Trip not found for id: ${tripId}`);
            }
            throw new errors_1.BadRequestError(`Trip is no longer available. Current status: ${currentTrip.status}`);
        }
        // 2. Fetch the updated trip to return the state
        const updatedTrip = await prisma_1.prisma.trip.findUnique({ where: { id: tripId } });
        if (!updatedTrip)
            throw new errors_1.NotFoundError('Trip not found after update');
        const rider = await prisma_1.prisma.user.findUnique({ where: { id: updatedTrip.riderId } });
        const trip = mapTripToState(updatedTrip, rider);
        // Get driver details for event
        const driverData = await redis_1.redisClient.hgetall(`driver:data:${driverId}`);
        const driver = Object.keys(driverData).length > 0 ? driverData : null;
        const driverName = driver?.name || 'Vikram Singh';
        const driverPhone = driver?.phone || '+918888888888';
        // 3. Mark driver as IN_TRIP in Redis
        await redis_1.redisClient.hset(`driver:data:${driverId}`, { status: 'IN_TRIP' });
        event_bus_1.eventBus.emit('trip.accepted', {
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
    static async rejectTrip(tripId, driverId) {
        const dbTrip = await prisma_1.prisma.trip.findUnique({ where: { id: tripId } });
        if (!dbTrip)
            throw new errors_1.NotFoundError('Trip not found');
        if (dbTrip.status !== 'REQUESTED') {
            throw new errors_1.BadRequestError(`Trip is already ${dbTrip.status}`);
        }
        // Trigger re-dispatch logic via event bus
        event_bus_1.eventBus.emit('trip.rejected', { tripId, driverId });
        logger_1.logger.info({ tripId, driverId }, 'Driver rejected trip. Re-dispatch triggered.');
    }
    static async driverArrived(tripId, driverId) {
        const currentTrip = await prisma_1.prisma.trip.findUnique({ where: { id: tripId } });
        if (!currentTrip)
            throw new errors_1.NotFoundError(`Trip not found: ${tripId}`);
        if (currentTrip.driverId !== driverId)
            throw new errors_1.BadRequestError('Unauthorized to update this trip');
        if (currentTrip.status !== 'ASSIGNED')
            throw new errors_1.BadRequestError(`Invalid transition from ${currentTrip.status} to ARRIVED`);
        const dbTrip = await prisma_1.prisma.trip.update({
            where: { id: tripId },
            data: { status: 'ARRIVED' },
        });
        const rider = await prisma_1.prisma.user.findUnique({ where: { id: dbTrip.riderId } });
        const trip = mapTripToState(dbTrip, rider);
        event_bus_1.eventBus.emit('trip.arrived', trip);
        notification_1.FcmService.sendPushNotification(trip.riderId, 'Driver Arrived', 'Your driver has arrived at the pickup location.', { tripId }).catch(e => logger_1.logger.error(e));
        return trip;
    }
    static async startTrip(tripId, driverId, otp) {
        const dbTrip = await prisma_1.prisma.trip.findUnique({ where: { id: tripId } });
        if (!dbTrip)
            throw new errors_1.NotFoundError(`Trip not found: ${tripId}`);
        if (dbTrip.driverId !== driverId)
            throw new errors_1.BadRequestError('Unauthorized to update this trip');
        if (dbTrip.status !== 'ARRIVED')
            throw new errors_1.BadRequestError(`Invalid transition from ${dbTrip.status} to IN_PROGRESS`);
        if (dbTrip.riderOtp !== otp)
            throw new errors_1.BadRequestError('Invalid OTP code entered by driver');
        const updatedTrip = await prisma_1.prisma.trip.update({
            where: { id: tripId },
            data: {
                status: 'IN_PROGRESS',
                startedAt: new Date(),
            },
        });
        const rider = await prisma_1.prisma.user.findUnique({ where: { id: updatedTrip.riderId } });
        const trip = mapTripToState(updatedTrip, rider);
        event_bus_1.eventBus.emit('trip.started', trip);
        notification_1.FcmService.sendPushNotification(trip.riderId, 'Trip Started', 'Have a safe journey!', { tripId }).catch(e => logger_1.logger.error(e));
        return trip;
    }
    static async completeTrip(tripId, driverId) {
        const dbTrip = await prisma_1.prisma.trip.findUnique({ where: { id: tripId } });
        if (!dbTrip)
            throw new errors_1.NotFoundError(`Trip not found: ${tripId}`);
        if (dbTrip.driverId !== driverId)
            throw new errors_1.BadRequestError('Unauthorized to update this trip');
        if (dbTrip.status !== 'IN_PROGRESS')
            throw new errors_1.BadRequestError(`Invalid transition from ${dbTrip.status} to COMPLETED`);
        const updatedTrip = await prisma_1.prisma.trip.update({
            where: { id: tripId },
            data: {
                status: 'COMPLETED',
                completedAt: new Date(),
                finalFare: dbTrip.estimatedFare,
            },
        });
        const rider = await prisma_1.prisma.user.findUnique({ where: { id: updatedTrip.riderId } });
        const trip = mapTripToState(updatedTrip, rider);
        // Create payment record for cash payment
        const paymentId = await payment_service_1.CashPaymentProvider.instance.createPayment(tripId, Number(dbTrip.estimatedFare), 'CASH');
        // Emit trip.completed event
        event_bus_1.eventBus.emit('trip.completed', trip);
        // Set driver back to ONLINE
        await redis_1.redisClient.hset(`driver:data:${driverId}`, { status: 'ONLINE' });
        // Background Job: Process receipt and notify rider
        await queues_1.receiptQueue.add('generate-receipt', { tripId, paymentId });
        notification_1.FcmService.sendPushNotification(trip.riderId, 'Trip Completed', 'Your trip has ended. Thank you for riding with Mr. Rideo!', { tripId }).catch(e => logger_1.logger.error(e));
        return trip;
    }
    static async cancelTrip(tripId, reason, actorId) {
        let dbTrip;
        try {
            dbTrip = await prisma_1.prisma.trip.update({
                where: { id: tripId },
                data: {
                    status: 'CANCELLED',
                    cancelledBy: actorId,
                    cancellationReason: reason,
                },
            });
        }
        catch (err) {
            if (err instanceof client_1.Prisma.PrismaClientKnownRequestError && err.code === 'P2025') {
                throw new errors_1.NotFoundError(`Trip not found: ${tripId}`);
            }
            throw err;
        }
        const rider = await prisma_1.prisma.user.findUnique({ where: { id: dbTrip.riderId } });
        const trip = mapTripToState(dbTrip, rider);
        event_bus_1.eventBus.emit('trip.cancelled', { tripId, reason, actorId });
        return trip;
    }
}
exports.TripService = TripService;
