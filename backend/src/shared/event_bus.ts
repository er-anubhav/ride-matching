import { EventEmitter2 } from 'eventemitter2';
import { logger } from './logger';

export const eventBus = new EventEmitter2({
  wildcard: true,
  delimiter: '.',
  maxListeners: 20,
  verboseMemoryLeak: true,
});

// Setup global logging listener for all events in development
eventBus.on('*.*', (event, payload) => {
  logger.debug({ event, payload }, 'Event emitted');
});
export default eventBus;
