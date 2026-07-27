"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.kycRoutes = kycRoutes;
const zod_1 = require("zod");
const auth_1 = require("../../auth");
const logger_1 = require("../../../shared/logger");
const prisma_1 = require("../../../shared/prisma");
const r2_service_1 = require("./r2_service");
const kyc_service_1 = require("./kyc_service");
const uploadUrlSchema = zod_1.z.object({
    docType: zod_1.z.enum(['AADHAAR_FRONT', 'AADHAAR_BACK', 'SELFIE', 'DL', 'RC', 'INSURANCE', 'VEHICLE_PHOTO']),
    contentType: zod_1.z.string(),
    fileExtension: zod_1.z.string(),
});
const adminApproveSchema = zod_1.z.object({
    reason: zod_1.z.string().optional(),
});
const adminRejectSchema = zod_1.z.object({
    reason: zod_1.z.string(),
});
async function kycRoutes(server) {
    server.addHook('preHandler', auth_1.verifyJwtMiddleware);
    // Driver endpoints
    server.post('/api/kyc/upload-url', async (request, reply) => {
        try {
            const user = request.user;
            if (user.role !== 'DRIVER') {
                return reply.code(403).send({ error: 'Only drivers can upload KYC documents.' });
            }
            const parsed = uploadUrlSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
            }
            const { docType, contentType, fileExtension } = parsed.data;
            // Ensure no dot in extension
            const ext = fileExtension.replace(/^\./, '');
            const objectKey = `drivers/${user.userId}/${docType.toLowerCase()}_${Date.now()}.${ext}`;
            const uploadUrl = await r2_service_1.R2Service.generatePresignedUploadUrl(objectKey, contentType);
            // Create a pending document record
            const document = await prisma_1.prisma.document.create({
                data: {
                    driverId: user.userId,
                    docType,
                    s3Key: objectKey,
                    verificationStatus: 'PENDING',
                },
            });
            return reply.code(200).send({
                status: 'success',
                uploadUrl,
                documentId: document.id,
                objectKey,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error generating KYC upload URL');
            return reply.code(500).send({ error: err.message });
        }
    });
    server.get('/api/kyc/documents', async (request, reply) => {
        try {
            const user = request.user;
            if (user.role !== 'DRIVER') {
                return reply.code(403).send({ error: 'Only drivers can view KYC documents.' });
            }
            const documents = await prisma_1.prisma.document.findMany({
                where: { driverId: user.userId },
                orderBy: { createdAt: 'desc' },
            });
            return reply.code(200).send({
                status: 'success',
                documents,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error fetching KYC documents');
            return reply.code(500).send({ error: err.message });
        }
    });
    server.get('/api/kyc/status', async (request, reply) => {
        try {
            const user = request.user;
            if (user.role !== 'DRIVER') {
                return reply.code(403).send({ error: 'Only drivers can check KYC status.' });
            }
            const status = await kyc_service_1.KycService.getKycStatus(user.userId);
            return reply.code(200).send({ status: 'success', data: status });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error fetching KYC status');
            return reply.code(500).send({ error: err.message });
        }
    });
    // Admin endpoints
    const requireAdmin = (request) => {
        const user = request.user;
        if (user.role !== 'ADMIN') {
            throw new Error('Admin access required');
        }
        return user;
    };
    server.get('/api/admin/kyc/pending', async (request, reply) => {
        try {
            requireAdmin(request);
            const { page = 1, limit = 10 } = request.query;
            const result = await kyc_service_1.KycService.getPendingApprovals(Number(page), Number(limit));
            return reply.code(200).send({
                status: 'success',
                data: result,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error fetching pending KYC approvals');
            if (err.message === 'Admin access required') {
                return reply.code(403).send({ error: err.message });
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/admin/kyc/:driverId/approve', async (request, reply) => {
        try {
            const admin = requireAdmin(request);
            const { driverId } = request.params;
            await kyc_service_1.KycService.approveDriver(driverId, admin.userId);
            return reply.code(200).send({
                status: 'success',
                message: 'Driver KYC approved successfully',
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error approving driver KYC');
            if (err.message === 'Admin access required') {
                return reply.code(403).send({ error: err.message });
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/admin/kyc/:driverId/reject', async (request, reply) => {
        try {
            const admin = requireAdmin(request);
            const { driverId } = request.params;
            const parsed = adminRejectSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
            }
            await kyc_service_1.KycService.rejectDriver(driverId, parsed.data.reason, admin.userId);
            return reply.code(200).send({
                status: 'success',
                message: 'Driver KYC rejected successfully',
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error rejecting driver KYC');
            if (err.message === 'Admin access required') {
                return reply.code(403).send({ error: err.message });
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/admin/kyc/:driverId/resubmit', async (request, reply) => {
        try {
            const admin = requireAdmin(request);
            const { driverId } = request.params;
            const parsed = adminRejectSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
            }
            await kyc_service_1.KycService.requestResubmission(driverId, parsed.data.reason);
            return reply.code(200).send({
                status: 'success',
                message: 'Driver KYC resubmission requested',
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error requesting KYC resubmission');
            if (err.message === 'Admin access required') {
                return reply.code(403).send({ error: err.message });
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    // Admin endpoints for payment history and trip reports
    server.get('/api/admin/payments/search', async (request, reply) => {
        try {
            const admin = requireAdmin(request);
            const { riderId, status } = request.query;
            const payments = await prisma_1.prisma.payment.findMany({
                where: {
                    ...(riderId && { riderId: riderId }),
                    ...(status && { status: status }),
                },
                orderBy: { createdAt: 'desc' },
                take: 100,
            });
            return reply.code(200).send({
                status: 'success',
                count: payments.length,
                payments,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error searching payment history');
            if (err.message === 'Admin access required') {
                return reply.code(403).send({ error: err.message });
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    server.get('/api/admin/trips/reports', async (request, reply) => {
        try {
            const admin = requireAdmin(request);
            const { cityId, dateRange } = request.query;
            const trips = await prisma_1.prisma.trip.findMany({
                where: {
                    ...(cityId && { cityId }),
                    ...(dateRange && { createdAt: { lte: new Date(dateRange.end), gte: new Date(dateRange.start) } })
                },
                orderBy: { createdAt: 'desc' },
                take: 100,
            });
            return reply.code(200).send({
                status: 'success',
                count: trips.length,
                trips: trips.map(t => ({
                    id: t.id,
                    status: t.status,
                    riderId: t.riderId,
                    createdAt: t.createdAt,
                    estimatedFare: t.estimatedFare,
                    finalFare: t.finalFare,
                })),
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error generating trip reports');
            if (err.message === 'Admin access required') {
                return reply.code(403).send({ error: err.message });
            }
            return reply.code(500).send({ error: err.message });
        }
    });
}
