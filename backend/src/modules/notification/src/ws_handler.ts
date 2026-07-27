import { FastifyRequest } from 'fastify';
import { logger } from '../../../shared/logger';
import { memoryStore } from '../../../state/memory_store';
import { TripService } from '../../trip';
import { MatchingService } from '../../matching';
import { getDistanceKm } from '../../pricing';
import { prisma } from '../../../shared/prisma';
import { redisClient } from '../../../shared/redis';
import { PubSubService } from './pubsub_service';

export const activeRiderSubscriptions = new Map<string, { socket: any, lat: number, lng: number }>();

function broadcastNearbyDriversToRiders() {
  for (const [riderId, sub] of activeRiderSubscriptions.entries()) {
    if (sub.socket.readyState === 1) {
      sendNearbyDrivers(riderId, sub.lat, sub.lng, sub.socket);
    } else {
      activeRiderSubscriptions.delete(riderId);
    }
  }
}

async function sendNearbyDrivers(riderId: string, riderLat: number, riderLng: number, socket: any) {
  try {
    const nearbyDriverIds = await redisClient.georadius(
      'drivers:geo',
      riderLng,
      riderLat,
      3.0,
      'km'
    );

    if (nearbyDriverIds.length === 0) return;

    const nearby: any[] = [];
    const pipeline = redisClient.pipeline();
    nearbyDriverIds.forEach(id => {
      pipeline.hgetall(`driver:data:${id}`);
    });
    
    const results = await pipeline.exec();
    if (results) {
      for (const [err, data] of results) {
        if (!err && data && Object.keys(data).length > 0) {
          const driver = data as Record<string, string>;
          if (driver.status === 'ONLINE' || driver.status === 'IDLE') {
            nearby.push({
              id: driver.driverId,
              name: driver.name,
              lat: parseFloat(driver.lat),
              lng: parseFloat(driver.lng),
              vehicleType: driver.vehicleType,
              heading: parseFloat(driver.heading || '0'),
            });
          }
        }
      }
    }

    socket.send(JSON.stringify({
      type: 'nearby_drivers',
      drivers: nearby
    }));
  } catch (e) {
    logger.error({ e, riderId }, 'Failed to send nearby drivers to rider socket');
  }
}

export async function handleWebSocketConnection(connection: any, request: FastifyRequest) {
  logger.info({ 
    connectionType: typeof connection,
    hasSocket: !!(connection && connection.socket),
    keys: connection ? Object.keys(connection) : [],
    requestType: typeof request
  }, 'handleWebSocketConnection arguments check');

  const socket = connection?.socket || connection;
  const socketId = `socket-${Math.random().toString(36).substr(2, 9)}`;
  const user = (request as any).user;
  
  if (!user) {
    logger.error('No authenticated user found for WebSocket connection');
    socket.close(1008, 'Unauthorized');
    return;
  }

  let registeredId: string = user.userId;
  let registeredRole: 'RIDER' | 'DRIVER' | null = user.role;

  logger.info({ socketId, userId: registeredId, role: registeredRole }, 'New WebSocket connection established');

  socket.on('message', async (rawMessage: any) => {
    try {
      const message = JSON.parse(rawMessage.toString());
      logger.info({ socketId, message }, 'Received WebSocket message');

      const { type } = message;

      if (type === 'register_driver') {
        if (registeredRole !== 'DRIVER') {
           socket.send(JSON.stringify({ error: 'Unauthorized role' }));
           return;
        }
        
        // Detect vehicle type based on vehicle name
        const vehicleName = message.vehicleName || 'Bajaj Pulsar 150';
        let vehicleType = 'bike';
        if (vehicleName.toLowerCase().includes('auto')) {
          vehicleType = 'auto';
        } else if (vehicleName.toLowerCase().includes('cab') || vehicleName.toLowerCase().includes('car') || vehicleName.toLowerCase().includes('swift')) {
          vehicleType = 'cab';
        }

        const lat = message.driverLat || 26.8467;
        const lng = message.driverLng || 80.9462;

        const pipeline = redisClient.pipeline();
        pipeline.geoadd('drivers:geo', lng, lat, registeredId);
        pipeline.hset(`driver:data:${registeredId}`, {
          driverId: registeredId,
          name: message.driverName || 'Vikram Singh',
          phone: message.driverPhone || '+918888888888',
          vehicleNumber: message.vehicleNumber || 'UP32-AB-9999',
          vehicleName: vehicleName,
          vehicleType: vehicleType,
          lat: lat.toString(),
          lng: lng.toString(),
          status: 'ONLINE',
          rating: '4.8',
          acceptanceRate: '0.9',
          cancellationRate: '0.05',
          lastSeen: Date.now().toString(),
        });
        await pipeline.exec();

        memoryStore.setSocket(registeredId, socket);
        logger.info({ driverId: registeredId, vehicleType }, 'Driver registered successfully in Redis');
        
        socket.send(JSON.stringify({ type: 'registered', status: 'success', driverId: registeredId }));
        return;
      }

      if (type === 'request_ride') {
        if (registeredRole !== 'RIDER') {
           socket.send(JSON.stringify({ error: 'Unauthorized role' }));
           return;
        }
        memoryStore.setSocket(registeredId, socket);

        const { pickupLat, pickupLng, destLat, destLng, vehicleName, price } = message;
        
        let targetType = 'bike';
        if (vehicleName?.toLowerCase().includes('auto')) {
          targetType = 'auto';
        } else if (vehicleName?.toLowerCase().includes('cab') || vehicleName?.toLowerCase().includes('car') || vehicleName?.toLowerCase().includes('prime')) {
          targetType = 'cab';
        }

        logger.info({ riderId: registeredId, targetType }, 'Rider requesting a ride');

        // Create the trip in status REQUESTED
        const trip = await TripService.createTrip({
          riderId: registeredId,
          pickupLat,
          pickupLng,
          pickupAddress: message.pickupAddress || 'Hazratganj, Lucknow',
          dropoffLat: destLat,
          dropoffLng: destLng,
          dropoffAddress: message.dropoffAddress || 'Lucknow Airport (LKO)',
          price: price || 150.0,
          vehicleType: targetType,
        });

        // Query matching engine for available drivers
        const matchedDrivers = await MatchingService.findDrivers(pickupLat, pickupLng, targetType);

        if (matchedDrivers.length > 0) {
          const bestDriver = matchedDrivers[0];

          // Use Pub/Sub to send dispatch request to driver across instances
          await PubSubService.publishToUser(bestDriver.id, {
            type: 'incoming_dispatch',
            tripId: trip.id,
            riderName: trip.riderName,
            riderPhone: trip.riderPhone,
            pickupAddress: trip.pickupAddress,
            dropoffAddress: trip.dropoffAddress,
            pickupLat: trip.pickupLat,
            pickupLng: trip.pickupLng,
            dropoffLat: trip.dropoffLat,
            dropoffLng: trip.dropoffLng,
            price: trip.price,
            otp: trip.otp,
          });

          // FCM Push
          const { FcmService } = await import('./fcm_service');
          FcmService.sendPushNotification(
            bestDriver.id,
            'New Ride Request',
            `Pickup at ${trip.pickupAddress} for ₹${trip.price}`,
            { tripId: trip.id }
          ).catch(e => logger.error(e));

          logger.info({ driverId: bestDriver.id, tripId: trip.id }, 'Dispatched trip to online driver via Redis PubSub and FCM');
        } else {
          logger.warn('No active drivers connected.');
          socket.send(JSON.stringify({
            type: 'no_drivers_available',
            message: 'No drivers available in your area.'
          }));
        }
        return;
      }

      if (type === 'subscribe_nearby') {
        if (registeredRole !== 'RIDER') {
           socket.send(JSON.stringify({ error: 'Unauthorized role' }));
           return;
        }
        memoryStore.setSocket(registeredId, socket);
        
        const { latitude, longitude } = message;
        activeRiderSubscriptions.set(registeredId, { socket, lat: latitude, lng: longitude });
        sendNearbyDrivers(registeredId, latitude, longitude, socket);
        return;
      }

      if (type === 'driver_location_update') {
        const { latitude, longitude, heading } = message;
        if (registeredId !== '') {
          await MatchingService.updateDriverLocation(registeredId, latitude, longitude, heading);
          
          // Broadcast to all subscribed riders since a driver location has changed!
          broadcastNearbyDriversToRiders();

          // Find active trip to notify rider of ETA updates
          const activeTrip = await prisma.trip.findFirst({
            where: {
              driverId: registeredId,
              status: { in: ['ASSIGNED', 'ARRIVED', 'IN_PROGRESS'] },
            },
          });

          if (activeTrip) {
            // Use Pub/Sub to send location update to rider across instances
            await PubSubService.publishToUser(activeTrip.riderId, {
              type: 'location_update',
              lat: latitude,
              lng: longitude,
              eta: activeTrip.status === 'IN_PROGRESS' ? '8 mins' : '2 mins',
            });
            // Note: Trip lifecycle transitions (ARRIVED, IN_PROGRESS, COMPLETED)
            // are now exclusively handled by explicit Driver REST API endpoints.
          }
        }
        return;
      }
    } catch (e) {
      logger.error({ e, rawMessage: rawMessage.toString() }, 'Failed to parse WebSocket message');
    }
  });

  socket.on('error', (err: any) => {
    logger.error({ socketId, err }, 'WebSocket error encountered');
  });

  return new Promise<void>((resolve) => {
    socket.on('close', () => {
      logger.info({ socketId, registeredId, registeredRole }, 'WebSocket connection closed');
      if (registeredId !== '') {
        memoryStore.removeSocket(registeredId);
        activeRiderSubscriptions.delete(registeredId);
        if (registeredRole === 'DRIVER') {
          MatchingService.setDriverAvailability(registeredId, 'OFFLINE');
        }
      }
      resolve();
    });
  });
}
