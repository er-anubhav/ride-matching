import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { config } from '../../../shared/config';

let s3Client: S3Client | null = null;

if (
  config.CLOUDFLARE_R2_ACCOUNT_ID &&
  config.CLOUDFLARE_R2_ACCESS_KEY_ID &&
  config.CLOUDFLARE_R2_SECRET_ACCESS_KEY
) {
  s3Client = new S3Client({
    region: 'auto',
    endpoint: `https://${config.CLOUDFLARE_R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
      accessKeyId: config.CLOUDFLARE_R2_ACCESS_KEY_ID,
      secretAccessKey: config.CLOUDFLARE_R2_SECRET_ACCESS_KEY,
    },
  });
}

export class R2Service {
  /**
   * Generates a pre-signed URL for the mobile app to directly PUT a file to Cloudflare R2.
   * @param objectKey The target S3 key (e.g. 'drivers/UUID/dl_front.jpg')
   * @param contentType The MIME type of the file (e.g. 'image/jpeg')
   * @param expiresInSeconds URL validity duration (default: 5 minutes)
   */
  public static async generatePresignedUploadUrl(
    objectKey: string,
    contentType: string,
    expiresInSeconds: number = 300
  ): Promise<string> {
    if (!s3Client || !config.CLOUDFLARE_R2_BUCKET_NAME) {
      throw new Error('Cloudflare R2 is not configured on the backend.');
    }

    const command = new PutObjectCommand({
      Bucket: config.CLOUDFLARE_R2_BUCKET_NAME,
      Key: objectKey,
      ContentType: contentType,
    });

    return getSignedUrl(s3Client, command, { expiresIn: expiresInSeconds });
  }
}
