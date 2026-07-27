import { pubClient, subClient } from '../../../shared/redis';
import { logger } from '../../../shared/logger';
import { memoryStore } from '../../../state/memory_store';

export class PubSubService {
  private static readonly WS_CHANNEL = 'ws:messages';

  public static initialize() {
    subClient.subscribe(this.WS_CHANNEL, (err, count) => {
      if (err) {
        logger.error({ err }, 'Failed to subscribe to Redis PubSub channel');
      } else {
        logger.info(`Subscribed to Redis PubSub channel. Count: ${count}`);
      }
    });

    subClient.on('message', (channel, message) => {
      if (channel === this.WS_CHANNEL) {
        try {
          const { targetId, payload } = JSON.parse(message);
          const socket = memoryStore.getSocket(targetId);
          if (socket && socket.readyState === 1) {
            socket.send(JSON.stringify(payload));
          }
        } catch (e) {
          logger.error({ err: e, message }, 'Error processing PubSub message');
        }
      }
    });
  }

  public static async publishToUser(targetId: string, payload: any) {
    try {
      const message = JSON.stringify({ targetId, payload });
      await pubClient.publish(this.WS_CHANNEL, message);
    } catch (e) {
      logger.error({ err: e, targetId }, 'Failed to publish message via Redis');
    }
  }
}
