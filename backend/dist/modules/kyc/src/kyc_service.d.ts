export declare class KycService {
    static submitDocument(driverId: string, docType: string, s3Key: string): Promise<void>;
    static getKycStatus(driverId: string): Promise<{
        status: 'PENDING' | 'APPROVED' | 'REJECTED';
        documents: Array<{
            type: string;
            status: string;
            s3Key: string;
        }>;
    }>;
    static approveDriver(driverId: string, approvedBy: string): Promise<void>;
    static rejectDriver(driverId: string, reason: string, approvedBy: string): Promise<void>;
    static requestResubmission(driverId: string, reason: string): Promise<void>;
    static getPendingApprovals(page?: number, limit?: number): Promise<{
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
    }>;
}
