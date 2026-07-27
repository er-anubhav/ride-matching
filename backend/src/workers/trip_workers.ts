import { Worker, Job } from 'bullmq';
import { logger } from '../shared/logger';
import { prisma } from '../shared/prisma';
import { TripService } from '../modules/trip/src/trip_service';

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

const connection = {
  url: redisUrl,
};

// 1. Receipt Worker
export const receiptWorker = new Worker('receipt-queue', async (job: Job) => {
  const { tripId } = job.data;
  logger.info({ tripId, jobId: job.id }, 'Processing receipt generation job...');

  const trip = await prisma.trip.findUnique({
    where: { id: tripId },
  });

  if (!trip) {
    logger.warn({ tripId }, 'Trip not found during receipt generation');
    return;
  }

  const rider = await prisma.user.findUnique({
    where: { id: trip.riderId },
  });

  logger.info({ 
    tripId, 
    riderEmail: rider?.email || 'unknown@example.com', 
    fare: trip.finalFare?.toString() 
  }, 'Successfully sent receipt to rider');
}, { connection });


receiptWorker.on('completed', (job: Job) => {
  logger.debug({ jobId: job.id }, 'Receipt job completed');
});

receiptWorker.on('failed', (job, err) => {
  logger.error({ jobId: job?.id, err }, 'Receipt job failed');
});


// 2. Trip Timeout Worker
export const tripTimeoutWorker = new Worker('trip-timeout-queue', async (job: Job) => {
  const { tripId } = job.data;
  logger.info({ tripId, jobId: job.id }, 'Checking for trip dispatch timeout...');

  const trip = await prisma.trip.findUnique({
    where: { id: tripId },
  });

  if (!trip) {
    return;
  }

  if (trip.status === 'REQUESTED') {
    logger.warn({ tripId }, 'Trip timed out waiting for a driver. Cancelling via system...');
    // We use a 'SYSTEM' actor ID to denote automatic cancellation
    await TripService.cancelTrip(tripId, 'No drivers accepted the dispatch in time.', 'SYSTEM');
  } else {
    logger.debug({ tripId, status: trip.status }, 'Trip was already accepted or cancelled, skipping timeout logic.');
  }
}, { connection });

tripTimeoutWorker.on('completed', (job: Job) => {
  logger.debug({ jobId: job.id }, 'Timeout check job completed');
});

tripTimeoutWorker.on('failed', (job, err) => {
  logger.error({ jobId: job?.id, err }, 'Timeout check job failed');
});
