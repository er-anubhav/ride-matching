"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tripTimeoutWorker = exports.receiptWorker = void 0;
const bullmq_1 = require("bullmq");
const logger_1 = require("../shared/logger");
const prisma_1 = require("../shared/prisma");
const trip_service_1 = require("../modules/trip/src/trip_service");
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
const connection = {
    url: redisUrl,
};
// 1. Receipt Worker
exports.receiptWorker = new bullmq_1.Worker('receipt-queue', async (job) => {
    const { tripId } = job.data;
    logger_1.logger.info({ tripId, jobId: job.id }, 'Processing receipt generation job...');
    const trip = await prisma_1.prisma.trip.findUnique({
        where: { id: tripId },
    });
    if (!trip) {
        logger_1.logger.warn({ tripId }, 'Trip not found during receipt generation');
        return;
    }
    const rider = await prisma_1.prisma.user.findUnique({
        where: { id: trip.riderId },
    });
    // Simulate heavy PDF generation or API call to email provider
    await new Promise((resolve) => setTimeout(resolve, 2000));
    logger_1.logger.info({
        tripId,
        riderEmail: rider?.email || 'unknown@example.com',
        fare: trip.finalFare?.toString()
    }, 'Successfully sent receipt to rider');
}, { connection });
exports.receiptWorker.on('completed', (job) => {
    logger_1.logger.debug({ jobId: job.id }, 'Receipt job completed');
});
exports.receiptWorker.on('failed', (job, err) => {
    logger_1.logger.error({ jobId: job?.id, err }, 'Receipt job failed');
});
// 2. Trip Timeout Worker
exports.tripTimeoutWorker = new bullmq_1.Worker('trip-timeout-queue', async (job) => {
    const { tripId } = job.data;
    logger_1.logger.info({ tripId, jobId: job.id }, 'Checking for trip dispatch timeout...');
    const trip = await prisma_1.prisma.trip.findUnique({
        where: { id: tripId },
    });
    if (!trip) {
        return;
    }
    if (trip.status === 'REQUESTED') {
        logger_1.logger.warn({ tripId }, 'Trip timed out waiting for a driver. Cancelling via system...');
        // We use a 'SYSTEM' actor ID to denote automatic cancellation
        await trip_service_1.TripService.cancelTrip(tripId, 'No drivers accepted the dispatch in time.', 'SYSTEM');
    }
    else {
        logger_1.logger.debug({ tripId, status: trip.status }, 'Trip was already accepted or cancelled, skipping timeout logic.');
    }
}, { connection });
exports.tripTimeoutWorker.on('completed', (job) => {
    logger_1.logger.debug({ jobId: job.id }, 'Timeout check job completed');
});
exports.tripTimeoutWorker.on('failed', (job, err) => {
    logger_1.logger.error({ jobId: job?.id, err }, 'Timeout check job failed');
});
