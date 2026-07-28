"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createServer = createServer;
const fastify_1 = __importDefault(require("fastify"));
const cors_1 = __importDefault(require("@fastify/cors"));
const websocket_1 = __importDefault(require("@fastify/websocket"));
const logger_1 = require("./shared/logger");
const auth_1 = require("./modules/auth");
const trip_1 = require("./modules/trip");
const notification_1 = require("./modules/notification");
const errors_1 = require("./shared/errors");
const config_1 = require("./shared/config");
const redis_1 = require("./shared/redis");
const auth_2 = require("./modules/auth");
async function createServer() {
    notification_1.PubSubService.initialize();
    const server = (0, fastify_1.default)({
        logger: false, // Use our custom Pino logger
    });
    // Enable CORS
    await server.register(cors_1.default, {
        origin: '*',
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    });
    // Enable Rate Limiting if configured
    if (config_1.config.ENABLE_RATE_LIMIT) {
        await server.register(Promise.resolve().then(() => __importStar(require('@fastify/rate-limit'))), {
            global: true,
            max: 100, // default limit
            timeWindow: '1 minute',
            redis: redis_1.redisClient,
            errorResponseBuilder: (request, context) => {
                return new errors_1.AppError(429, 'Too Many Requests', `Rate limit exceeded, retry in ${context.after} time units`, 'https://errors.mrrideo.com/too-many-requests', request.url).toRFC7807(request.url);
            },
        });
    }
    // Enable WebSockets
    await server.register(websocket_1.default, {
        options: {
            maxPayload: 1048576, // 1MB
        },
    });
    // Global Error Handler following RFC 7807 problem details specifications
    server.setErrorHandler((error, request, reply) => {
        logger_1.logger.error(error, `Request failed at ${request.url}`);
        if (error instanceof errors_1.AppError) {
            return reply.code(error.statusCode).send(error.toRFC7807(request.url));
        }
        // Default fall-through fallback for unhandled exceptions
        return reply.code(500).send({
            type: 'about:blank',
            title: 'Internal Server Error',
            status: 500,
            detail: error.message || 'An unexpected server error occurred',
            instance: request.url,
        });
    });
    // Health check endpoint
    server.get('/health', async () => {
        return { status: 'healthy', timestamp: new Date().toISOString() };
    });
    // System endpoint to query active rider locations for simulation script
    server.get('/api/system/rider-locations', async (request, reply) => {
        const locations = [];
        for (const [riderId, sub] of notification_1.activeRiderSubscriptions.entries()) {
            locations.push({
                riderId,
                lat: sub.lat,
                lng: sub.lng,
            });
        }
        return locations;
    });
    // Register REST routes
    await server.register(auth_1.authRoutes);
    await server.register(trip_1.tripRoutes);
    await server.register((await Promise.resolve().then(() => __importStar(require('./modules/kyc')))).kycRoutes);
    await server.register((await Promise.resolve().then(() => __importStar(require('./modules/user_api')))).userApiRoutes);
    await server.register((await Promise.resolve().then(() => __importStar(require('./modules/driver_api')))).driverApiRoutes);
    // Register Ride Tracking WebSocket handler
    server.route({
        method: 'GET',
        url: '/ride-tracking',
        preValidation: [auth_2.verifyJwtMiddleware],
        handler: async (req, reply) => {
            // Return 400 if client requests HTTP on WebSocket route
            reply.code(400).send({ error: 'WebSocket connection expected' });
        },
        wsHandler: notification_1.handleWebSocketConnection,
    });
    return server;
}
