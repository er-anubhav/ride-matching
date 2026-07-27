"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.R2Service = void 0;
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const config_1 = require("../../../shared/config");
let s3Client = null;
if (config_1.config.CLOUDFLARE_R2_ACCOUNT_ID &&
    config_1.config.CLOUDFLARE_R2_ACCESS_KEY_ID &&
    config_1.config.CLOUDFLARE_R2_SECRET_ACCESS_KEY) {
    s3Client = new client_s3_1.S3Client({
        region: 'auto',
        endpoint: `https://${config_1.config.CLOUDFLARE_R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
        credentials: {
            accessKeyId: config_1.config.CLOUDFLARE_R2_ACCESS_KEY_ID,
            secretAccessKey: config_1.config.CLOUDFLARE_R2_SECRET_ACCESS_KEY,
        },
    });
}
class R2Service {
    /**
     * Generates a pre-signed URL for the mobile app to directly PUT a file to Cloudflare R2.
     * @param objectKey The target S3 key (e.g. 'drivers/UUID/dl_front.jpg')
     * @param contentType The MIME type of the file (e.g. 'image/jpeg')
     * @param expiresInSeconds URL validity duration (default: 5 minutes)
     */
    static async generatePresignedUploadUrl(objectKey, contentType, expiresInSeconds = 300) {
        if (!s3Client || !config_1.config.CLOUDFLARE_R2_BUCKET_NAME) {
            throw new Error('Cloudflare R2 is not configured on the backend.');
        }
        const command = new client_s3_1.PutObjectCommand({
            Bucket: config_1.config.CLOUDFLARE_R2_BUCKET_NAME,
            Key: objectKey,
            ContentType: contentType,
        });
        return (0, s3_request_presigner_1.getSignedUrl)(s3Client, command, { expiresIn: expiresInSeconds });
    }
}
exports.R2Service = R2Service;
