"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.initializeWorkers = initializeWorkers;
const logger_1 = require("../shared/logger");
require("./trip_workers");
function initializeWorkers() {
    logger_1.logger.info('BullMQ workers successfully initialized and listening for jobs.');
}
