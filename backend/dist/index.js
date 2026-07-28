"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const server_1 = require("./server");
const config_1 = require("./shared/config");
const logger_1 = require("./shared/logger");
const workers_1 = require("./workers");
async function bootstrap() {
    try {
        logger_1.logger.info('Starting Ride Matching Backend Modular Monolith...');
        (0, workers_1.initializeWorkers)();
        const server = await (0, server_1.createServer)();
        const address = await server.listen({
            port: config_1.config.PORT,
            host: config_1.config.HOST,
        });
        logger_1.logger.info(`Server successfully listening on: ${address}`);
        logger_1.logger.info(`WebSocket endpoint active at: ws://${config_1.config.HOST}:${config_1.config.PORT}/ride-tracking`);
    }
    catch (err) {
        logger_1.logger.fatal(err, 'Failed to bootstrap Ride Matching Backend server');
        process.exit(1);
    }
}
// Handle termination signals for clean shutdown
process.on('SIGTERM', () => {
    logger_1.logger.info('SIGTERM received. Shutting down gracefully...');
    process.exit(0);
});
process.on('SIGINT', () => {
    logger_1.logger.info('SIGINT received. Shutting down gracefully...');
    process.exit(0);
});
bootstrap();
