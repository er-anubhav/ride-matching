"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tripRoutes = tripRoutes;
const zod_1 = require("zod");
const trip_service_1 = require("./trip_service");
const pricing_1 = require("../../pricing");
const auth_1 = require("../../auth");
const logger_1 = require("../../../shared/logger");
const prisma_1 = require("../../../shared/prisma");
const errors_1 = require("../../../shared/errors");
const config_1 = require("../../../shared/config");
const estimateSchema = zod_1.z.object({
    pickupLat: zod_1.z.number(),
    pickupLng: zod_1.z.number(),
    dropoffLat: zod_1.z.number(),
    dropoffLng: zod_1.z.number(),
    cityId: zod_1.z.string().optional(),
});
const requestTripSchema = zod_1.z.object({
    pickupLat: zod_1.z.number(),
    pickupLng: zod_1.z.number(),
    pickupAddress: zod_1.z.string(),
    dropoffLat: zod_1.z.number(),
    dropoffLng: zod_1.z.number(),
    dropoffAddress: zod_1.z.string(),
    vehicleType: zod_1.z.enum(['bike', 'auto', 'cab']),
    cityId: zod_1.z.string().optional(),
});
async function tripRoutes(server) {
    // Apply JWT verification middleware to all trip endpoints
    server.addHook('preHandler', auth_1.verifyJwtMiddleware);
    server.post('/api/trips/estimate', async (request, reply) => {
        try {
            const parsed = estimateSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid input fields' });
            }
            let { pickupLat, pickupLng, dropoffLat, dropoffLng, cityId } = parsed.data;
            if (!cityId) {
                if (config_1.config.ENABLE_DEFAULT_CITY && config_1.config.DEFAULT_CITY_ID) {
                    cityId = config_1.config.DEFAULT_CITY_ID;
                }
                else {
                    return reply.code(400).send({ error: 'cityId is required' });
                }
            }
            // Estimate prices for all three vehicle types
            const bikeEstimate = await pricing_1.PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, 'bike', cityId);
            const autoEstimate = await pricing_1.PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, 'auto', cityId);
            const cabEstimate = await pricing_1.PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, 'cab', cityId);
            return reply.code(200).send({
                status: 'success',
                estimates: {
                    bike: bikeEstimate.estimatedFare,
                    auto: autoEstimate.estimatedFare,
                    cab: cabEstimate.estimatedFare,
                    distance: bikeEstimate.distanceKm,
                    durationMin: bikeEstimate.durationMin,
                    estimated: bikeEstimate.estimated,
                    routeSource: bikeEstimate.routeSource
                },
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error calculating fare estimates');
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/trips/request', {
        config: {
            rateLimit: {
                max: 5,
                timeWindow: '1 minute',
            }
        }
    }, async (request, reply) => {
        try {
            const parsed = requestTripSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid trip request fields' });
            }
            let { pickupLat, pickupLng, pickupAddress, dropoffLat, dropoffLng, dropoffAddress, vehicleType, cityId, } = parsed.data;
            if (!cityId) {
                if (config_1.config.ENABLE_DEFAULT_CITY && config_1.config.DEFAULT_CITY_ID) {
                    cityId = config_1.config.DEFAULT_CITY_ID;
                }
                else {
                    return reply.code(400).send({ error: 'cityId is required' });
                }
            }
            const user = request.user;
            // Calculate final estimated fare
            const fare = await pricing_1.PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, vehicleType, cityId);
            const trip = await trip_service_1.TripService.createTrip({
                riderId: user.userId,
                pickupLat,
                pickupLng,
                pickupAddress,
                dropoffLat,
                dropoffLng,
                dropoffAddress,
                price: fare.estimatedFare,
                vehicleType,
            });
            return reply.code(201).send({
                status: 'success',
                trip,
            });
        }
        catch (err) {
            logger_1.logger.error(err, 'Error requesting trip');
            return reply.code(500).send({ error: err.message });
        }
    });
    server.get('/api/trips/:id', async (request, reply) => {
        try {
            const { id } = request.params;
            const trip = await prisma_1.prisma.trip.findUnique({ where: { id } });
            if (!trip) {
                throw new errors_1.NotFoundError(`Trip not found for ID: ${id}`);
            }
            return reply.code(200).send({
                status: 'success',
                trip,
            });
        }
        catch (err) {
            if (err.statusCode) {
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            }
            return reply.code(500).send({ error: err.message });
        }
    });
    // --- Driver Trip Interaction Endpoints ---
    const requireDriver = (request) => {
        const user = request.user;
        if (user.role !== 'DRIVER') {
            throw new Error('Only drivers can perform this action');
        }
        return user;
    };
    server.post('/api/trips/:id/accept', async (request, reply) => {
        try {
            const driver = requireDriver(request);
            const { id } = request.params;
            const trip = await trip_service_1.TripService.acceptTrip(id, driver.userId);
            return reply.code(200).send({ status: 'success', trip });
        }
        catch (err) {
            if (err.statusCode)
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/trips/:id/reject', async (request, reply) => {
        try {
            const driver = requireDriver(request);
            const { id } = request.params;
            await trip_service_1.TripService.rejectTrip(id, driver.userId);
            return reply.code(200).send({ status: 'success', message: 'Trip rejected and re-dispatch triggered' });
        }
        catch (err) {
            if (err.statusCode)
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/trips/:id/arrive', async (request, reply) => {
        try {
            const driver = requireDriver(request);
            const { id } = request.params;
            const trip = await trip_service_1.TripService.driverArrived(id, driver.userId);
            return reply.code(200).send({ status: 'success', trip });
        }
        catch (err) {
            if (err.statusCode)
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            return reply.code(500).send({ error: err.message });
        }
    });
    const startTripSchema = zod_1.z.object({
        otp: zod_1.z.string().length(4),
    });
    server.post('/api/trips/:id/start', async (request, reply) => {
        try {
            const driver = requireDriver(request);
            const { id } = request.params;
            const parsed = startTripSchema.safeParse(request.body);
            if (!parsed.success) {
                return reply.code(400).send({ error: 'Invalid OTP' });
            }
            const trip = await trip_service_1.TripService.startTrip(id, driver.userId, parsed.data.otp);
            return reply.code(200).send({ status: 'success', trip });
        }
        catch (err) {
            if (err.statusCode)
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            return reply.code(500).send({ error: err.message });
        }
    });
    server.post('/api/trips/:id/complete', async (request, reply) => {
        try {
            const driver = requireDriver(request);
            const { id } = request.params;
            const trip = await trip_service_1.TripService.completeTrip(id, driver.userId);
            return reply.code(200).send({ status: 'success', trip });
        }
        catch (err) {
            if (err.statusCode)
                return reply.code(err.statusCode).send(err.toRFC7807(request.url));
            return reply.code(500).send({ error: err.message });
        }
    });
}
