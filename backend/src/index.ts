import { createServer } from './server';
import { config } from './shared/config';
import { logger } from './shared/logger';
import { initializeWorkers } from './workers';

async function bootstrap() {
  try {
    logger.info('Starting UrbanPulse Backend Modular Monolith...');
    initializeWorkers();
    const server = await createServer();

    const address = await server.listen({
      port: config.PORT,
      host: config.HOST,
    });

    logger.info(`Server successfully listening on: ${address}`);
    logger.info(`WebSocket endpoint active at: ws://${config.HOST}:${config.PORT}/ride-tracking`);
  } catch (err) {
    logger.fatal(err, 'Failed to bootstrap UrbanPulse Backend server');
    process.exit(1);
  }
}

// Handle termination signals for clean shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received. Shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received. Shutting down gracefully...');
  process.exit(0);
});

bootstrap();
