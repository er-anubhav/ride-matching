import { Redis } from 'ioredis';
import { logger } from './logger';
import { config } from './config';

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';

export const redisClient = new Redis(redisUrl, {
  maxRetriesPerRequest: null,
  enableReadyCheck: false
});

export const pubClient = new Redis(redisUrl);
export const subClient = new Redis(redisUrl);

redisClient.on('error', (err) => logger.error({ err }, 'Redis Client Error'));
pubClient.on('error', (err) => logger.error({ err }, 'Redis Pub Client Error'));
subClient.on('error', (err) => logger.error({ err }, 'Redis Sub Client Error'));

redisClient.on('connect', () => logger.info('Connected to Redis (Data Client)'));
pubClient.on('connect', () => logger.info('Connected to Redis (Pub Client)'));
subClient.on('connect', () => logger.info('Connected to Redis (Sub Client)'));
