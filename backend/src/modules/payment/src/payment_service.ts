import { prisma } from '../../../shared/prisma';

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

export class CashPaymentProvider implements PaymentProvider {
  public static instance: CashPaymentProvider = new CashPaymentProvider();

  private constructor() {}

  public async createPayment(tripId: string, amount: number, paymentType: 'CASH', riderId?: string): Promise<string> {
    if (paymentType !== 'CASH') {
      throw new Error(`Unsupported payment type: ${paymentType}`);
    }

    const now = new Date();

    const payment = await prisma.payment.create({
      data: {
        tripId,
        riderId: riderId || 'TEMP_RIDER',
        amount,
        method: 'CASH',
        status: 'PENDING',
        createdAt: now,
        updatedAt: now,
      },
    });

    const { eventBus } = await import('../../../shared/event_bus');
    eventBus.emit('payment.created', { paymentId: payment.id, tripId, amount, paymentMethod: 'CASH' });

    return payment.id;
  }

  public async completePayment(paymentId: string): Promise<void> {
    const payment = await prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment) {
      throw new Error(`Payment not found: ${paymentId}`);
    }

    if (payment.status !== 'PENDING') {
      throw new Error(`Payment already in status: ${payment.status}`);
    }

    const now = new Date();
    await prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: 'COMPLETED',
        collectedBy: 'DRIVER',
        collectedAt: now,
        updatedAt: now,
      },
    });

    const { eventBus } = await import('../../../shared/event_bus');
    eventBus.emit('payment.completed', { paymentId, tripId: payment.tripId, amount: payment.amount });
  }

  public async cancelPayment(paymentId: string): Promise<void> {
    const payment = await prisma.payment.findUnique({ where: { id: paymentId } });
    if (!payment) {
      throw new Error(`Payment not found: ${paymentId}`);
    }

    if (payment.status === 'COMPLETED') {
      throw new Error(`Cannot cancel completed payment: ${paymentId}`);
    }

    const now = new Date();
    await prisma.payment.update({
      where: { id: paymentId },
      data: {
        status: 'CANCELLED',
        updatedAt: now,
      },
    });

    const { eventBus } = await import('../../../shared/event_bus');
    eventBus.emit('payment.cancelled', { paymentId, tripId: payment.tripId });
  }

  public async getPayment(paymentId: string): Promise<Payment | null> {
    const payment = await prisma.payment.findUnique({ where: { id: paymentId } });
    return payment as Payment | null;
  }
}

// Backward compatibility shim
export class PaymentService {
  public static async processTripPayment(tripId: string, amount: number, riderId?: string): Promise<boolean> {
    const paymentId = await CashPaymentProvider.instance.createPayment(tripId, amount, 'CASH', riderId);
    await CashPaymentProvider.instance.completePayment(paymentId);
    return true;
  }
}