import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { TripService } from './trip_service';
import { PricingService } from '../../pricing';
import { verifyJwtMiddleware } from '../../auth';
import { logger } from '../../../shared/logger';
import { prisma } from '../../../shared/prisma';
import { NotFoundError } from '../../../shared/errors';

import { config } from '../../../shared/config';

const estimateSchema = z.object({
  pickupLat: z.number(),
  pickupLng: z.number(),
  dropoffLat: z.number(),
  dropoffLng: z.number(),
  cityId: z.string().optional(),
});

const requestTripSchema = z.object({
  pickupLat: z.number(),
  pickupLng: z.number(),
  pickupAddress: z.string(),
  dropoffLat: z.number(),
  dropoffLng: z.number(),
  dropoffAddress: z.string(),
  vehicleType: z.enum(['bike', 'auto', 'cab']),
  cityId: z.string().optional(),
});

export async function tripRoutes(server: FastifyInstance) {
  // Apply JWT verification middleware to all trip endpoints
  server.addHook('preHandler', verifyJwtMiddleware);

  server.post('/api/trips/estimate', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const parsed = estimateSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid input fields' });
      }

      let { pickupLat, pickupLng, dropoffLat, dropoffLng, cityId } = parsed.data;

      if (!cityId) {
        if (config.ENABLE_DEFAULT_CITY && config.DEFAULT_CITY_ID) {
          cityId = config.DEFAULT_CITY_ID;
        } else {
          return reply.code(400).send({ error: 'cityId is required' });
        }
      }

      // Estimate prices for all three vehicle types
      const bikeEstimate = await PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, 'bike', cityId);
      const autoEstimate = await PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, 'auto', cityId);
      const cabEstimate = await PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, 'cab', cityId);

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
    } catch (err: any) {
      logger.error(err, 'Error calculating fare estimates');
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
  }, async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const parsed = requestTripSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid trip request fields' });
      }

      let {
        pickupLat,
        pickupLng,
        pickupAddress,
        dropoffLat,
        dropoffLng,
        dropoffAddress,
        vehicleType,
        cityId,
      } = parsed.data;

      if (!cityId) {
        if (config.ENABLE_DEFAULT_CITY && config.DEFAULT_CITY_ID) {
          cityId = config.DEFAULT_CITY_ID;
        } else {
          return reply.code(400).send({ error: 'cityId is required' });
        }
      }

      const user = (request as any).user;

      // Calculate final estimated fare
      const fare = await PricingService.calculateFare(pickupLat, pickupLng, dropoffLat, dropoffLng, vehicleType, cityId);

      const trip = await TripService.createTrip({
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
    } catch (err: any) {
      logger.error(err, 'Error requesting trip');
      return reply.code(500).send({ error: err.message });
    }
  });

  server.get('/api/trips/:id', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const { id } = request.params as any;
      const trip = await prisma.trip.findUnique({ where: { id } });
      if (!trip) {
        throw new NotFoundError(`Trip not found for ID: ${id}`);
      }

      return reply.code(200).send({
        status: 'success',
        trip,
      });
    } catch (err: any) {
      if (err.statusCode) {
        return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      }
      return reply.code(500).send({ error: err.message });
    }
  });

  // --- Driver Trip Interaction Endpoints ---

  const requireDriver = (request: FastifyRequest) => {
    const user = (request as any).user;
    if (user.role !== 'DRIVER' && user.role !== 'ADMIN') {
      throw new Error('Only drivers or admins can perform this action');
    }
    return user;
  };

  server.post('/api/trips/:id/accept', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const driver = requireDriver(request);
      const { id } = request.params as any;
      const trip = await TripService.acceptTrip(id, driver.userId);
      return reply.code(200).send({ status: 'success', trip });
    } catch (err: any) {
      if (err.statusCode) return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/trips/:id/reject', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const driver = requireDriver(request);
      const { id } = request.params as any;
      await TripService.rejectTrip(id, driver.userId);
      return reply.code(200).send({ status: 'success', message: 'Trip rejected and re-dispatch triggered' });
    } catch (err: any) {
      if (err.statusCode) return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/trips/:id/arrive', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const driver = requireDriver(request);
      const { id } = request.params as any;
      const trip = await TripService.driverArrived(id, driver.userId);
      return reply.code(200).send({ status: 'success', trip });
    } catch (err: any) {
      if (err.statusCode) return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      return reply.code(500).send({ error: err.message });
    }
  });

  const startTripSchema = z.object({
    otp: z.string().length(4),
  });

  server.post('/api/trips/:id/start', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const driver = requireDriver(request);
      const { id } = request.params as any;
      const parsed = startTripSchema.safeParse(request.body);
      if (!parsed.success) {
        return reply.code(400).send({ error: 'Invalid OTP' });
      }
      const trip = await TripService.startTrip(id, driver.userId, parsed.data.otp);
      return reply.code(200).send({ status: 'success', trip });
    } catch (err: any) {
      if (err.statusCode) return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      return reply.code(500).send({ error: err.message });
    }
  });

  server.post('/api/trips/:id/complete', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      const driver = requireDriver(request);
      const { id } = request.params as any;
      const trip = await TripService.completeTrip(id, driver.userId);
      return reply.code(200).send({ status: 'success', trip });
    } catch (err: any) {
      if (err.statusCode) return reply.code(err.statusCode).send(err.toRFC7807(request.url));
      return reply.code(500).send({ error: err.message });
    }
  });
}
