import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { config } from '../../../shared/config';
import { UnauthorizedError, TooManyRequestsError, BadRequestError } from '../../../shared/errors';
import { prisma } from '../../../shared/prisma';
import { SmsService } from './sms_service';

export interface UserPayload {
  userId: string;
  phone: string;
  role: 'RIDER' | 'DRIVER' | 'ADMIN';
  name: string;
}

export class AuthService {
  public static generateToken(payload: UserPayload): string {
    return jwt.sign(payload, config.JWT_SECRET, { expiresIn: '7d' });
  }

  public static verifyToken(token: string): UserPayload {
    try {
      return jwt.verify(token, config.JWT_SECRET) as UserPayload;
    } catch (e) {
      throw new UnauthorizedError('Invalid or expired authentication token');
    }
  }

  public static async requestOtp(phone: string): Promise<string> {
    // 1. Check for rate limit
    const oneMinuteAgo = new Date(Date.now() - 60000);
    const recentOtp = await prisma.otpCode.findFirst({
      where: {
        phone,
        createdAt: { gte: oneMinuteAgo },
      },
    });

    if (recentOtp) {
      throw new TooManyRequestsError('Please wait before requesting another OTP');
    }

    // 2. Generate random 4-digit OTP
    const otp = Math.floor(1000 + Math.random() * 9000).toString();


    // 3. Hash OTP
    const codeHash = crypto.createHash('sha256').update(otp).digest('hex');

    // 4. Store in DB
    const expiresAt = new Date(Date.now() + 5 * 60000); // 5 minutes expiration
    await prisma.otpCode.create({
      data: {
        phone,
        codeHash,
        expiresAt,
      },
    });

    // 5. Send via Fast2SMS
    await SmsService.sendOtp(phone, otp);

    return otp;
  }

  public static async verifyOtp(phone: string, otp: string, role: 'RIDER' | 'DRIVER'): Promise<{ token: string; user: UserPayload }> {
    const codeHash = crypto.createHash('sha256').update(otp).digest('hex');

    // Find the latest valid OTP
    const otpRecord = await prisma.otpCode.findFirst({
      where: {
        phone,
        codeHash,
        usedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });

    if (!otpRecord) {
      throw new UnauthorizedError('Invalid or expired OTP code provided');
    }

    // Mark as used
    await prisma.otpCode.update({
      where: { id: otpRecord.id },
      data: { usedAt: new Date() },
    });

    let user = await prisma.user.findUnique({ where: { phone } });
    if (!user) {
      user = await prisma.user.create({
        data: {
          phone,
          name: role === 'DRIVER' ? 'New Driver' : 'New Rider',
          role: role,
        },
      });
    }

    const payload: UserPayload = {
      userId: user.id,
      phone: user.phone,
      role: user.role as 'RIDER' | 'DRIVER' | 'ADMIN',
      name: user.name || (role === 'DRIVER' ? 'New Driver' : 'New Rider'),
    };

    const token = this.generateToken(payload);

    return {
      token,
      user: payload,
    };
  }
}
