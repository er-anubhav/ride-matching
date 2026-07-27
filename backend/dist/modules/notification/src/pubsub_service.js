"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PubSubService = void 0;
const redis_1 = require("../../../shared/redis");
const logger_1 = require("../../../shared/logger");
const memory_store_1 = require("../../../state/memory_store");
class PubSubService {
    static WS_CHANNEL = 'ws:messages';
    static initialize() {
        redis_1.subClient.subscribe(this.WS_CHANNEL, (err, count) => {
            if (err) {
                logger_1.logger.error({ err }, 'Failed to subscribe to Redis PubSub channel');
            }
            else {
                logger_1.logger.info(`Subscribed to Redis PubSub channel. Count: ${count}`);
            }
        });
        redis_1.subClient.on('message', (channel, message) => {
            if (channel === this.WS_CHANNEL) {
                try {
                    const { targetId, payload } = JSON.parse(message);
                    const socket = memory_store_1.memoryStore.getSocket(targetId);
                    if (socket && socket.readyState === 1) {
                        socket.send(JSON.stringify(payload));
                    }
                }
                catch (e) {
                    logger_1.logger.error({ err: e, message }, 'Error processing PubSub message');
                }
            }
        });
    }
    static async publishToUser(targetId, payload) {
        try {
            const message = JSON.stringify({ targetId, payload });
            await redis_1.pubClient.publish(this.WS_CHANNEL, message);
        }
        catch (e) {
            logger_1.logger.error({ err: e, targetId }, 'Failed to publish message via Redis');
        }
    }
}
exports.PubSubService = PubSubService;
