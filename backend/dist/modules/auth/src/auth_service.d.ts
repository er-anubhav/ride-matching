export interface UserPayload {
    userId: string;
    phone: string;
    role: 'RIDER' | 'DRIVER' | 'ADMIN';
    name: string;
}
export declare class AuthService {
    static generateToken(payload: UserPayload): string;
    static verifyToken(token: string): UserPayload;
    static requestOtp(phone: string): Promise<string>;
    static verifyOtp(phone: string, otp: string, role: 'RIDER' | 'DRIVER'): Promise<{
        token: string;
        user: UserPayload;
    }>;
}
