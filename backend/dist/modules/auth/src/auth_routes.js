"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authRoutes = authRoutes;
const zod_1 = require("zod");
const auth_service_1 = require("./auth_service");
const logger_1 = require("../../../shared/logger");
const errors_1 = require("../../../shared/errors");
const prisma_1 = require("../../../shared/prisma");
const auth_middleware_1 = require("./auth_middleware");
const config_1 = require("../../../shared/config");
const requestOtpSchema = zod_1.z.object({
    phone: zod_1.z.string().min(10).max(15),
});
const verifyOtpSchema = zod_1.z.object({
    phone: zod_1.z.string().min(10).max(15),
    code: zod_1.z.string().length(4), // client app uses OTP: "4820"
    role: zod_1.z.enum(['RIDER', 'DRIVER']),
});
const loginSchema = zod_1.z.object({
    username: zod_1.z.string().min(1, 'Username is required'),
    password: zod_1.z.string().min(1, 'Password is required'),
});
async function authRoutes(server) {
    // Admin login endpoint (username/password)
    server.post('/api/auth/login', async (request, reply) => {
        try {
            const parsed = loginSchema.safeParse(request.body);
            if (!parsed.success) {
                throw new errors_1.BadRequestError('Invalid login credentials format');
            }
            const { username, password } = parsed.data;
            // Validate against environment variables or defaults
            const adminUsername = config_1.config.ADMIN_USERNAME;
            const adminPassword = config_1.config.ADMIN_PASSWORD;
            if (username !== adminUsername || password !== adminPassword) {
                throw new errors_1.UnauthorizedError('Invalid credentials. Please check and try again.');
            }
            // Find or create admin user in the database
            let adminUser = await prisma_1.prisma.user.findFirst({
                where: { role: 'ADMIN' },
            });
            if (!adminUser) {
                adminUser = await prisma_1.prisma.user.create({
                    data: {
                        phone: '0000000000',
                        name: 'Admin',
                        email: 'admin@urbanpulse.com',
                        role: 'ADMIN',
                    },
                });
            }
            const payload = {
                userId: adminUser.id,
                phone: adminUser.phone,
                role: 'ADMIN',
                name: adminUser.name || 'Admin',
            };
            const token = auth_service_1.AuthService.generateToken(payload);
            logger_1.logger.info({ userId: adminUser.id }, 'Admin user logged in successfully');
            return reply.code(200).send({
                status: 'success',
                token,
                user: payload,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Admin login error');
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
    }, async (request, reply) => {
        try {
            const parsed = requestOtpSchema.safeParse(request.body);
            if (!parsed.success) {
                throw new errors_1.BadRequestError('Invalid phone number format');
            }
            const { phone } = parsed.data;
            const otp = await auth_service_1.AuthService.requestOtp(phone);
            logger_1.logger.info({ phone }, 'OTP generated and sent');
            return reply.code(200).send({
                status: 'success',
                message: 'OTP sent successfully',
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error requesting OTP');
            if (err.statusCode) {
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/auth/otp/verify', async (request, reply) => {
        try {
            const parsed = verifyOtpSchema.safeParse(request.body);
            if (!parsed.success) {
                logger_1.logger.warn({ errors: parsed.error.format() }, 'Validation failed for OTP verify request');
                throw new errors_1.BadRequestError('Invalid OTP verification parameters');
            }
            const { phone, code, role } = parsed.data;
            const result = await auth_service_1.AuthService.verifyOtp(phone, code, role);
            logger_1.logger.info({ phone, role, userId: result.user.userId }, 'User successfully verified OTP');
            return reply.code(200).send({
                status: 'success',
                ...result,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error verifying OTP');
            if (err.statusCode) {
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    const fcmTokenSchema = zod_1.z.object({
        fcmToken: zod_1.z.string(),
        deviceId: zod_1.z.string(),
        platform: zod_1.z.string().optional(),
        appVersion: zod_1.z.string().optional(),
    });
    server.post('/api/auth/fcm-token', {
        preHandler: [auth_middleware_1.verifyJwtMiddleware]
    }, async (request, reply) => {
        try {
            const parsed = fcmTokenSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
            }
            const { fcmToken, deviceId, platform, appVersion } = parsed.data;
            const user = request.user;
            const device = await prisma_1.prisma.userDevice.upsert({
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
        }
        catch (err) {
            logger_1.logger.error(err, 'Error updating FCM token');
            return reply.code(500).send({ error: err.message });
        }
    });
}
