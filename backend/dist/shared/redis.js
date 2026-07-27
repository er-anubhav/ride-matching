"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.subClient = exports.pubClient = exports.redisClient = void 0;
const ioredis_1 = require("ioredis");
const logger_1 = require("./logger");
const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
exports.redisClient = new ioredis_1.Redis(redisUrl, {
    maxRetriesPerRequest: null,
    enableReadyCheck: false
});
exports.pubClient = new ioredis_1.Redis(redisUrl);
exports.subClient = new ioredis_1.Redis(redisUrl);
exports.redisClient.on('error', (err) => logger_1.logger.error({ err }, 'Redis Client Error'));
exports.pubClient.on('error', (err) => logger_1.logger.error({ err }, 'Redis Pub Client Error'));
exports.subClient.on('error', (err) => logger_1.logger.error({ err }, 'Redis Sub Client Error'));
exports.redisClient.on('connect', () => logger_1.logger.info('Connected to Redis (Data Client)'));
exports.pubClient.on('connect', () => logger_1.logger.info('Connected to Redis (Pub Client)'));
exports.subClient.on('connect', () => logger_1.logger.info('Connected to Redis (Sub Client)'));
