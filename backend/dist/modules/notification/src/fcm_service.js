"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.FcmService = void 0;
const app_1 = require("firebase-admin/app");
const messaging_1 = require("firebase-admin/messaging");
const config_1 = require("../../../shared/config");
const logger_1 = require("../../../shared/logger");
const prisma_1 = require("../../../shared/prisma");
let isInitialized = false;
if (config_1.config.FIREBASE_PROJECT_ID &&
    config_1.config.FIREBASE_CLIENT_EMAIL &&
    config_1.config.FIREBASE_PRIVATE_KEY) {
    try {
        (0, app_1.initializeApp)({
            credential: (0, app_1.cert)({
                projectId: config_1.config.FIREBASE_PROJECT_ID,
                clientEmail: config_1.config.FIREBASE_CLIENT_EMAIL,
                // Replace literal \n with actual newlines if passed in ENV
                privateKey: config_1.config.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
            }),
        });
        isInitialized = true;
        logger_1.logger.info('Firebase Admin initialized successfully.');
    }
    catch (err) {
        logger_1.logger.error(err, 'Failed to initialize Firebase Admin');
    }
}
else {
    logger_1.logger.warn('Firebase Admin credentials missing. Push notifications are disabled.');
}
class FcmService {
    /**
     * Sends a push notification to all active devices of a user.
     */
    static async sendPushNotification(userId, title, body, data) {
        if (!isInitialized)
            return;
        try {
            const devices = await prisma_1.prisma.userDevice.findMany({
                where: { userId, isActive: true },
            });
            if (devices.length === 0)
                return;
            const tokens = devices.map((d) => d.fcmToken);
            const message = {
                tokens,
                notification: {
                    title,
                    body,
                },
                data: data || {},
            };
            const response = await (0, messaging_1.getMessaging)().sendEachForMulticast(message);
            // Cleanup stale tokens
            const staleTokenIds = [];
            response.responses.forEach((res, idx) => {
                if (!res.success) {
                    const error = res.error?.code;
                    if (error === 'messaging/invalid-registration-token' ||
                        error === 'messaging/registration-token-not-registered') {
                        staleTokenIds.push(devices[idx].id);
                    }
                }
            });
            if (staleTokenIds.length > 0) {
                await prisma_1.prisma.userDevice.updateMany({
                    where: { id: { in: staleTokenIds } },
                    data: { isActive: false },
                });
                logger_1.logger.info(`Cleaned up ${staleTokenIds.length} stale FCM tokens for user ${userId}`);
            }
        }
        catch (err) {
            logger_1.logger.error({ err, userId }, 'Failed to send FCM push notification');
        }
    }
}
exports.FcmService = FcmService;
