export declare class PubSubService {
    private static readonly WS_CHANNEL;
    static initialize(): void;
    static publishToUser(targetId: string, payload: any): Promise<void>;
}
