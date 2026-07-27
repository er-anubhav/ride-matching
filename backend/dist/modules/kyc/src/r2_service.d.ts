export declare class R2Service {
    /**
     * Generates a pre-signed URL for the mobile app to directly PUT a file to Cloudflare R2.
     * @param objectKey The target S3 key (e.g. 'drivers/UUID/dl_front.jpg')
     * @param contentType The MIME type of the file (e.g. 'image/jpeg')
     * @param expiresInSeconds URL validity duration (default: 5 minutes)
     */
    static generatePresignedUploadUrl(objectKey: string, contentType: string, expiresInSeconds?: number): Promise<string>;
}
