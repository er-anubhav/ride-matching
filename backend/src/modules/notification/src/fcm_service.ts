import { initializeApp, cert } from 'firebase-admin/app';
import { getMessaging, MulticastMessage } from 'firebase-admin/messaging';
import { config } from '../../../shared/config';
import { logger } from '../../../shared/logger';
import { prisma } from '../../../shared/prisma';

let isInitialized = false;

if (
  config.FIREBASE_PROJECT_ID &&
  config.FIREBASE_CLIENT_EMAIL &&
  config.FIREBASE_PRIVATE_KEY
) {
  try {
    initializeApp({
      credential: cert({
        projectId: config.FIREBASE_PROJECT_ID,
        clientEmail: config.FIREBASE_CLIENT_EMAIL,
        // Replace literal \n with actual newlines if passed in ENV
        privateKey: config.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
      }),
    });
    isInitialized = true;
    logger.info('Firebase Admin initialized successfully.');
  } catch (err: any) {
    logger.error(err, 'Failed to initialize Firebase Admin');
  }
} else {
  logger.warn('Firebase Admin credentials missing. Push notifications are disabled.');
}

export class FcmService {
  /**
   * Sends a push notification to all active devices of a user.
   */
  public static async sendPushNotification(
    userId: string,
    title: string,
    body: string,
    data?: Record<string, string>
  ): Promise<void> {
    if (!isInitialized) return;

    try {
      const devices = await prisma.userDevice.findMany({
        where: { userId, isActive: true },
      });

      if (devices.length === 0) return;

      const tokens = devices.map((d: any) => d.fcmToken);

      const message: MulticastMessage = {
        tokens,
        notification: {
          title,
          body,
        },
        data: data || {},
      };

      const response = await getMessaging().sendEachForMulticast(message);
      
      // Cleanup stale tokens
      const staleTokenIds: string[] = [];
      response.responses.forEach((res: any, idx: number) => {
        if (!res.success) {
          const error = res.error?.code;
          if (
            error === 'messaging/invalid-registration-token' ||
            error === 'messaging/registration-token-not-registered'
          ) {
            staleTokenIds.push(devices[idx].id);
          }
        }
      });

      if (staleTokenIds.length > 0) {
        await prisma.userDevice.updateMany({
          where: { id: { in: staleTokenIds } },
          data: { isActive: false },
        });
        logger.info(`Cleaned up ${staleTokenIds.length} stale FCM tokens for user ${userId}`);
      }

    } catch (err: any) {
      logger.error({ err, userId }, 'Failed to send FCM push notification');
    }
  }
}
