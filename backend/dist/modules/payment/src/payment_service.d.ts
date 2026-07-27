export interface PaymentCreateInput {
    tripId: string;
    amount: number;
    paymentMethod?: 'CASH';
    riderId?: string;
}
export interface PaymentUpdateInput {
    status?: 'PENDING' | 'COMPLETED' | 'CANCELLED' | 'FAILED';
    collectedBy?: 'DRIVER' | null;
    collectedAt?: Date | null;
    settledAt?: Date | null;
}
export interface Payment {
    id: string;
    tripId: string;
    riderId: string;
    amount: number;
    paymentMethod: 'CASH' | 'CARD' | 'UPI';
    status: 'PENDING' | 'COMPLETED' | 'CANCELLED' | 'FAILED';
    collectedBy?: 'DRIVER' | null;
    collectedAt?: Date | null;
    createdAt: Date;
    updatedAt: Date;
    settledAt?: Date | null;
}
export interface PaymentProvider {
    createPayment(tripId: string, amount: number, paymentType: 'CASH', riderId?: string): Promise<string>;
    completePayment(paymentId: string): Promise<void>;
    cancelPayment(paymentId: string): Promise<void>;
}
export declare class CashPaymentProvider implements PaymentProvider {
    static instance: CashPaymentProvider;
    private constructor();
    createPayment(tripId: string, amount: number, paymentType: 'CASH', riderId?: string): Promise<string>;
    completePayment(paymentId: string): Promise<void>;
    cancelPayment(paymentId: string): Promise<void>;
    getPayment(paymentId: string): Promise<Payment | null>;
}
export declare class PaymentService {
    static processTripPayment(tripId: string, amount: number, riderId?: string): Promise<boolean>;
}
