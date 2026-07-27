export declare class SmsService {
    /**
     * Sends an OTP via Fast2SMS using the provided phone number and OTP code.
     * If USE_MOCK_OTP is enabled or FAST2SMS_API_KEY is missing, it will bypass sending and log the OTP.
     */
    static sendOtp(phone: string, otp: string): Promise<boolean>;
}
