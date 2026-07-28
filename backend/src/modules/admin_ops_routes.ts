import { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import path from 'path';
import fs from 'fs';
import { verifyJwtMiddleware } from './auth';
import { prisma } from '../shared/prisma';
import { redisClient } from '../shared/redis';
import { logger } from '../shared/logger';
import { memoryStore } from '../state/memory_store';
import { activeRiderSubscriptions } from './notification/src/ws_handler';
import { MatchingService } from './matching';
import { getDistanceKm } from './pricing';

const requireAdmin = (request: FastifyRequest) => {
  const user = (request as any).user;
  if (user?.role !== 'ADMIN') {
    throw new Error('Admin access required');
  }
  return user;
};

export async function adminOpsRoutes(server: FastifyInstance) {
  server.addHook('preHandler', verifyJwtMiddleware);

  // 1. GET /api/admin/fleet/live - Real-time drivers in Redis & DB
  server.get('/api/admin/fleet/live', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);

      // 1. Search Redis drivers:geo worldwide (20,000 km radius)
      let geoDriverIds: string[] = [];
      try {
        const res = await redisClient.georadius(
          'drivers:geo',
          80.9462,
          26.8467,
          20000,
          'km'
        );
        geoDriverIds = (res || []) as string[];
      } catch (e) {
        logger.warn(e, 'Error fetching drivers:geo radius');
      }

      // 2. Scan Redis for all active driver:data:* hash keys
      let dataKeyIds: string[] = [];
      try {
        const keys = await redisClient.keys('driver:data:*');
        dataKeyIds = keys.map((k) => k.replace('driver:data:', ''));
      } catch (e) {
        logger.warn(e, 'Error scanning driver:data:* keys');
      }

      const allRedisDriverIds = Array.from(new Set<string>([...geoDriverIds, ...dataKeyIds]));

      // 3. Fetch driver metadata from PostgreSQL DB for all candidate IDs
      let dbUserMap = new Map<string, any>();
      if (allRedisDriverIds.length > 0) {
        try {
          const dbUsers = await prisma.user.findMany({
            where: { id: { in: allRedisDriverIds } },
            include: { driverProfile: true },
          });
          dbUserMap = new Map(dbUsers.map((u) => [u.id, u]));
        } catch (e) {
          logger.warn(e, 'Error fetching DB driver profiles for live fleet');
        }
      }

      const driversMap = new Map<string, any>();

      if (allRedisDriverIds.length > 0) {
        const pipeline = redisClient.pipeline();
        allRedisDriverIds.forEach((id) => pipeline.hgetall(`driver:data:${id}`));
        const results = await pipeline.exec();

        if (results) {
          let idx = 0;
          for (const [err, data] of results) {
            const candidateId = allRedisDriverIds[idx++];
            if (!err && data && Object.keys(data as any).length > 0) {
              const d = data as Record<string, string>;
              const dId = d.driverId || candidateId;

              const lat = parseFloat(d.lat || '0');
              const lng = parseFloat(d.lng || '0');
              const lastSeen = parseInt(d.lastSeen || '0', 10);
              const hasSocket = memoryStore.getSocket(dId) ? true : false;

              // Filter out stale/zombie keys with no valid location, no socket, and no heartbeat in last 15 mins
              const isRecent = lastSeen > 0 && Date.now() - lastSeen < 15 * 60 * 1000;
              const hasLocation = lat !== 0 && lng !== 0;

              if (!hasSocket && !isRecent && !hasLocation) {
                continue;
              }

              const dbUser = dbUserMap.get(dId);
              const dbProfile = dbUser?.driverProfile;

              driversMap.set(dId, {
                driverId: dId,
                name: d.name || dbUser?.name || 'Driver',
                phone: d.phone || dbUser?.phone || '',
                vehicleNumber: d.vehicleNumber || dbProfile?.licencePlate || '',
                vehicleName:
                  d.vehicleName ||
                  (dbProfile?.vehicleMake ? `${dbProfile.vehicleMake} ${dbProfile.vehicleModel || ''}` : 'Vehicle'),
                vehicleType: (d.vehicleType || dbProfile?.vehicleType || 'bike').toLowerCase(),
                lat: hasLocation ? lat : 26.8467,
                lng: hasLocation ? lng : 80.9462,
                heading: parseFloat(d.heading || '0'),
                status: d.status || 'ONLINE',
                rating: parseFloat(d.rating || '4.8'),
                acceptanceRate: parseFloat(d.acceptanceRate || '0.95'),
                cancellationRate: parseFloat(d.cancellationRate || '0.02'),
                lastSeen: lastSeen || Date.now(),
                hasActiveSocket: hasSocket,
              });
            }
          }
        }
      }

      // 4. Fallback: Include approved drivers in PostgreSQL DB who have active WebSocket connections
      try {
        const approvedProfiles = await prisma.driverProfile.findMany({
          where: { kycStatus: 'APPROVED' },
          include: { driver: true },
        });

        for (const prof of approvedProfiles) {
          if (!driversMap.has(prof.driverId)) {
            const hasSocket = memoryStore.getSocket(prof.driverId) ? true : false;
            if (hasSocket) {
              driversMap.set(prof.driverId, {
                driverId: prof.driverId,
                name: prof.driver?.name || 'Driver',
                phone: prof.driver?.phone || '',
                vehicleNumber: prof.licencePlate || '',
                vehicleName: `${prof.vehicleMake || 'Hero'} ${prof.vehicleModel || 'Splendor'}`,
                vehicleType: prof.vehicleType ? prof.vehicleType.toLowerCase() : 'bike',
                lat: 26.8467,
                lng: 80.9462,
                heading: 0,
                status: 'ONLINE',
                rating: 4.8,
                acceptanceRate: 0.95,
                cancellationRate: 0.02,
                lastSeen: Date.now(),
                hasActiveSocket: hasSocket,
              });
            }
          }
        }
      } catch (e) {
        logger.warn(e, 'Error fetching DB approved profiles fallback');
      }

      const drivers = Array.from(driversMap.values());

      return reply.code(200).send({
        status: 'success',
        count: drivers.length,
        drivers,
      });
    } catch (err: any) {
      logger.error(err, 'Error in GET /api/admin/fleet/live');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 2. GET /api/admin/trips/active - Real-time active trips
  server.get('/api/admin/trips/active', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);

      // Auto-expire stale REQUESTED trips older than 10 minutes
      const requestExpiry = new Date(Date.now() - 10 * 60 * 1000);
      await prisma.trip.updateMany({
        where: { status: 'REQUESTED', createdAt: { lt: requestExpiry } },
        data: { status: 'EXPIRED' },
      });

      // Auto-expire stale ASSIGNED/ARRIVED trips older than 30 minutes (dead/abandoned rides)
      const assignedExpiry = new Date(Date.now() - 30 * 60 * 1000);
      await prisma.trip.updateMany({
        where: { status: { in: ['ASSIGNED', 'ARRIVED'] }, createdAt: { lt: assignedExpiry } },
        data: { status: 'EXPIRED' },
      });

      const activeTrips = await prisma.trip.findMany({
        where: {
          status: { in: ['REQUESTED', 'ASSIGNED', 'ARRIVED', 'IN_PROGRESS'] },
        },
        include: {
          rider: { select: { id: true, name: true, phone: true } },
          driver: { select: { id: true, name: true, phone: true } },
        },
        orderBy: { createdAt: 'desc' },
      });

      return reply.code(200).send({
        status: 'success',
        count: activeTrips.length,
        trips: activeTrips.map((t) => ({
          id: t.id,
          status: t.status,
          vehicleType: t.vehicleType,
          riderId: t.riderId,
          riderName: t.rider?.name || 'Rider',
          riderPhone: t.rider?.phone || '',
          driverId: t.driverId,
          driverName: t.driver?.name || null,
          driverPhone: t.driver?.phone || null,
          pickupLat: Number(t.pickupLat),
          pickupLng: Number(t.pickupLng),
          pickupAddress: t.pickupAddress,
          dropoffLat: Number(t.dropoffLat),
          dropoffLng: Number(t.dropoffLng),
          dropoffAddress: t.dropoffAddress,
          estimatedFare: Number(t.estimatedFare),
          finalFare: t.finalFare ? Number(t.finalFare) : null,
          riderOtp: t.riderOtp,
          createdAt: t.createdAt,
          startedAt: t.startedAt,
        })),
      });
    } catch (err: any) {
      logger.error(err, 'Error in GET /api/admin/trips/active');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 3. GET /api/admin/matching/queue - Active matching queue & candidate scoring diagnostics
  server.get('/api/admin/matching/queue', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);

      // Auto-expire stale REQUESTED trips older than 10 minutes
      const expiryCutoff = new Date(Date.now() - 10 * 60 * 1000);
      await prisma.trip.updateMany({
        where: { status: 'REQUESTED', createdAt: { lt: expiryCutoff } },
        data: { status: 'EXPIRED' },
      });

      // Only fetch genuinely active REQUESTED trips (created within last 10 minutes)
      const searchingTrips = await prisma.trip.findMany({
        where: { status: 'REQUESTED' },
        include: { rider: { select: { name: true, phone: true } } },
        orderBy: { createdAt: 'desc' },
      });

      const queueDetails: any[] = [];

      for (const trip of searchingTrips) {
        const pickupLatNum = Number(trip.pickupLat);
        const pickupLngNum = Number(trip.pickupLng);

        const scoredCandidates = await MatchingService.findDrivers(
          pickupLatNum,
          pickupLngNum,
          trip.vehicleType
        );

        const nearbyDriverIds = await redisClient.georadius(
          'drivers:geo',
          pickupLngNum,
          pickupLatNum,
          5,
          'km'
        );

        const allNearbyDrivers: any[] = [];
        if (nearbyDriverIds.length > 0) {
          const pipeline = redisClient.pipeline();
          nearbyDriverIds.forEach((id) => pipeline.hgetall(`driver:data:${id}`));
          const results = await pipeline.exec();
          if (results) {
            for (const [err, data] of results) {
              if (!err && data && Object.keys(data as any).length > 0) {
                const d = data as Record<string, string>;
                const dist = getDistanceKm(pickupLatNum, pickupLngNum, parseFloat(d.lat), parseFloat(d.lng));
                let exclusionReason: string | null = null;

                if (d.status !== 'ONLINE' && d.status !== 'IDLE') {
                  exclusionReason = `Status is '${d.status}' (Must be ONLINE or IDLE)`;
                } else if (d.vehicleType.toLowerCase() !== trip.vehicleType.toLowerCase()) {
                  exclusionReason = `Vehicle mismatch: requested '${trip.vehicleType}', driver is '${d.vehicleType}'`;
                }

                const candidateMatch = scoredCandidates.find((c) => c.id === d.driverId);

                allNearbyDrivers.push({
                  driverId: d.driverId,
                  name: d.name,
                  vehicleNumber: d.vehicleNumber,
                  vehicleType: d.vehicleType,
                  status: d.status,
                  rating: parseFloat(d.rating || '5.0'),
                  distance: Math.round(dist * 100) / 100,
                  score: candidateMatch ? candidateMatch.score : null,
                  eta: candidateMatch ? candidateMatch.eta : Math.round(dist * 2.0 * 10) / 10,
                  isSelected: scoredCandidates.length > 0 && scoredCandidates[0].id === d.driverId,
                  exclusionReason,
                });
              }
            }
          }
        }

        queueDetails.push({
          tripId: trip.id,
          riderId: trip.riderId,
          riderName: trip.rider?.name || 'Rider',
          riderPhone: trip.rider?.phone || '',
          vehicleType: trip.vehicleType,
          pickupAddress: trip.pickupAddress,
          dropoffAddress: trip.dropoffAddress,
          pickupLat: pickupLatNum,
          pickupLng: pickupLngNum,
          estimatedFare: Number(trip.estimatedFare),
          createdAt: trip.createdAt,
          candidatesCount: scoredCandidates.length,
          topMatchedDriver: scoredCandidates.length > 0 ? scoredCandidates[0] : null,
          allCandidates: allNearbyDrivers.sort((a, b) => (b.score || 0) - (a.score || 0)),
        });
      }

      return reply.code(200).send({
        status: 'success',
        count: queueDetails.length,
        queue: queueDetails,
      });
    } catch (err: any) {
      logger.error(err, 'Error in GET /api/admin/matching/queue');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 4. GET /api/admin/trips/:id/timeline - Detailed dispatch & event audit timeline
  server.get('/api/admin/trips/:id/timeline', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);
      const { id } = request.params as any;

      const trip = await prisma.trip.findUnique({
        where: { id },
        include: {
          rider: { select: { name: true, phone: true } },
          driver: { select: { name: true, phone: true } },
        },
      });

      if (!trip) {
        return reply.code(404).send({ error: `Trip not found: ${id}` });
      }

      const timeline: any[] = [];
      const baseTime = trip.createdAt.getTime();

      timeline.push({
        step: '1. Ride Requested',
        timestamp: new Date(baseTime).toISOString(),
        detail: `Rider ${trip.rider?.name || trip.riderId} requested a ${trip.vehicleType} ride for ₹${trip.estimatedFare}`,
        status: 'completed',
      });

      timeline.push({
        step: '2. Matching Engine Evaluated Candidates',
        timestamp: new Date(baseTime + 200).toISOString(),
        detail: `Geospatial 5km radius query executed. Go Matching Engine scored candidate drivers.`,
        status: 'completed',
      });

      if (trip.driverId || trip.status !== 'REQUESTED') {
        timeline.push({
          step: '3. Dispatch Notification Sent',
          timestamp: new Date(baseTime + 400).toISOString(),
          detail: `Incoming dispatch pushed via Redis Pub/Sub & FCM to Driver ${trip.driver?.name || trip.driverId}`,
          status: 'completed',
        });
      } else {
        timeline.push({
          step: '3. Searching Active Drivers...',
          timestamp: new Date(baseTime + 500).toISOString(),
          detail: `Broadcasting dispatch to nearby drivers`,
          status: 'in_progress',
        });
      }

      if (['ASSIGNED', 'ARRIVED', 'IN_PROGRESS', 'COMPLETED'].includes(trip.status)) {
        timeline.push({
          step: '4. Driver Accepted',
          timestamp: new Date(baseTime + 3500).toISOString(),
          detail: `Driver ${trip.driver?.name || trip.driverId} accepted ride. Status set to ASSIGNED.`,
          status: 'completed',
        });
      }

      if (['ARRIVED', 'IN_PROGRESS', 'COMPLETED'].includes(trip.status)) {
        timeline.push({
          step: '5. Driver Arrived at Pickup',
          timestamp: new Date(baseTime + 180000).toISOString(),
          detail: `Driver reached pickup location (${trip.pickupAddress})`,
          status: 'completed',
        });
      }

      if (['IN_PROGRESS', 'COMPLETED'].includes(trip.status)) {
        timeline.push({
          step: '6. OTP Verified & Trip Started',
          timestamp: trip.startedAt ? trip.startedAt.toISOString() : new Date(baseTime + 240000).toISOString(),
          detail: `OTP ${trip.riderOtp} verified. Trip status set to IN_PROGRESS`,
          status: 'completed',
        });
      }

      if (trip.status === 'COMPLETED') {
        timeline.push({
          step: '7. Trip Completed',
          timestamp: trip.completedAt ? trip.completedAt.toISOString() : new Date(baseTime + 900000).toISOString(),
          detail: `Trip completed successfully. Final Fare: ₹${trip.finalFare || trip.estimatedFare}`,
          status: 'completed',
        });
      }

      if (trip.status === 'CANCELLED') {
        timeline.push({
          step: 'Trip Cancelled',
          timestamp: new Date().toISOString(),
          detail: `Trip cancelled by ${trip.cancelledBy || 'system'}. Reason: ${trip.cancellationReason || 'User cancelled'}`,
          status: 'cancelled',
        });
      }

      return reply.code(200).send({
        status: 'success',
        tripId: trip.id,
        currentStatus: trip.status,
        timeline,
      });
    } catch (err: any) {
      logger.error(err, 'Error in GET /api/admin/trips/:id/timeline');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 5. GET /api/admin/system/health - WebSocket, Redis & Go Engine health
  server.get('/api/admin/system/health', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);

      let redisStatus = 'disconnected';
      try {
        const ping = await redisClient.ping();
        if (ping === 'PONG') redisStatus = 'healthy';
      } catch (_) {}

      let dbStatus = 'disconnected';
      try {
        await prisma.$queryRaw`SELECT 1`;
        dbStatus = 'healthy';
      } catch (_) {}

      const goEnginePath = path.join(process.cwd(), 'matching-engine', 'matching-engine');
      let goEngineStatus = 'missing';
      if (fs.existsSync(goEnginePath)) {
        goEngineStatus = 'ready (binary compiled)';
      } else {
        goEngineStatus = 'using TypeScript fallback algorithm';
      }

      return reply.code(200).send({
        status: 'success',
        system: {
          redis: redisStatus,
          database: dbStatus,
          goMatchingEngine: goEngineStatus,
          activeSocketsCount: memoryStore.localSockets.size,
          activeRiderSubscriptionsCount: activeRiderSubscriptions.size,
          serverUptime: Math.round(process.uptime()),
          nodeVersion: process.version,
        },
      });
    } catch (err: any) {
      logger.error(err, 'Error in GET /api/admin/system/health');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 6. GET /api/admin/users - Get all users/drivers
  server.get('/api/admin/users', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);

      const users = await prisma.user.findMany({
        include: { driverProfile: true },
        orderBy: { createdAt: 'desc' },
      });

      return reply.code(200).send({
        status: 'success',
        users: users.map((u) => ({
          id: u.id,
          name: u.name || (u.role === 'DRIVER' ? 'Driver' : 'Rider'),
          phone: u.phone,
          role: u.role,
          status: u.status,
          kycStatus: u.driverProfile?.kycStatus || 'N/A',
          joinedAt: u.createdAt,
        })),
      });
    } catch (err: any) {
      logger.error(err, 'Error in GET /api/admin/users');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 7. POST /api/admin/users/:userId/activate - Activate driver or user
  server.post('/api/admin/users/:userId/activate', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);
      const { userId } = request.params as { userId: string };

      const user = await prisma.user.update({
        where: { id: userId },
        data: { status: 'ACTIVE' },
      });

      if (user.role === 'DRIVER') {
        await prisma.driverProfile.upsert({
          where: { driverId: userId },
          update: { kycStatus: 'APPROVED' },
          create: {
            driverId: userId,
            vehicleType: 'Bike',
            licencePlate: 'DL01ACTIVATED',
            kycStatus: 'APPROVED',
          },
        });

        // Also update Redis driver data hash if present
        const driverKey = `driver:data:${userId}`;
        const existingData = await redisClient.hgetall(driverKey);
        if (existingData && Object.keys(existingData).length > 0) {
          await redisClient.hset(driverKey, 'status', 'ONLINE');
        }
      }

      return reply.code(200).send({ status: 'success', message: 'User/Driver activated successfully', user });
    } catch (err: any) {
      logger.error(err, 'Error in POST /api/admin/users/:userId/activate');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });

  // 8. POST /api/admin/users/:userId/suspend - Suspend driver or user
  server.post('/api/admin/users/:userId/suspend', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      requireAdmin(request);
      const { userId } = request.params as { userId: string };

      const user = await prisma.user.update({
        where: { id: userId },
        data: { status: 'SUSPENDED' },
      });

      if (user.role === 'DRIVER') {
        await prisma.driverProfile.updateMany({
          where: { driverId: userId },
          data: { kycStatus: 'SUSPENDED' },
        });

        const driverKey = `driver:data:${userId}`;
        await redisClient.hset(driverKey, 'status', 'OFFLINE');
        try {
          await redisClient.zrem('drivers:geo', userId);
        } catch (_) {}
      }

      return reply.code(200).send({ status: 'success', message: 'User/Driver suspended successfully', user });
    } catch (err: any) {
      logger.error(err, 'Error in POST /api/admin/users/:userId/suspend');
      return reply.code(err.message === 'Admin access required' ? 403 : 500).send({ error: err.message });
    }
  });
}
