import { config } from '../../../shared/config';
import { logger } from '../../../shared/logger';

export class SmsService {
  /**
   * Sends an OTP via Fast2SMS using the provided phone number and OTP code.
   * If USE_MOCK_OTP is enabled or FAST2SMS_API_KEY is missing, it will bypass sending and log the OTP.
   */
  public static async sendOtp(phone: string, otp: string): Promise<boolean> {
    if (!config.FAST2SMS_API_KEY) {
      logger.error({ phone }, 'FAST2SMS_API_KEY is not configured in environment variables');
      return false;
    }


    try {
      // Fast2SMS API integration
      const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
        method: 'POST',
        headers: {
          'authorization': config.FAST2SMS_API_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          route: 'q',
          message: `Your UrbanPulse verification code is: ${otp}`,
          flash: 0,
          numbers: phone.replace('+', '') // Fast2SMS expects numbers without '+'
        })
      });

      const data = await response.json();
      if (!response.ok || !data.return) {
        logger.error({ phone, response: data }, 'Fast2SMS failed to send OTP');
        return false;
      }

      logger.info({ phone }, 'OTP SMS sent successfully');
      return true;
    } catch (error) {
      logger.error({ err: error, phone }, 'Exception while sending OTP SMS');
      return false;
    }
  }
}
