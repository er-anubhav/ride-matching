export declare class FcmService {
    /**
     * Sends a push notification to all active devices of a user.
     */
    static sendPushNotification(userId: string, title: string, body: string, data?: Record<string, string>): Promise<void>;
}
