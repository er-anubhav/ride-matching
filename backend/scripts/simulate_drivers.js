const WebSocket = require('ws');
const http = require('http');

const UPDATE_INTERVAL = 3000; // 3 seconds
const DRIVERS_PER_RIDER = 3;

// Map of riderId -> { lat, lng, drivers: Array<{ driverId, ws, lat, lng, intervalId }> }
const activeConnections = new Map();

function fetchRiderLocations() {
  return new Promise((resolve) => {
    http.get('http://localhost:8080/api/system/rider-locations', (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve([]);
        }
      });
    }).on('error', () => {
      resolve([]);
    });
  });
}

function startDriverForRider(riderId, index, startLat, startLng) {
  const driverId = `driver-sim-${riderId.substring(0, 6)}-${index}`;
  const driverName = `Simulated Driver ${index}`;
  const vehicleNumber = `UP32-SIM-${Math.floor(1000 + Math.random() * 9000)}`;
  
  const vehicleTypes = ['bike', 'auto', 'cab'];
  const vehicleType = vehicleTypes[index % 3];
  const vehicleName = vehicleType === 'bike' ? 'Hero Splendor' : vehicleType === 'auto' ? 'RE Auto' : 'Maruti Swift';

  // Spawn simulated drivers spaced out on roads: between 0.005 (500m) and 0.015 (1.5km) away
  const minDist = 0.005;
  const maxDist = 0.015;
  // Spread them evenly in a circle to prevent overlapping (e.g., 120 degrees apart for 3 drivers)
  const angle = (index * (2 * Math.PI / 3)) + (Math.random() * 0.5);
  const dist = minDist + Math.random() * (maxDist - minDist);
  
  let lat = startLat + dist * Math.sin(angle);
  let lng = startLng + dist * Math.cos(angle);

  // Grid simulation: move along straight horizontal or vertical lines (streets)
  let direction = Math.random() > 0.5 ? 0 : 1; // 0 = Lat (N/S), 1 = Lng (E/W)
  let sign = Math.random() > 0.5 ? 1 : -1;
  const speed = 0.0006; // ~60m per step (realistic street speed)
  let stepsToTurn = Math.floor(4 + Math.random() * 6);

  const wsUrl = `ws://localhost:8080/ride-tracking?driverId=${driverId}`;
  const ws = new WebSocket(wsUrl);
  
  const connectionInfo = {
    driverId,
    ws,
    lat,
    lng,
    intervalId: null
  };

  ws.on('open', () => {
    ws.send(JSON.stringify({
      type: 'register_driver',
      driverName: driverName,
      vehicleNumber: vehicleNumber,
      vehicleName: vehicleName,
      driverLat: lat,
      driverLng: lng
    }));
  });

  ws.on('message', (data) => {
    try {
      const msg = JSON.parse(data);
      if (msg.type === 'registered') {
        // Start updates
        connectionInfo.intervalId = setInterval(() => {
          const riderConnection = activeConnections.get(riderId);
          if (riderConnection) {
            const targetLat = riderConnection.lat;
            const targetLng = riderConnection.lng;

            // Move along current street direction
            if (direction === 0) {
              connectionInfo.lat += sign * speed;
            } else {
              connectionInfo.lng += sign * speed;
            }

            stepsToTurn--;
            if (stepsToTurn <= 0) {
              // Turn at street intersection
              direction = direction === 0 ? 1 : 0;
              sign = Math.random() > 0.5 ? 1 : -1;
              stepsToTurn = Math.floor(4 + Math.random() * 6);
            }

            // Keep driver within a 2.5km boundary from the rider
            const distFromRider = Math.sqrt(Math.pow(connectionInfo.lat - targetLat, 2) + Math.pow(connectionInfo.lng - targetLng, 2));
            if (distFromRider > 0.025) {
              // Force direction turn back towards rider
              if (direction === 0) {
                sign = connectionInfo.lat < targetLat ? 1 : -1;
              } else {
                sign = connectionInfo.lng < targetLng ? 1 : -1;
              }
            }

            let heading = 0;
            if (direction === 0) {
              heading = sign > 0 ? 0 : 180;
            } else {
              heading = sign > 0 ? 90 : 270;
            }

            ws.send(JSON.stringify({
              type: 'driver_location_update',
              latitude: connectionInfo.lat,
              longitude: connectionInfo.lng,
              heading: heading
            }));
          }
        }, UPDATE_INTERVAL);
      }
    } catch (e) {
      console.error(`[${driverId}] Error:`, e);
    }
  });

  ws.on('error', (err) => {
    // Handle error quietly
  });

  ws.on('close', () => {
    if (connectionInfo.intervalId) {
      clearInterval(connectionInfo.intervalId);
    }
  });

  return connectionInfo;
}

async function monitorRiders() {
  try {
    const riders = await fetchRiderLocations();
    const currentRiderIds = new Set(riders.map(r => r.riderId));

    // 1. Clean up drivers for disconnected riders
    for (const riderId of activeConnections.keys()) {
      if (!currentRiderIds.has(riderId)) {
        console.log(`Rider ${riderId} disconnected. Cleaning up simulated drivers.`);
        const riderData = activeConnections.get(riderId);
        riderData.drivers.forEach(d => {
          d.ws.close();
        });
        activeConnections.delete(riderId);
      }
    }

    // 2. Add or update drivers for active riders
    for (const rider of riders) {
      if (activeConnections.has(rider.riderId)) {
        const riderData = activeConnections.get(rider.riderId);
        riderData.lat = rider.lat;
        riderData.lng = rider.lng;
      } else {
        console.log(`New active rider detected: ${rider.riderId} at ${rider.lat}, ${rider.lng}. Spawning ${DRIVERS_PER_RIDER} drivers.`);
        const driverConns = [];
        for (let i = 1; i <= DRIVERS_PER_RIDER; i++) {
          driverConns.push(startDriverForRider(rider.riderId, i, rider.lat, rider.lng));
        }
        activeConnections.set(rider.riderId, {
          lat: rider.lat,
          lng: rider.lng,
          drivers: driverConns
        });
      }
    }
  } catch (err) {
    console.error("Error monitoring active riders:", err);
  }
}

// Start monitor loop
setInterval(monitorRiders, 3000);
console.log("Dynamic multi-rider driver simulation service started.");
