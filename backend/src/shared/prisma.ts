import { PrismaClient } from '@prisma/client';
import { logger } from './logger';
import { config } from './config';

if (!config.DATABASE_URL) {
  throw new Error(
    'DATABASE_URL environment variable is required. ' +
    'Set it before starting the server. ' +
    'Example: postgresql://user:password@localhost:5432/dbname'
  );
}

const prisma = new PrismaClient({
  datasources: {
    db: {
      url: config.DATABASE_URL,
    },
  },
});

// Verify connectivity at startup — server won't accept requests if this fails
prisma.$connect()
  .then(() => logger.info('PostgreSQL connected successfully'))
  .catch((err) => {
    logger.error({ err }, 'Failed to connect to PostgreSQL. Server shutting down.');
    process.exit(1);
  });

export { prisma };
export default prisma;
