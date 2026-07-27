"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.MatchingService = void 0;
const child_process_1 = require("child_process");
const path_1 = __importDefault(require("path"));
const logger_1 = require("../../../shared/logger");
const pricing_1 = require("../../pricing");
const redis_1 = require("../../../shared/redis");
class MatchingService {
    /**
     * Spawns Go matching-engine binary or performs local TS fallback scoring
     */
    static async findDrivers(pickupLat, pickupLng, vehicleType) {
        // 1. Gather all online/idle drivers of the matching vehicle type from Redis within 5km
        const radiusKm = 5;
        // Format: georadius drivers:geo <lng> <lat> 5 km
        const nearbyDriverIds = await redis_1.redisClient.georadius('drivers:geo', pickupLng, pickupLat, radiusKm, 'km');
        if (nearbyDriverIds.length === 0) {
            logger_1.logger.info(`No nearby drivers found for vehicleType: ${vehicleType}`);
            return [];
        }
        const availableDrivers = [];
        // Pipelining to fetch all driver metadata efficiently
        const pipeline = redis_1.redisClient.pipeline();
        nearbyDriverIds.forEach(driverId => {
            pipeline.hgetall(`driver:data:${driverId}`);
        });
        const results = await pipeline.exec();
        if (results) {
            for (const [err, data] of results) {
                if (!err && data && Object.keys(data).length > 0) {
                    const driver = data;
                    // Reconstruct types from Redis string representations
                    if ((driver.status === 'ONLINE' || driver.status === 'IDLE') &&
                        driver.vehicleType.toLowerCase() === vehicleType.toLowerCase()) {
                        availableDrivers.push({
                            driverId: driver.driverId,
                            name: driver.name,
                            phone: driver.phone,
                            vehicleNumber: driver.vehicleNumber,
                            vehicleName: driver.vehicleName,
                            vehicleType: driver.vehicleType,
                            lat: parseFloat(driver.lat),
                            lng: parseFloat(driver.lng),
                            status: driver.status,
                            rating: parseFloat(driver.rating),
                            acceptanceRate: parseFloat(driver.acceptanceRate),
                            cancellationRate: parseFloat(driver.cancellationRate),
                            lastSeen: parseInt(driver.lastSeen, 10),
                        });
                    }
                }
            }
        }
        if (availableDrivers.length === 0) {
            logger_1.logger.info(`No active online drivers available for vehicleType: ${vehicleType}`);
            return [];
        }
        // 2. Try running through the Go core binary via Stdin IPC
        const goBinaryPath = path_1.default.join(__dirname, '../../../../matching-engine/matching-engine');
        try {
            const matchResults = await this.queryGoEngine(goBinaryPath, pickupLat, pickupLng, availableDrivers);
            logger_1.logger.info({ resultsCount: matchResults.length }, 'Successfully matched drivers using Go binary');
            return matchResults;
        }
        catch (err) {
            logger_1.logger.warn('Go matching engine unavailable, falling back to TypeScript matching core logic');
            // 3. Fallback: Pure TypeScript implementation of the exact same algorithm
            const fallbackResults = availableDrivers.map((d) => {
                const distance = (0, pricing_1.getDistanceKm)(pickupLat, pickupLng, d.lat, d.lng);
                let etaMinutes = distance * 2.0;
                if (etaMinutes < 1.0)
                    etaMinutes = 1.0;
                const etaScore = 1.0 / (1.0 + etaMinutes);
                const ratingScore = d.rating / 5.0;
                const acceptanceScore = d.acceptanceRate;
                const cancellationScore = 1.0 - d.cancellationRate;
                // PRD Driver Scoring: score = (0.40 * eta) + (0.25 * rating) + (0.20 * accept) + (0.15 * cancel)
                const score = 0.4 * etaScore +
                    0.25 * ratingScore +
                    0.2 * acceptanceScore +
                    0.15 * cancellationScore;
                return {
                    id: d.driverId,
                    lat: d.lat,
                    lng: d.lng,
                    score: Math.round(score * 1000) / 1000,
                    distance: Math.round(distance * 100) / 100,
                    eta: Math.round(etaMinutes * 10) / 10,
                };
            });
            // Sort descending by score
            fallbackResults.sort((a, b) => b.score - a.score);
            // Return top 3
            return fallbackResults.slice(0, 3);
        }
    }
    static queryGoEngine(binaryPath, pickupLat, pickupLng, drivers) {
        return new Promise((resolve, reject) => {
            const child = (0, child_process_1.spawn)(binaryPath);
            let stdoutData = '';
            let stderrData = '';
            child.stdout.on('data', (data) => {
                stdoutData += data.toString();
            });
            child.stderr.on('data', (data) => {
                stderrData += data.toString();
            });
            child.on('close', (code) => {
                if (code !== 0) {
                    reject(new Error(`Go binary exited with code ${code}. Stderr: ${stderrData}`));
                    return;
                }
                try {
                    const parsed = JSON.parse(stdoutData.trim());
                    if (parsed.status === 'error') {
                        reject(new Error(parsed.error));
                        return;
                    }
                    resolve(parsed.results || []);
                }
                catch (e) {
                    reject(new Error(`Failed to parse Go binary output: ${stdoutData}. Error: ${e}`));
                }
            });
            child.on('error', (err) => {
                reject(err);
            });
            // Write payload input line to stdin
            const payload = {
                action: 'score_drivers',
                pickupLat,
                pickupLng,
                drivers: drivers.map((d) => ({
                    id: d.driverId,
                    lat: d.lat,
                    lng: d.lng,
                    rating: d.rating,
                    acceptanceRate: d.acceptanceRate,
                    cancellationRate: d.cancellationRate,
                    vehicleType: d.vehicleType,
                })),
            };
            child.stdin.write(JSON.stringify(payload) + '\n');
            child.stdin.end();
        });
    }
    static async updateDriverLocation(driverId, lat, lng, heading) {
        const pipeline = redis_1.redisClient.pipeline();
        pipeline.geoadd('drivers:geo', lng, lat, driverId);
        pipeline.hset(`driver:data:${driverId}`, {
            lat: lat.toString(),
            lng: lng.toString(),
            heading: heading ? heading.toString() : '0',
            lastSeen: Date.now().toString(),
        });
        await pipeline.exec();
        logger_1.logger.debug({ driverId, lat, lng, heading }, 'Driver location updated in Redis');
    }
    static async setDriverAvailability(driverId, status) {
        await redis_1.redisClient.hset(`driver:data:${driverId}`, {
            status,
            lastSeen: Date.now().toString(),
        });
        logger_1.logger.info({ driverId, status }, 'Driver availability status updated in Redis');
    }
}
exports.MatchingService = MatchingService;
