import { prisma } from '../../../shared/prisma';
import { logger } from '../../../shared/logger';
import { eventBus } from '../../../shared/event_bus';

export class KycService {
  public static async submitDocument(driverId: string, docType: string, s3Key: string): Promise<void> {
    await prisma.document.create({
      data: {
        driverId,
        docType,
        s3Key,
        verificationStatus: 'PENDING',
      },
    });

    logger.info({ driverId, docType }, 'Document submitted for verification');

    const driverProfile = await prisma.driverProfile.findUnique({ where: { driverId } });
    if (driverProfile) {
      eventBus.emit('kyc.document_submitted', { driverId, docType, s3Key });
    }
  }

  public static async getKycStatus(driverId: string): Promise<{
    status: 'PENDING' | 'APPROVED' | 'REJECTED';
    documents: Array<{ type: string; status: string; s3Key: string }>;
  }> {
    const driverProfile = await prisma.driverProfile.findUnique({
      where: { driverId },
    });

    if (!driverProfile) {
      return { status: 'PENDING', documents: [] };
    }

    // Documents are on User, not DriverProfile — query separately
    const docs = await prisma.document.findMany({
      where: { driverId },
      orderBy: { createdAt: 'desc' },
    });

    return {
      status: driverProfile.kycStatus as any,
      documents: docs.map(d => ({
        type: d.docType,
        status: d.verificationStatus,
        s3Key: d.s3Key,
      })),
    };
  }

  public static async approveDriver(driverId: string, approvedBy: string): Promise<void> {
    const driverProfile = await prisma.driverProfile.findUnique({ where: { driverId } });
    if (!driverProfile) {
      throw new Error('Driver profile not found');
    }

    // Update KYC status
    await prisma.driverProfile.update({
      where: { driverId },
      data: {
        kycStatus: 'APPROVED',
        approvedBy,
        approvalNote: 'Approved by admin',
        updatedAt: new Date(),
      },
    });

    // Update user status to ACTIVE
    const userId = driverProfile.driverId;
    await prisma.user.update({
      where: { id: userId },
      data: {
        status: 'ACTIVE',
      },
    });

    logger.info({ driverId, approvedBy }, 'Driver KYC approved');

    eventBus.emit('kyc.approved', { driverId, approvedBy });
  }

  public static async rejectDriver(driverId: string, reason: string, approvedBy: string): Promise<void> {
    const driverProfile = await prisma.driverProfile.findUnique({ where: { driverId } });
    if (!driverProfile) {
      throw new Error('Driver profile not found');
    }

    await prisma.driverProfile.update({
      where: { driverId },
      data: {
        kycStatus: 'REJECTED',
        approvalNote: reason,
        approvedBy,
        updatedAt: new Date(),
      },
    });

    // Update user status to BLOCKED
    const userId = driverProfile.driverId;
    await prisma.user.update({
      where: { id: userId },
      data: {
        status: 'BLOCKED',
      },
    });

    logger.info({ driverId, reason, approvedBy }, 'Driver KYC rejected');

    eventBus.emit('kyc.rejected', { driverId, reason, approvedBy });
  }

  public static async requestResubmission(driverId: string, reason: string): Promise<void> {
    const driverProfile = await prisma.driverProfile.findUnique({ where: { driverId } });
    if (!driverProfile) {
      throw new Error('Driver profile not found');
    }

    await prisma.driverProfile.update({
      where: { driverId },
      data: {
        kycStatus: 'PENDING',
        approvalNote: reason,
        updatedAt: new Date(),
      },
    });

    logger.info({ driverId, reason }, 'Driver KYC resubmission requested');
  }

  public static async getPendingApprovals(page: number = 1, limit: number = 10): Promise<{
    drivers: Array<{
      id: string;
      name: string | null;
      phone: string;
      vehicleType: string;
      kycStatus: string;
      createdAt: Date;
    }>;
    total: number;
    page: number;
    limit: number;
  }> {
    const skip = (page - 1) * limit;

    const [drivers, total] = await Promise.all([
      prisma.driverProfile.findMany({
        where: { kycStatus: 'PENDING' },
        include: {
          driver: true,
        },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      prisma.driverProfile.count({
        where: { kycStatus: 'PENDING' },
      }),
    ]);

    return {
      drivers: drivers.map(d => ({
        id: d.driverId,
        name: d.driver.name,
        phone: d.driver.phone,
        vehicleType: d.vehicleType,
        kycStatus: d.kycStatus,
        createdAt: d.createdAt,
      })),
      total,
      page,
      limit,
    };
  }
}