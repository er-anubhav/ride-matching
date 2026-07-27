"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tripTimeoutQueue = exports.receiptQueue = void 0;
const bullmq_1 = require("bullmq");
// BullMQ connection uses the raw redis connection options rather than an existing client
// because workers often need to open blocking connections.
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
const queueOptions = {
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
        removeOnFail: false, // Keep failed jobs for inspection
    },
};
// Queue for processing trip receipts after completion
exports.receiptQueue = new bullmq_1.Queue('receipt-queue', queueOptions);
// Queue for handling delayed tasks like checking if a requested trip timed out
exports.tripTimeoutQueue = new bullmq_1.Queue('trip-timeout-queue', queueOptions);
