"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.KycService = void 0;
const prisma_1 = require("../../../shared/prisma");
const logger_1 = require("../../../shared/logger");
const event_bus_1 = require("../../../shared/event_bus");
class KycService {
    static async submitDocument(driverId, docType, s3Key) {
        await prisma_1.prisma.document.create({
            data: {
                driverId,
                docType,
                s3Key,
                verificationStatus: 'PENDING',
            },
        });
        logger_1.logger.info({ driverId, docType }, 'Document submitted for verification');
        const driverProfile = await prisma_1.prisma.driverProfile.findUnique({ where: { driverId } });
        if (driverProfile) {
            event_bus_1.eventBus.emit('kyc.document_submitted', { driverId, docType, s3Key });
        }
    }
    static async getKycStatus(driverId) {
        const driverProfile = await prisma_1.prisma.driverProfile.findUnique({
            where: { driverId },
            include: {
                documents: true,
            },
        });
        if (!driverProfile) {
            return { status: 'PENDING', documents: [] };
        }
        return {
            status: driverProfile.kycStatus,
            documents: driverProfile.documents.map(d => ({
                type: d.docType,
                status: d.verificationStatus,
                s3Key: d.s3Key,
            })),
        };
    }
    static async approveDriver(driverId, approvedBy) {
        const driverProfile = await prisma_1.prisma.driverProfile.findUnique({ where: { driverId } });
        if (!driverProfile) {
            throw new Error('Driver profile not found');
        }
        // Update KYC status
        await prisma_1.prisma.driverProfile.update({
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
        await prisma_1.prisma.user.update({
            where: { id: userId },
            data: {
                status: 'ACTIVE',
            },
        });
        logger_1.logger.info({ driverId, approvedBy }, 'Driver KYC approved');
        event_bus_1.eventBus.emit('kyc.approved', { driverId, approvedBy });
    }
    static async rejectDriver(driverId, reason, approvedBy) {
        const driverProfile = await prisma_1.prisma.driverProfile.findUnique({ where: { driverId } });
        if (!driverProfile) {
            throw new Error('Driver profile not found');
        }
        await prisma_1.prisma.driverProfile.update({
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
        await prisma_1.prisma.user.update({
            where: { id: userId },
            data: {
                status: 'BLOCKED',
            },
        });
        logger_1.logger.info({ driverId, reason, approvedBy }, 'Driver KYC rejected');
        event_bus_1.eventBus.emit('kyc.rejected', { driverId, reason, approvedBy });
    }
    static async requestResubmission(driverId, reason) {
        const driverProfile = await prisma_1.prisma.driverProfile.findUnique({ where: { driverId } });
        if (!driverProfile) {
            throw new Error('Driver profile not found');
        }
        await prisma_1.prisma.driverProfile.update({
            where: { driverId },
            data: {
                kycStatus: 'PENDING',
                approvalNote: reason,
                updatedAt: new Date(),
            },
        });
        logger_1.logger.info({ driverId, reason }, 'Driver KYC resubmission requested');
    }
    static async getPendingApprovals(page = 1, limit = 10) {
        const skip = (page - 1) * limit;
        const [drivers, total] = await Promise.all([
            prisma_1.prisma.driverProfile.findMany({
                where: { kycStatus: 'PENDING' },
                include: {
                    driver: true,
                },
                skip,
                take: limit,
                orderBy: { createdAt: 'desc' },
            }),
            prisma_1.prisma.driverProfile.count({
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
exports.KycService = KycService;
