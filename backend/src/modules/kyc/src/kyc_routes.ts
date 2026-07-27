import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyJwtMiddleware } from '../../auth';
import { logger } from '../../../shared/logger';
import { prisma } from '../../../shared/prisma';
import { R2Service } from './r2_service';
import { KycService } from './kyc_service';

const uploadUrlSchema = z.object({
  docType: z.enum(['AADHAAR_FRONT', 'AADHAAR_BACK', 'SELFIE', 'DL', 'RC', 'INSURANCE', 'VEHICLE_PHOTO']),
  contentType: z.string(),
  fileExtension: z.string(),
});

const adminApproveSchema = z.object({
  reason: z.string().optional(),
});

const adminRejectSchema = z.object({
  reason: z.string(),
});

export async function kycRoutes(server: FastifyInstance) {
  server.addHook('preHandler', verifyJwtMiddleware);

  // Driver endpoints
  server.post('/api/kyc/upload-url', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
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

      const uploadUrl = await R2Service.generatePresignedUploadUrl(objectKey, contentType);

      // Create a pending document record
      const document = await prisma.document.create({
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
    } catch (err: any) {
      logger.error(err, 'Error generating KYC upload URL');
      return reply.code(500).send({ error: err.message });
    }
  });

  server.get('/api/kyc/documents', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      if (user.role !== 'DRIVER') {
        return reply.code(403).send({ error: 'Only drivers can view KYC documents.' });
      }

      const documents = await prisma.document.findMany({
        where: { driverId: user.userId },
        orderBy: { createdAt: 'desc' },
      });

      return reply.code(200).send({
        status: 'success',
        documents,
      });
    } catch (err: any) {
      logger.error(err, 'Error fetching KYC documents');
      return reply.code(500).send({ error: err.message });
    }
  });

  server.get('/api/kyc/status', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      if (user.role !== 'DRIVER') {
        return reply.code(403).send({ error: 'Only drivers can check KYC status.' });
      }

      const status = await KycService.getKycStatus(user.userId);
      return reply.code(200).send({ status: 'success', data: status });
    } catch (err: any) {
      logger.error(err, 'Error fetching KYC status');
      return reply.code(500).send({ error: err.message });
    }
  });

  // Admin endpoints
  const requireAdmin = (request: FastifyRequest) => {
    const user = (request as any).user;
    if (user.role !== 'ADMIN') {
      throw new Error('Admin access required');
    }
    return user;
  };

  server.get('/api/admin/kyc/pending', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);

      const { page = 1, limit = 10 } = request.query as any;
      const result = await KycService.getPendingApprovals(Number(page), Number(limit));

      return reply.code(200).send({
        status: 'success',
        data: result,
      });
    } catch (err: any) {
      logger.error(err, 'Error fetching pending KYC approvals');
      if (err.message === 'Admin access required') {
        return reply.code(403).send({ error: err.message });
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/admin/kyc/:driverId/approve', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const admin = requireAdmin(request);
      const { driverId } = request.params as any;

      await KycService.approveDriver(driverId, admin.userId);

      return reply.code(200).send({
        status: 'success',
        message: 'Driver KYC approved successfully',
      });
    } catch (err: any) {
      logger.error(err, 'Error approving driver KYC');
      if (err.message === 'Admin access required') {
        return reply.code(403).send({ error: err.message });
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/admin/kyc/:driverId/reject', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const admin = requireAdmin(request);
      const { driverId } = request.params as any;

      const parsed = adminRejectSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
      }

      await KycService.rejectDriver(driverId, parsed.data.reason, admin.userId);

      return reply.code(200).send({
        status: 'success',
        message: 'Driver KYC rejected successfully',
      });
    } catch (err: any) {
      logger.error(err, 'Error rejecting driver KYC');
      if (err.message === 'Admin access required') {
        return reply.code(403).send({ error: err.message });
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/admin/kyc/:driverId/resubmit', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const admin = requireAdmin(request);
      const { driverId } = request.params as any;

      const parsed = adminRejectSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid input fields', details: parsed.error.issues });
      }

      await KycService.requestResubmission(driverId, parsed.data.reason);

      return reply.code(200).send({
        status: 'success',
        message: 'Driver KYC resubmission requested',
      });
    } catch (err: any) {
      logger.error(err, 'Error requesting KYC resubmission');
      if (err.message === 'Admin access required') {
        return reply.code(403).send({ error: err.message });
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  // Admin endpoints for payment history and trip reports
  server.get('/api/admin/payments/search', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const admin = requireAdmin(request);
      const { riderId, status } = request.query as any;

      const payments = await prisma.payment.findMany({
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
    } catch (err: any) {
      logger.error(err, 'Error searching payment history');
      if (err.message === 'Admin access required') {
        return reply.code(403).send({ error: err.message });
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  server.get('/api/admin/trips/reports', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const admin = requireAdmin(request);
      const { cityId, dateRange } = request.query as any;

      const trips = await prisma.trip.findMany({
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
    } catch (err: any) {
      logger.error(err, 'Error generating trip reports');
      if (err.message === 'Admin access required') {
        return reply.code(403).send({ error: err.message });
      }
      return reply.code(500).send({ error: err.message });
    }
  });
}
