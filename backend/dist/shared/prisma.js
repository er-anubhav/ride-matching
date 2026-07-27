"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.prisma = void 0;
const client_1 = require("@prisma/client");
const logger_1 = require("./logger");
const config_1 = require("./config");
if (!config_1.config.DATABASE_URL) {
    throw new Error('DATABASE_URL environment variable is required. ' +
        'Set it before starting the server. ' +
        'Example: postgresql://user:password@localhost:5432/dbname');
}
const prisma = new client_1.PrismaClient({
    datasources: {
        db: {
            url: config_1.config.DATABASE_URL,
        },
    },
});
exports.prisma = prisma;
// Verify connectivity at startup — server won't accept requests if this fails
prisma.$connect()
    .then(() => logger_1.logger.info('PostgreSQL connected successfully'))
    .catch((err) => {
    logger_1.logger.error({ err }, 'Failed to connect to PostgreSQL. Server shutting down.');
    process.exit(1);
});
exports.default = prisma;
