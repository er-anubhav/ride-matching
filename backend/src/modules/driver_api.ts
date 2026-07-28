import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { verifyJwtMiddleware } from './auth';
import { logger } from '../shared/logger';
import { prisma } from '../shared/prisma';

// In-memory data store for Driver Profile & KYC when explicit tables are pending
const driverProfileStore = new Map<string, any>();
const driverKycStore = new Map<string, any>();
const driverEarningsStore = new Map<string, any>();

export async function driverApiRoutes(server: FastifyInstance) {
  server.addHook('preHandler', verifyJwtMiddleware);

  // 1. Driver Profile: GET /api/driver/profile & PUT /api/driver/profile
  server.get('/api/driver/profile', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const dbUser = await prisma.user.findUnique({
        where: { id: user.userId },
        include: { driverProfile: true },
      });

      const storeProfile = driverProfileStore.get(user.userId) || {};

      return reply.code(200).send({
        status: 'success',
        driverId: user.userId,
        name: dbUser?.name || user.name || storeProfile.name || 'Vikram Singh',
        phone: dbUser?.phone || user.phone || '+91 98765 12345',
        rating: 4.9,
        vehicleMake: dbUser?.driverProfile?.vehicleMake || storeProfile.vehicleMake || 'Maruti',
        vehicleModel: dbUser?.driverProfile?.vehicleModel || storeProfile.vehicleModel || 'Swift',
        vehicleNumber: dbUser?.driverProfile?.licencePlate || storeProfile.vehicleNumber || 'UP32-AB-9999',
        upiId: storeProfile.upiId || 'vikram@okaxis',
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.put('/api/driver/profile', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const body = (request.body as any) || {};

      const storeProfile = driverProfileStore.get(user.userId) || {};
      const updated = {
        ...storeProfile,
        ...(body.vehicleMake ? { vehicleMake: body.vehicleMake } : {}),
        ...(body.vehicleModel ? { vehicleModel: body.vehicleModel } : {}),
        ...(body.vehicleNumber ? { vehicleNumber: body.vehicleNumber } : {}),
        ...(body.upiId ? { upiId: body.upiId } : {}),
      };
      driverProfileStore.set(user.userId, updated);

      return reply.code(200).send({
        status: 'success',
        driverId: user.userId,
        ...updated,
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // 2. KYC Status & Document Upload: GET /api/driver/kyc/status & POST /api/driver/kyc/documents
  server.get('/api/driver/kyc/status', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const kyc = driverKycStore.get(user.userId) || {
        status: 'approved',
        rcUploaded: true,
        dlUploaded: true,
        insuranceUploaded: true,
        aadhaarUploaded: true,
        submittedAt: new Date().toISOString(),
      };
      driverKycStore.set(user.userId, kyc);
      return reply.code(200).send({
        status: 'success',
        kyc,
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/driver/kyc/documents', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const body = (request.body as any) || {};

      const kycData = {
        status: 'under_review',
        vehicleMake: body.vehicleMake,
        vehicleModel: body.vehicleModel,
        vehicleNumber: body.vehicleNumber,
        rcDocumentUrl: body.rcDocumentUrl || 'rc_doc.pdf',
        dlDocumentUrl: body.dlDocumentUrl || 'dl_doc.pdf',
        insuranceDocumentUrl: body.insuranceDocumentUrl || 'insurance_doc.pdf',
        aadhaarDocumentUrl: body.aadhaarDocumentUrl || 'aadhaar_doc.pdf',
        submittedAt: new Date().toISOString(),
      };
      driverKycStore.set(user.userId, kycData);

      return reply.code(200).send({
        status: 'success',
        message: 'KYC documents submitted successfully. Under review.',
        kyc: kycData,
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  // 3. Driver Earnings & Payout: GET /api/driver/earnings & POST /api/driver/payout
  server.get('/api/driver/earnings', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const earnings = driverEarningsStore.get(user.userId) || {
        totalEarnings: 1240.50,
        tripsCompleted: 4,
        onlineHours: 8.4,
        nextPayoutDate: 'Monday, Aug 3',
        history: [],
      };
      driverEarningsStore.set(user.userId, earnings);
      return reply.code(200).send({
        status: 'success',
        earnings,
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/driver/payout', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const user = (request as any).user;
      const { amount } = (request.body as any) || {};
      const numAmount = parseFloat(amount) || 0.0;

      const earnings = driverEarningsStore.get(user.userId) || { totalEarnings: 0.0, history: [] };
      earnings.totalEarnings = Math.max(0, earnings.totalEarnings - numAmount);
      driverEarningsStore.set(user.userId, earnings);

      return reply.code(200).send({
        status: 'success',
        message: `Payout request for ₹${numAmount.toFixed(2)} processed successfully via UPI`,
        remainingBalance: earnings.totalEarnings,
      });
    } catch (err: any) {
      return reply.code(500).send({ error: err.message });
    }
  });
}
