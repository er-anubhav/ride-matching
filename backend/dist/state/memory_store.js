"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.memoryStore = void 0;
const logger_1 = require("../shared/logger");
class MemoryStore {
    // Map of userId/driverId -> WS Socket on this specific Node.js instance
    localSockets = new Map();
    constructor() {
        logger_1.logger.info('MemoryStore singleton initialized.');
    }
    getSocket(id) {
        return this.localSockets.get(id);
    }
    setSocket(id, socket) {
        this.localSockets.set(id, socket);
        logger_1.logger.debug(`Socket registered for ID: ${id}`);
    }
    removeSocket(id) {
        this.localSockets.delete(id);
        logger_1.logger.debug(`Socket removed for ID: ${id}`);
    }
}
exports.memoryStore = new MemoryStore();
exports.default = exports.memoryStore;
