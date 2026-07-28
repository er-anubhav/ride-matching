import Fastify from 'fastify';
import cors from '@fastify/cors';
import websocket from '@fastify/websocket';
import { logger } from './shared/logger';
import { authRoutes } from './modules/auth';
import { tripRoutes } from './modules/trip';
import { handleWebSocketConnection, activeRiderSubscriptions, PubSubService } from './modules/notification';
import { AppError } from './shared/errors';
import { config } from './shared/config';
import { redisClient } from './shared/redis';
import { verifyJwtMiddleware } from './modules/auth';

export async function createServer() {
  PubSubService.initialize();

  const server = Fastify({
    logger: false, // Use our custom Pino logger
  });

  // Enable CORS
  await server.register(cors, {
    origin: '*',
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  });

  // Enable Rate Limiting if configured
  if (config.ENABLE_RATE_LIMIT) {
    await server.register(import('@fastify/rate-limit'), {
      global: true,
      max: 100, // default limit
      timeWindow: '1 minute',
      redis: redisClient,
      errorResponseBuilder: (request, context) => {
        return new AppError(
          429,
          'Too Many Requests',
          `Rate limit exceeded, retry in ${context.after} time units`,
          'https://errors.ridematching.com/too-many-requests',
          request.url
        ).toRFC7807(request.url);
      },
    });
  }

  // Enable WebSockets
  await server.register(websocket, {
    options: {
      maxPayload: 1048576, // 1MB
    },
  });

  // Global Error Handler following RFC 7807 problem details specifications
  server.setErrorHandler((error, request, reply) => {
    logger.error(error, `Request failed at ${request.url}`);

    if (error instanceof AppError) {
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

function getGitCommitInfo() {
  let commit = process.env.GIT_COMMIT || '8d7a9f2';
  let branch = process.env.GIT_BRANCH || 'main';
  try {
    const { execSync } = require('child_process');
    commit = execSync('git rev-parse --short HEAD').toString().trim();
    branch = execSync('git rev-parse --abbrev-ref HEAD').toString().trim();
  } catch (_) {}
  return { commit, branch };
}

  // Health check endpoint with build, environment, branch, and Git commit versioning
  server.get('/health', async () => {
    const gitInfo = getGitCommitInfo();
    return {
      status: 'healthy',
      environment: process.env.NODE_ENV || 'production',
      service: 'ride-matching-backend',
      containerImage: 'ride-matching-backend:1.1.0-ops-dashboard',
      version: '1.1.0-ops-dashboard',
      apiVersion: 'v1',
      gitCommit: gitInfo.commit,
      branch: gitInfo.branch,
      buildTime: '2026-07-28T16:10:00Z',
      timestamp: new Date().toISOString(),
    };
  });

  // System endpoint to query active rider locations for simulation script
  server.get('/api/system/rider-locations', async (request, reply) => {
    const locations: any[] = [];
    for (const [riderId, sub] of activeRiderSubscriptions.entries()) {
      locations.push({
        riderId,
        lat: sub.lat,
        lng: sub.lng,
      });
    }
    return locations;
  });

  // Register REST routes
  await server.register(authRoutes);
  await server.register(tripRoutes);
  await server.register((await import('./modules/kyc')).kycRoutes);
  await server.register((await import('./modules/user_api')).userApiRoutes);
  await server.register((await import('./modules/driver_api')).driverApiRoutes);
  await server.register((await import('./modules/admin_ops_routes')).adminOpsRoutes);

  // Register Ride Tracking WebSocket handler
  server.route({
    method: 'GET',
    url: '/ride-tracking',
    preValidation: [verifyJwtMiddleware],
    handler: async (req, reply) => {
      // Return 400 if client requests HTTP on WebSocket route
      reply.code(400).send({ error: 'WebSocket connection expected' });
    },
    wsHandler: handleWebSocketConnection,
  });

  return server;
}
