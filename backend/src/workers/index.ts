import { logger } from '../shared/logger';
import './trip_workers';

export function initializeWorkers() {
  logger.info('BullMQ workers successfully initialized and listening for jobs.');
}
