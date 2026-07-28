"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.PaymentService = exports.CashPaymentProvider = void 0;
const prisma_1 = require("../../../shared/prisma");
class CashPaymentProvider {
    static instance = new CashPaymentProvider();
    constructor() { }
    async createPayment(tripId, amount, paymentType, riderId) {
        if (paymentType !== 'CASH') {
            throw new Error(`Unsupported payment type: ${paymentType}`);
        }
        const now = new Date();
        const isValidUuid = riderId && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(riderId);
        const payment = await prisma_1.prisma.payment.create({
            data: {
                tripId,
                riderId: isValidUuid ? riderId : '00000000-0000-0000-0000-000000000000',
                amount,
                method: 'CASH',
                status: 'PENDING',
                createdAt: now,
                updatedAt: now,
            },
        });
        const { eventBus } = await Promise.resolve().then(() => __importStar(require('../../../shared/event_bus')));
        eventBus.emit('payment.created', { paymentId: payment.id, tripId, amount, paymentMethod: 'CASH' });
        return payment.id;
    }
    async completePayment(paymentId) {
        const payment = await prisma_1.prisma.payment.findUnique({ where: { id: paymentId } });
        if (!payment) {
            throw new Error(`Payment not found: ${paymentId}`);
        }
        if (payment.status !== 'PENDING') {
            throw new Error(`Payment already in status: ${payment.status}`);
        }
        const now = new Date();
        await prisma_1.prisma.payment.update({
            where: { id: paymentId },
            data: {
                status: 'COMPLETED',
                collectedBy: 'DRIVER',
                collectedAt: now,
                updatedAt: now,
            },
        });
        const { eventBus } = await Promise.resolve().then(() => __importStar(require('../../../shared/event_bus')));
        eventBus.emit('payment.completed', { paymentId, tripId: payment.tripId, amount: payment.amount });
    }
    async cancelPayment(paymentId) {
        const payment = await prisma_1.prisma.payment.findUnique({ where: { id: paymentId } });
        if (!payment) {
            throw new Error(`Payment not found: ${paymentId}`);
        }
        if (payment.status === 'COMPLETED') {
            throw new Error(`Cannot cancel completed payment: ${paymentId}`);
        }
        const now = new Date();
        await prisma_1.prisma.payment.update({
            where: { id: paymentId },
            data: {
                status: 'CANCELLED',
                updatedAt: now,
            },
        });
        const { eventBus } = await Promise.resolve().then(() => __importStar(require('../../../shared/event_bus')));
        eventBus.emit('payment.cancelled', { paymentId, tripId: payment.tripId });
    }
    async getPayment(paymentId) {
        const payment = await prisma_1.prisma.payment.findUnique({ where: { id: paymentId } });
        return payment;
    }
}
exports.CashPaymentProvider = CashPaymentProvider;
// Backward compatibility shim
class PaymentService {
    static async processTripPayment(tripId, amount, riderId) {
        const paymentId = await CashPaymentProvider.instance.createPayment(tripId, amount, 'CASH', riderId);
        await CashPaymentProvider.instance.completePayment(paymentId);
        return true;
    }
}
exports.PaymentService = PaymentService;
