"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.eventBus = void 0;
const eventemitter2_1 = require("eventemitter2");
const logger_1 = require("./logger");
exports.eventBus = new eventemitter2_1.EventEmitter2({
    wildcard: true,
    delimiter: '.',
    maxListeners: 20,
    verboseMemoryLeak: true,
});
// Setup global logging listener for all events in development
exports.eventBus.on('*.*', (event, payload) => {
    logger_1.logger.debug({ event, payload }, 'Event emitted');
});
exports.default = exports.eventBus;
