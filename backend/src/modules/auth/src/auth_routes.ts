import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { AuthService } from './auth_service';
import { logger } from '../../../shared/logger';
import { BadRequestError, UnauthorizedError } from '../../../shared/errors';
import { prisma } from '../../../shared/prisma';
import { verifyJwtMiddleware } from './auth_middleware';
import { config } from '../../../shared/config';

const requestOtpSchema = z.object({
  phone: z.string().min(10).max(15),
});

const verifyOtpSchema = z.object({
  phone: z.string().min(10).max(15),
  code: z.string().length(4), // client app uses OTP: "4820"
  role: z.enum(['RIDER', 'DRIVER']),
});

const loginSchema = z.object({
  username: z.string().min(1, 'Username is required'),
  password: z.string().min(1, 'Password is required'),
});

export async function authRoutes(server: FastifyInstance) {
  // Admin login endpoint (username/password)
  server.post('/api/auth/login', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const parsed = loginSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new BadRequestError('Invalid login credentials format');
      }

      const { username, password } = parsed.data;

      // Validate against environment variables or defaults
      const adminUsername = config.ADMIN_USERNAME;
      const adminPassword = config.ADMIN_PASSWORD;

      if (username !== adminUsername || password !== adminPassword) {
        throw new UnauthorizedError('Invalid credentials. Please check and try again.');
      }

      // Find or create admin user in the database
      let adminUser = await prisma.user.findFirst({
        where: { role: 'ADMIN' },
      });

      if (!adminUser) {
        adminUser = await prisma.user.create({
          data: {
            phone: '0000000000',
            name: 'Admin',
            email: 'admin@mrrideo.com',
            role: 'ADMIN',
          },
        });
      }

      const payload = {
        userId: adminUser.id,
        phone: adminUser.phone,
        role: 'ADMIN' as const,
        name: adminUser.name || 'Admin',
      };

      const token = AuthService.generateToken(payload);

      logger.info({ userId: adminUser.id }, 'Admin user logged in successfully');
      return reply.code(200).send({
        status: 'success',
        token,
        user: payload,
      });
    } catch (err: any) {
      logger.error(err, 'Admin login error');
      if (err.statusCode) {
        return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/auth/otp/request', {
    config: {
      rateLimit: {
        max: 3,
        timeWindow: '5 minutes',
      }
    }
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const parsed = requestOtpSchema.safeParse(request.body);
      if (!parsed.success) {
        throw new BadRequestError('Invalid phone number format');
      }

      const { phone } = parsed.data;
      const otp = await AuthService.requestOtp(phone);

      logger.info({ phone }, 'OTP generated and sent');
      return reply.code(200).send({
        status: 'success',
        message: 'OTP sent successfully',
      });
    } catch (err: any) {
      logger.error(err, 'Error requesting OTP');
      if (err.statusCode) {
        return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/auth/otp/verify', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const parsed = verifyOtpSchema.safeParse(request.body);
      if (!parsed.success) {
        logger.warn({ errors: parsed.error.format() }, 'Validation failed for OTP verify request');
        throw new BadRequestError('Invalid OTP verification parameters');
      }

      const { phone, code, role } = parsed.data;
      const result = await AuthService.verifyOtp(phone, code, role);

      logger.info({ phone, role, userId: result.user.userId }, 'User successfully verified OTP');
      return reply.code(200).send({
        status: 'success',
        ...result,
      });
    } catch (err: any) {
      logger.error(err, 'Error verifying OTP');
      if (err.statusCode) {
        return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  const fcmTokenSchema = z.object({
    fcmToken: z.string(),
    deviceId: z.string(),
    platform: z.string().optional(),
    appVersion: z.string().optional(),
  });

  server.post('/api/auth/fcm-token', {
    preHandler: [verifyJwtMiddleware]
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const parsed = fcmTokenSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
      }

      const { fcmToken, deviceId, platform, appVersion } = parsed.data;
      const user = (request as any).user;

      const device = await prisma.userDevice.upsert({
        where: {
          userId_deviceId: {
            userId: user.userId,
            deviceId,
          },
        },
        update: {
          fcmToken,
          platform,
          appVersion,
          lastSeenAt: new Date(),
          isActive: true,
        },
        create: {
          userId: user.userId,
          deviceId,
          fcmToken,
          platform,
          appVersion,
          isActive: true,
        },
      });

      return reply.code(200).send({
        status: 'success',
        device: {
          id: device.id,
          deviceId: device.deviceId,
          isActive: device.isActive,
        },
      });
    } catch (err: any) {
      logger.error(err, 'Error updating FCM token');
      return reply.code(500).send({ error: err.message });
    }
  });
}
