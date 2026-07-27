# Mobile API Integration Reference

## REST API Endpoints Used

### 1. Authentication
- `POST /api/auth/otp/request`: Request 4-digit SMS OTP verification code.
- `POST /api/auth/otp/verify`: Verify OTP code and issue JWT token (`token`).

### 2. Pricing & Route Engine (Ola Maps)
- `POST /api/pricing/estimate`: Calculate distance, duration, and fare across vehicle categories (Bike, Auto, Cab) using Ola Maps API (`https://api.olamaps.io/routing/v1/directions`).

### 3. Trip Lifecycle
- `POST /api/trips`: Request ride creation.
- `GET /api/trips/history`: Retrieve user's past completed/cancelled trips.
- `POST /api/trips/:id/accept`: Driver accepts dispatch offer.
- `POST /api/trips/:id/arrive`: Driver marks arrival at pickup point.
- `POST /api/trips/:id/start`: Start trip using rider OTP code verification.
- `POST /api/trips/:id/complete`: Complete trip and register cash fare collection.

### 4. KYC & Document Uploads (Cloudflare R2)
- `POST /api/kyc/upload-url`: Request pre-signed Cloudflare R2 upload URL for document types (`DL`, `AADHAAR_FRONT`, `RC`, `SELFIE`).

---

## Real-Time WebSocket Events (`/ws`)

### Client → Server Events
- `register_driver`: Register active driver with vehicle metrics.
- `LOCATION_UPDATE`: Stream driver latitude, longitude, and heading.
- `PING`: Keep-alive ping packet sent every 25s.

### Server → Client Events
- `incoming_dispatch`: Push new trip request offer to candidate driver.
- `DRIVER_LOCATION_UPDATE`: Stream driver coordinates to active rider tracking map.
- `TRIP_STATUS_CHANGED`: Broadcast status updates (`ASSIGNED`, `ARRIVED`, `IN_PROGRESS`, `COMPLETED`).
