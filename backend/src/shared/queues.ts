import { Queue, QueueOptions } from 'bullmq';
import { config } from './config';

// BullMQ connection uses the raw redis connection options rather than an existing client
// because workers often need to open blocking connections.
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

const queueOptions: QueueOptions = {
  connection: {
    url: redisUrl,
  },
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
    removeOnComplete: true, // Keep redis clean
    removeOnFail: false,    // Keep failed jobs for inspection
  },
};

// Queue for processing trip receipts after completion
export const receiptQueue = new Queue('receipt-queue', queueOptions);

// Queue for handling delayed tasks like checking if a requested trip timed out
export const tripTimeoutQueue = new Queue('trip-timeout-queue', queueOptions);
