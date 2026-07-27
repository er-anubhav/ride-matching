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
exports.activeRiderSubscriptions = void 0;
exports.handleWebSocketConnection = handleWebSocketConnection;
const logger_1 = require("../../../shared/logger");
const memory_store_1 = require("../../../state/memory_store");
const trip_1 = require("../../trip");
const matching_1 = require("../../matching");
const prisma_1 = require("../../../shared/prisma");
const redis_1 = require("../../../shared/redis");
const pubsub_service_1 = require("./pubsub_service");
exports.activeRiderSubscriptions = new Map();
function broadcastNearbyDriversToRiders() {
    for (const [riderId, sub] of exports.activeRiderSubscriptions.entries()) {
        if (sub.socket.readyState === 1) {
            sendNearbyDrivers(riderId, sub.lat, sub.lng, sub.socket);
        }
        else {
            exports.activeRiderSubscriptions.delete(riderId);
        }
    }
}
async function sendNearbyDrivers(riderId, riderLat, riderLng, socket) {
    try {
        const nearbyDriverIds = await redis_1.redisClient.georadius('drivers:geo', riderLng, riderLat, 3.0, 'km');
        if (nearbyDriverIds.length === 0)
            return;
        const nearby = [];
        const pipeline = redis_1.redisClient.pipeline();
        nearbyDriverIds.forEach(id => {
            pipeline.hgetall(`driver:data:${id}`);
        });
        const results = await pipeline.exec();
        if (results) {
            for (const [err, data] of results) {
                if (!err && data && Object.keys(data).length > 0) {
                    const driver = data;
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
    }
    catch (e) {
        logger_1.logger.error({ e, riderId }, 'Failed to send nearby drivers to rider socket');
    }
}
async function handleWebSocketConnection(connection, request) {
    logger_1.logger.info({
        connectionType: typeof connection,
        hasSocket: !!(connection && connection.socket),
        keys: connection ? Object.keys(connection) : [],
        requestType: typeof request
    }, 'handleWebSocketConnection arguments check');
    const socket = connection?.socket || connection;
    const socketId = `socket-${Math.random().toString(36).substr(2, 9)}`;
    const user = request.user;
    if (!user) {
        logger_1.logger.error('No authenticated user found for WebSocket connection');
        socket.close(1008, 'Unauthorized');
        return;
    }
    let registeredId = user.userId;
    let registeredRole = user.role;
    logger_1.logger.info({ socketId, userId: registeredId, role: registeredRole }, 'New WebSocket connection established');
    socket.on('message', async (rawMessage) => {
        try {
            const message = JSON.parse(rawMessage.toString());
            logger_1.logger.info({ socketId, message }, 'Received WebSocket message');
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
                }
                else if (vehicleName.toLowerCase().includes('cab') || vehicleName.toLowerCase().includes('car') || vehicleName.toLowerCase().includes('swift')) {
                    vehicleType = 'cab';
                }
                const lat = message.driverLat || 26.8467;
                const lng = message.driverLng || 80.9462;
                const pipeline = redis_1.redisClient.pipeline();
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
                memory_store_1.memoryStore.setSocket(registeredId, socket);
                logger_1.logger.info({ driverId: registeredId, vehicleType }, 'Driver registered successfully in Redis');
                socket.send(JSON.stringify({ type: 'registered', status: 'success', driverId: registeredId }));
                return;
            }
            if (type === 'request_ride') {
                if (registeredRole !== 'RIDER') {
                    socket.send(JSON.stringify({ error: 'Unauthorized role' }));
                    return;
                }
                memory_store_1.memoryStore.setSocket(registeredId, socket);
                const { pickupLat, pickupLng, destLat, destLng, vehicleName, price } = message;
                let targetType = 'bike';
                if (vehicleName?.toLowerCase().includes('auto')) {
                    targetType = 'auto';
                }
                else if (vehicleName?.toLowerCase().includes('cab') || vehicleName?.toLowerCase().includes('car') || vehicleName?.toLowerCase().includes('prime')) {
                    targetType = 'cab';
                }
                logger_1.logger.info({ riderId: registeredId, targetType }, 'Rider requesting a ride');
                // Create the trip in status REQUESTED
                const trip = await trip_1.TripService.createTrip({
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
                const matchedDrivers = await matching_1.MatchingService.findDrivers(pickupLat, pickupLng, targetType);
                if (matchedDrivers.length > 0) {
                    const bestDriver = matchedDrivers[0];
                    // Use Pub/Sub to send dispatch request to driver across instances
                    await pubsub_service_1.PubSubService.publishToUser(bestDriver.id, {
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
                    const { FcmService } = await Promise.resolve().then(() => __importStar(require('./fcm_service')));
                    FcmService.sendPushNotification(bestDriver.id, 'New Ride Request', `Pickup at ${trip.pickupAddress} for ₹${trip.price}`, { tripId: trip.id }).catch(e => logger_1.logger.error(e));
                    logger_1.logger.info({ driverId: bestDriver.id, tripId: trip.id }, 'Dispatched trip to online driver via Redis PubSub and FCM');
                }
                else {
                    logger_1.logger.warn('No active drivers connected.');
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
                memory_store_1.memoryStore.setSocket(registeredId, socket);
                const { latitude, longitude } = message;
                exports.activeRiderSubscriptions.set(registeredId, { socket, lat: latitude, lng: longitude });
                sendNearbyDrivers(registeredId, latitude, longitude, socket);
                return;
            }
            if (type === 'driver_location_update') {
                const { latitude, longitude, heading } = message;
                if (registeredId !== '') {
                    await matching_1.MatchingService.updateDriverLocation(registeredId, latitude, longitude, heading);
                    // Broadcast to all subscribed riders since a driver location has changed!
                    broadcastNearbyDriversToRiders();
                    // Find active trip to notify rider of ETA updates
                    const activeTrip = await prisma_1.prisma.trip.findFirst({
                        where: {
                            driverId: registeredId,
                            status: { in: ['ASSIGNED', 'ARRIVED', 'IN_PROGRESS'] },
                        },
                    });
                    if (activeTrip) {
                        // Use Pub/Sub to send location update to rider across instances
                        await pubsub_service_1.PubSubService.publishToUser(activeTrip.riderId, {
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
        }
        catch (e) {
            logger_1.logger.error({ e, rawMessage: rawMessage.toString() }, 'Failed to parse WebSocket message');
        }
    });
    socket.on('error', (err) => {
        logger_1.logger.error({ socketId, err }, 'WebSocket error encountered');
    });
    return new Promise((resolve) => {
        socket.on('close', () => {
            logger_1.logger.info({ socketId, registeredId, registeredRole }, 'WebSocket connection closed');
            if (registeredId !== '') {
                memory_store_1.memoryStore.removeSocket(registeredId);
                exports.activeRiderSubscriptions.delete(registeredId);
                if (registeredRole === 'DRIVER') {
                    matching_1.MatchingService.setDriverAvailability(registeredId, 'OFFLINE');
                }
            }
            resolve();
        });
    });
}
