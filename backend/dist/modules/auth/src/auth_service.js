"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const crypto_1 = __importDefault(require("crypto"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const config_1 = require("../../../shared/config");
const errors_1 = require("../../../shared/errors");
const prisma_1 = require("../../../shared/prisma");
const sms_service_1 = require("./sms_service");
class AuthService {
    static generateToken(payload) {
        return jsonwebtoken_1.default.sign(payload, config_1.config.JWT_SECRET, { expiresIn: '7d' });
    }
    static verifyToken(token) {
        try {
            return jsonwebtoken_1.default.verify(token, config_1.config.JWT_SECRET);
        }
        catch (e) {
            throw new errors_1.UnauthorizedError('Invalid or expired authentication token');
        }
    }
    static async requestOtp(phone) {
        // 1. Check for rate limit
        const oneMinuteAgo = new Date(Date.now() - 60000);
        const recentOtp = await prisma_1.prisma.otpCode.findFirst({
            where: {
                phone,
                createdAt: { gte: oneMinuteAgo },
            },
        });
        if (recentOtp) {
            throw new errors_1.TooManyRequestsError('Please wait before requesting another OTP');
        }
        // 2. Generate random 4-digit OTP
        const otp = Math.floor(1000 + Math.random() * 9000).toString();
        // 3. Hash OTP
        const codeHash = crypto_1.default.createHash('sha256').update(otp).digest('hex');
        // 4. Store in DB
        const expiresAt = new Date(Date.now() + 5 * 60000); // 5 minutes expiration
        await prisma_1.prisma.otpCode.create({
            data: {
                phone,
                codeHash,
                expiresAt,
            },
        });
        // 5. Send via Fast2SMS
        await sms_service_1.SmsService.sendOtp(phone, otp);
        return otp;
    }
    static async verifyOtp(phone, otp, role) {
        // Master test OTP bypass for testing (code 1234, 123456, 0000 or 4820)
        const isTestOtp = otp === '1234' || otp === '123456' || otp === '0000' || otp === '4820';
        if (!isTestOtp) {
            const codeHash = crypto_1.default.createHash('sha256').update(otp).digest('hex');
            // Find the latest valid OTP
            const otpRecord = await prisma_1.prisma.otpCode.findFirst({
                where: {
                    phone,
                    codeHash,
                    usedAt: null,
                    expiresAt: { gt: new Date() },
                },
                orderBy: { createdAt: 'desc' },
            });
            if (!otpRecord) {
                throw new errors_1.UnauthorizedError('Invalid or expired OTP code provided');
            }
            // Mark as used
            await prisma_1.prisma.otpCode.update({
                where: { id: otpRecord.id },
                data: { usedAt: new Date() },
            });
        }
        let user = await prisma_1.prisma.user.findUnique({ where: { phone } });
        if (!user) {
            user = await prisma_1.prisma.user.create({
                data: {
                    phone,
                    name: role === 'DRIVER' ? 'Test Driver' : 'Test Rider',
                    role: role,
                },
            });
        }
        // Auto-approve DriverProfile for DRIVER role so driver can instantly go online
        if (role === 'DRIVER') {
            await prisma_1.prisma.driverProfile.upsert({
                where: { driverId: user.id },
                update: { kycStatus: 'APPROVED' },
                create: {
                    driverId: user.id,
                    vehicleType: 'Sedan',
                    vehicleMake: 'Tata',
                    vehicleModel: 'Tigor EV',
                    licencePlate: 'DL01TEST99',
                    kycStatus: 'APPROVED',
                },
            });
        }
        const payload = {
            userId: user.id,
            phone: user.phone,
            role: user.role,
            name: user.name || (role === 'DRIVER' ? 'New Driver' : 'New Rider'),
        };
        const token = this.generateToken(payload);
        return {
            token,
            user: payload,
        };
    }
}
exports.AuthService = AuthService;
