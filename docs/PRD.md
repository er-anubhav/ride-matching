# Product Requirements Document (PRD)
## Ride-Sharing Platform — Modular Monolith

**Version:** 1.0  
**Status:** Active  
**Audience:** AI Agents, Junior Engineers, Tech Leads  
**Last Updated:** June 2026

---

## Table of Contents

1. [Document Purpose & How to Use This PRD](#1-document-purpose--how-to-use-this-prd)
2. [Product Overview](#2-product-overview)
3. [Architecture Decision: Modular Monolith](#3-architecture-decision-modular-monolith)
4. [System Architecture Diagram](#4-system-architecture-diagram)
5. [Module Specifications](#5-module-specifications)
6. [Database Design](#6-database-design)
7. [API Design Standards](#7-api-design-standards)
8. [Real-Time Layer](#8-real-time-layer)
9. [Mobile Applications](#9-mobile-applications)
10. [Infrastructure & DevOps](#10-infrastructure--devops)
11. [Build Stages & Roadmap](#11-build-stages--roadmap)
12. [Non-Functional Requirements](#12-non-functional-requirements)
13. [Regulatory & Compliance](#13-regulatory--compliance)
14. [Glossary](#14-glossary)
15. [Rules for AI Agents & Junior Engineers](#15-rules-for-ai-agents--junior-engineers)

---

## 1. Document Purpose & How to Use This PRD

### Who should read this

This PRD is written for three audiences simultaneously:

- **AI coding agents** — reading this to understand context before generating code, writing tests, or scaffolding modules. Read Section 3, 5, 6, and 15 before generating anything.
- **Junior engineers** — reading this to understand what they are building, why decisions were made, and exactly what "done" looks like for each stage.
- **Tech leads / founder** — reading this to validate scope, catch gaps, and update as decisions evolve.

### How to navigate

- **Starting a new feature?** → Go to Section 5 (Module Specifications) to find which module owns it.
- **Writing a database migration?** → Go to Section 6 (Database Design) for schema rules.
- **Debugging a real-time issue?** → Go to Section 8 (Real-Time Layer).
- **Picking up a sprint task?** → Go to Section 11 (Build Stages) for your current phase deliverables.
- **About to write code?** → Read Section 15 (Rules for AI Agents & Junior Engineers) first. Every time.

### Definition of "done" in this project

A feature is done when:
1. The code is written and passes linting (`npm run lint`)
2. Unit tests exist and pass (`npm run test`)
3. Integration tests pass against a real test database (Testcontainers)
4. API endpoint is documented in the module's `index.ts` public surface
5. A migration file exists for any schema changes
6. The feature works end-to-end in the staging environment

---

## 2. Product Overview

### What we are building

A ride-sharing platform targeting Tier 1 and Tier 2 Indian cities. The platform consists of:

| Product | Description | Target User |
|---|---|---|
| **Rider App** | iOS + Android — book, track, and pay for rides | End consumers |
| **Driver App** | iOS + Android — accept rides, navigate, earn, manage earnings | Driver partners |
| **Admin Dashboard** | Web — operations, pricing, fraud, driver KYC approval | Internal ops team |
| **Partner Portal** | Web — fleet operators managing multiple driver accounts | B2B fleet owners |

### Core user journeys (non-negotiable at launch)

**Rider:** Phone OTP signup → Set pickup & destination → See fare estimate → Request ride → Track driver in real-time → Ride → Pay via UPI / wallet → Rate driver

**Driver:** Phone OTP signup → KYC document upload → Wait for approval → Go online → Receive ride request → Accept / reject → Navigate to rider → Complete ride → View earnings

### Key product principles

1. **Supply first, demand second.** Never open the rider app in a city without at least 300 active drivers. Cold-start failure is existential.
2. **UPI is the primary payment method.** Cash is a fallback, not an afterthought. Card is optional.
3. **Offline-tolerant UI.** Tier 2 connectivity is unreliable. The app must degrade gracefully, not crash.
4. **Safety is a day-1 feature.** SOS button, masked phone numbers, and route deviation alerts ship with v1. Not v2.
5. **Hindi first, English second.** All copy, driver app navigation, and support flows are in Hindi by default.

---

## 3. Architecture Decision: Modular Monolith

### What this means

We are building a **single deployable application** (one Docker image, one process) structured internally as **distinct modules with strict boundaries**. This is not a microservices architecture. It is not a traditional monolith either.

Think of it as: microservices discipline, monolith simplicity.

### Why not microservices

| Concern | Microservices problem | Modular monolith solution |
|---|---|---|
| Team size | 8 services need 8+ owners. We have 5 engineers. | 8 modules, one team, one codebase. |
| Network overhead | Inter-service HTTP adds 2–20ms per hop | Module calls are in-process function calls — zero overhead |
| Distributed transactions | Trip completion needs to update trip + payment atomically. Saga pattern is complex. | Single PostgreSQL transaction handles this trivially. |
| Debugging | Logs across 8 services, distributed tracing required from day 1 | One log stream, one trace per request |
| Deployment | 8 CI/CD pipelines, 8 Docker images, 8 Kubernetes deployments | One pipeline, one image, one deployment |

### The non-negotiable module isolation rules

These rules are what separate a modular monolith from a "big ball of mud." Every engineer must follow them without exception.

**Rule 1 — No cross-module database joins**
Module A must never write a SQL query that JOINs tables owned by Module B. If Module A needs data from Module B, it calls Module B's public TypeScript API.

```
// WRONG — Trip module directly querying auth schema
SELECT t.*, u.name FROM trip.trips t JOIN auth.users u ON t.rider_id = u.id

// CORRECT — Trip module calls Auth module's public API
const rider = await auth.getUser(trip.riderId);
```

**Rule 2 — No cross-module internal imports**
Module A can only import from `modules/moduleB/index.ts`. It must never import from `modules/moduleB/src/anything.ts`. Internal files are private.

```typescript
// WRONG
import { PaymentService } from '../payment/src/payment.service'; // FORBIDDEN

// CORRECT
import { payment } from '../payment'; // only index.ts is the public surface
```

**Rule 3 — Events for side effects**
When Module A's action should trigger a side effect in Module B, Module A emits a domain event. Module B subscribes. Module A does not call Module B directly for side effects.

```typescript
// WRONG — Trip module directly calling Notification module
await notificationService.sendTripAccepted(tripId);

// CORRECT — Trip module emits an event
eventBus.emit('trip.accepted', { tripId, driverId, riderId, eta });
// Notification module subscribes to 'trip.accepted' independently
```

**Rule 4 — Shared kernel is for primitives only**
`/shared` contains: domain types (UserId, TripId), error classes, logger, config loader. It contains NO business logic. If you find yourself putting business logic in `/shared`, it belongs in a module instead.

**Rule 5 — ESLint enforces the boundary**
The `.eslintrc.js` has `import/no-restricted-paths` rules that will fail the lint step if any cross-module internal import is detected. You cannot merge to main if this lint rule fails.

---

## 4. System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Layer                             │
│  [Rider App]  [Driver App]  [Admin Dashboard]  [Partner Portal] │
└──────────────────────────┬──────────────────────────────────────┘
                           │ HTTPS / WebSocket
┌──────────────────────────▼──────────────────────────────────────┐
│              API Gateway (Kong / custom Express router)          │
│        Rate limiting · JWT validation · Route dispatch           │
│              WebSocket upgrade · DDoS via Cloudflare             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│          THE MONOLITH  (Single Node.js / Fastify process)        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Auth module  │  │  Matching    │  │    Trip module       │  │
│  │              │  │  module (Go) │  │  (state machine)     │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Payment     │  │ Notification │  │  Analytics module    │  │
│  │  module      │  │  module      │  │                      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│  ┌──────────────┐  ┌──────────────────────────────────────────┐ │
│  │  Pricing     │  │           KYC module                     │ │
│  │  module      │  │                                          │ │
│  └──────────────┘  └──────────────────────────────────────────┘ │
│  ─────────────────────────────────────────────────────────────  │
│  Internal Event Bus (EventEmitter2 + BullMQ for async/durable)  │
│  ─────────────────────────────────────────────────────────────  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Shared Kernel: types · errors · logger · config         │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Background Workers (BullMQ): KYC · payouts · PDF · sync │   │
│  └──────────────────────────────────────────────────────────┘   │
└────────────────────────────┬────────────────────────────────────┘
                             │
          ┌──────────────────┴──────────────────┐
          │                                     │
┌─────────▼──────────┐               ┌──────────▼──────────┐
│ PostgreSQL (RDS)   │               │  Redis (ElastiCache) │
│ Schema per module  │               │  Geo · sessions      │
│ PgBouncer pooling  │               │  BullMQ · Socket.io  │
└────────────────────┘               └─────────────────────┘

External integrations (all called via vendor adapter layer):
  Mapbox / OSRM — routing & ETA
  MSG91 / Gupshup — OTP & SMS
  Razorpay + Cashfree — payments & payouts
  Digilocker / Vahan / Parivahan — KYC verification
  FCM — push notifications
  AWS S3 — document & photo storage
  ClickHouse — analytics writes
```

---

## 5. Module Specifications

Each module has a defined: **owner scope**, **public API** (what other modules can call), **domain events** (what it emits), and **subscriptions** (what events it listens to).

---

### 5.1 Auth Module

**Directory:** `modules/auth/`  
**Language:** TypeScript  
**Database schema:** `auth.*`

**Purpose:** All user identity — signup, login, session management, device trust.

**Owns these tables:**
- `auth.users`
- `auth.sessions`
- `auth.otp_codes`
- `auth.device_fingerprints`

**Public API (`modules/auth/index.ts`):**

```typescript
sendOtp(phone: string): Promise<void>
verifyOtp(phone: string, code: string): Promise<{ accessToken: string; refreshToken: string; user: User }>
refreshToken(token: string): Promise<{ accessToken: string }>
revokeSession(userId: UserId): Promise<void>
getUser(userId: UserId): Promise<User | null>
getUserByPhone(phone: string): Promise<User | null>
updateUserProfile(userId: UserId, data: UpdateProfileData): Promise<User>
suspendUser(userId: UserId, reason: string): Promise<void>
```

**Emits these events:**
- `user.registered` — when a new user completes OTP for the first time
- `user.logged_in` — on every successful OTP verification
- `user.suspended` — when ops suspends an account

**External dependencies:**
- MSG91 or Gupshup for OTP SMS delivery
- Redis for: OTP rate limiting (max 5 OTPs/phone/hour), session storage, refresh token blocklist

**Implementation notes:**
- JWT access tokens expire in 15 minutes
- Refresh tokens expire in 30 days and are stored as hashed values in Redis
- On refresh token use, rotate the refresh token (new token issued, old invalidated)
- Rate limit OTP sends: max 5 per phone per hour, max 3 attempts per OTP code before it expires
- Device fingerprint (user-agent + device model hash) is stored but not enforced in v1 — stored for fraud analysis

---

### 5.2 Matching Module

**Directory:** `modules/matching/` (TypeScript wrapper) + `matching-engine/` (Go binary)  
**Language:** TypeScript wrapper + Go core  
**Database schema:** None — all state lives in Redis

**Purpose:** Find the best available drivers for a ride request. The most performance-critical module in the system.

**Why Go for the core:**  
Geospatial scoring under concurrent load (thousands of simultaneous match requests) requires low-latency, low-GC computation. Go is 10–20× faster than Node.js for this workload. The Go binary is compiled separately and called via a local Unix domain socket (or subprocess IPC). The TypeScript module wraps the Go binary — rest of the app never knows it's Go.

**Owns these Redis keys:**
```
GEOADD  drivers:available:{vehicleType}   lat lng driverId
HSET    driver:{driverId}:state           status vehicleType lastSeen rating
TTL     driver:{driverId}:state           30s  (must be refreshed by heartbeat)
HSET    match-request:{requestId}         riderId pickup dropoff status
TTL     match-request:{requestId}         90s
```

**Public API (`modules/matching/index.ts`):**

```typescript
findDrivers(pickup: LatLng, vehicleType: VehicleType): Promise<DriverMatch[]>
// Returns top 3 scored drivers within radius, sorted by score

updateDriverLocation(driverId: DriverId, location: LatLng): Promise<void>
// Called every 3s from WebSocket heartbeat handler

setDriverAvailability(driverId: DriverId, status: DriverStatus): Promise<void>
// Status: ONLINE | IDLE | NOTIFIED | ON_TRIP | OFFLINE

notifyDrivers(requestId: string, drivers: DriverMatch[], tripDetails: TripPreview): Promise<void>
// Sends ride request to top 3 drivers via WebSocket + FCM

acknowledgeRequest(driverId: DriverId, requestId: string, decision: 'accept' | 'reject'): Promise<void>
```

**Driver scoring algorithm:**

```
score = (0.40 × eta_score) + (0.25 × rating_score) + (0.20 × acceptance_score) + (0.15 × cancellation_score)

where:
  eta_score          = 1 / (1 + eta_minutes)          [closer = higher score]
  rating_score       = driver_rating / 5.0
  acceptance_score   = acceptance_rate (0.0 to 1.0)
  cancellation_score = 1 - cancellation_rate (0.0 to 1.0)
```

Weights are configurable per city in the pricing config. The Go binary reads weights from a config file that can be hot-reloaded.

**Emits these events:**
- `matching.drivers_found` — when ≥1 driver is available and notified
- `matching.no_drivers_available` — when radius search returns 0 drivers
- `matching.request_expired` — when 90s passes without a driver accepting

**Driver availability state machine:**
```
OFFLINE → ONLINE (driver taps "Go Online")
ONLINE  → IDLE   (GPS heartbeat received, no active request)
IDLE    → NOTIFIED (matching engine sends request)
NOTIFIED → ACCEPTED (driver taps Accept)
NOTIFIED → IDLE (driver taps Reject, or 15s timeout)
ACCEPTED → ON_TRIP (trip starts)
ON_TRIP  → IDLE (trip completes or cancels)
Any state → OFFLINE (heartbeat missing for 30s, or driver taps "Go Offline")
```

---

### 5.3 Trip Module

**Directory:** `modules/trip/`  
**Language:** TypeScript  
**Database schema:** `trip.*`

**Purpose:** Owns the lifecycle of every ride from creation to completion. Implements the trip state machine.

**Owns these tables:**
- `trip.trips` — core trip record
- `trip.trip_events` — immutable audit log of every state transition
- `trip.gps_tracks` — TimescaleDB hypertable for GPS coordinates during rides
- `trip.ratings` — post-trip ratings by both rider and driver
- `trip.cancellations` — cancellation reason and refund eligibility

**Trip state machine:**

```
REQUESTED
    │
    ▼ (matching.drivers_found)
DRIVER_NOTIFIED
    │
    ▼ (driver accepts within 15s)
DRIVER_ACCEPTED
    │
    ▼ (driver taps "Arrived at Pickup")
DRIVER_ARRIVED
    │
    ▼ (driver taps "Start Ride" + rider OTP confirms)
IN_PROGRESS
    │
    ▼ (driver taps "End Ride")
COMPLETED ──→ Payment settlement initiated
    
Any state before IN_PROGRESS → CANCELLED (rider or driver initiated)
IN_PROGRESS → DISPUTED (rare, SOS triggered during ride)
```

**Public API (`modules/trip/index.ts`):**

```typescript
createTrip(riderId: RiderId, pickup: LatLng, dropoff: LatLng, vehicleType: VehicleType): Promise<Trip>
acceptTrip(driverId: DriverId, tripId: TripId): Promise<Trip>
driverArrived(driverId: DriverId, tripId: TripId): Promise<Trip>
startTrip(driverId: DriverId, tripId: TripId, riderOtp: string): Promise<Trip>
endTrip(driverId: DriverId, tripId: TripId, finalLocation: LatLng): Promise<TripSummary>
cancelTrip(initiatorId: UserId, tripId: TripId, reason: CancellationReason): Promise<void>
getTrip(tripId: TripId): Promise<Trip | null>
getTripHistory(userId: UserId, page: number, limit: number): Promise<PaginatedTrips>
addGpsPoint(tripId: TripId, point: GpsPoint): Promise<void>
submitRating(raterId: UserId, tripId: TripId, rating: number, comment?: string): Promise<void>
triggerSos(userId: UserId, tripId: TripId): Promise<void>
```

**Emits these events:**
- `trip.created`
- `trip.driver_accepted` — triggers Notification module to alert rider
- `trip.driver_arrived`
- `trip.started`
- `trip.completed` — triggers Payment module to charge rider
- `trip.cancelled` — triggers Payment module for potential refund
- `trip.sos_triggered` — triggers Notification module for emergency alert

**Subscribes to:**
- `matching.no_drivers_available` → transition trip to FAILED state, notify rider
- `payment.charge_failed` → flag trip for cash collection, notify ops
- `payment.charged_successfully` → mark trip as SETTLED

**Rider OTP for trip start:**
When driver marks "Arrived," a 4-digit OTP is generated and sent to the rider's phone. Driver must enter this OTP in their app to start the trip. Prevents trip start without rider present.

---

### 5.4 Payment Module

**Directory:** `modules/payment/`  
**Language:** TypeScript  
**Database schema:** `payment.*`

**Purpose:** All money movement — charging riders, crediting the platform, paying out drivers.

**Owns these tables:**
- `payment.payments` — each individual charge attempt (idempotent by tripId)
- `payment.wallets` — in-app wallet balances per user
- `payment.wallet_transactions` — ledger of all wallet debits/credits
- `payment.payout_batches` — daily driver payout jobs
- `payment.refunds` — refund records linked to payments

**Public API (`modules/payment/index.ts`):**

```typescript
initiateCharge(tripId: TripId, riderId: RiderId, amount: Money, method: PaymentMethod): Promise<Payment>
processWebhook(gateway: 'razorpay' | 'cashfree', payload: unknown, signature: string): Promise<void>
processRefund(paymentId: PaymentId, amount: Money, reason: string): Promise<Refund>
creditWallet(userId: UserId, amount: Money, description: string): Promise<WalletTransaction>
debitWallet(userId: UserId, amount: Money, tripId: TripId): Promise<WalletTransaction>
getWalletBalance(userId: UserId): Promise<Money>
scheduleDriverPayout(driverId: DriverId, period: DateRange): Promise<PayoutBatch>
getEarnings(driverId: DriverId, period: DateRange): Promise<EarningsSummary>
```

**Subscribes to:**
- `trip.completed` → call `initiateCharge()` with calculated fare
- `trip.cancelled` → call `processRefund()` if rider was pre-charged

**Emits these events:**
- `payment.charge_initiated`
- `payment.charged_successfully`
- `payment.charge_failed`
- `payment.refunded`
- `payment.payout_scheduled`

**Payment gateway failover:**
Primary gateway is Razorpay. If Razorpay webhook doesn't confirm within 10 seconds, Cashfree is tried for the next charge attempt. A circuit breaker (using the `opossum` library) wraps each gateway call. Webhook verification uses HMAC-SHA256 signature check — any webhook that fails signature verification is silently dropped and logged.

**Idempotency:**
Every charge attempt is keyed by `tripId`. If `initiateCharge` is called twice for the same trip (e.g., due to retry), it returns the existing payment record without double-charging. This is enforced at the database level with a unique constraint on `payment.payments(trip_id)`.

**Driver payout flow:**
1. Nightly BullMQ job at 11 PM calculates each driver's earnings for the day
2. Platform commission deducted (18–22% depending on city config)
3. Net amount sent to driver's UPI ID via Razorpay Route
4. `payment.payouts` record updated with UTR (Unique Transaction Reference)
5. Driver sees earnings in app within 30 minutes of settlement

---

### 5.5 Pricing Module

**Directory:** `modules/pricing/`  
**Language:** TypeScript  
**Database schema:** `pricing.*`

**Purpose:** Calculate fares and surge multipliers. Entirely stateless — reads config, returns numbers.

**Owns these tables:**
- `pricing.city_configs` — base fare, per-km rate, per-minute rate, minimum fare per city/vehicle type
- `pricing.surge_events` — active surge periods with H3 cell, multiplier, start/end time
- `pricing.promo_codes` — discount codes with conditions and limits
- `pricing.flat_fare_corridors` — fixed-price routes (e.g., airport to city center)

**Public API (`modules/pricing/index.ts`):**

```typescript
estimateFare(pickup: LatLng, dropoff: LatLng, vehicleType: VehicleType, cityId: CityId): Promise<FareEstimate>
calculateFinalFare(tripId: TripId, actualDistanceKm: number, actualDurationMin: number): Promise<Money>
getSurgeMultiplier(location: LatLng, cityId: CityId): Promise<number>  // 1.0 if no surge
applyPromoCode(code: string, riderId: RiderId, estimatedFare: Money): Promise<DiscountResult>
getCityConfig(cityId: CityId): Promise<CityPricingConfig>
```

**Fare formula:**

```
base_fare = city_config.base_fare
distance_charge = actual_km × city_config.per_km_rate
time_charge = actual_minutes × city_config.per_min_rate
raw_fare = base_fare + distance_charge + time_charge
surge_fare = raw_fare × surge_multiplier
final_fare = MAX(surge_fare, city_config.minimum_fare)
final_fare = ROUND(final_fare / 5) × 5  // Round to nearest ₹5
```

**Surge calculation (runs on a 60-second cron):**
1. Count `REQUESTED` trips in each H3 cell (resolution 9, ~170m cells) in the last 10 minutes
2. Count `IDLE` drivers in each H3 cell
3. `demand_ratio = request_count / max(driver_count, 1)`
4. If `demand_ratio > 2.0` → surge = 1.5×; if `> 3.5` → surge = 2.0×; capped at 2.5×
5. Surge stored in Redis with 5-minute TTL and written to `pricing.surge_events`

---

### 5.6 Notification Module

**Directory:** `modules/notification/`  
**Language:** TypeScript  
**Database schema:** None — pure event consumer and sender

**Purpose:** Deliver all notifications to users. Subscribes to domain events and translates them into push notifications, SMS, and in-app WebSocket messages. This module never emits events. It is a pure side-effect module.

**Public API (`modules/notification/index.ts`):**

```typescript
// Mostly internal — called by the event subscribers
// These are exposed for direct emergency use:
sendEmergencyAlert(userId: UserId, tripId: TripId, location: LatLng): Promise<void>
sendSmsOtp(phone: string, otp: string): Promise<void>  // used by Auth module
```

**Subscribes to and what it does:**

| Event | Action |
|---|---|
| `trip.driver_accepted` | Push + WebSocket to rider: driver details, photo, ETA |
| `trip.driver_arrived` | Push + WebSocket to rider: "Driver has arrived" + OTP |
| `trip.started` | WebSocket to rider: start tracking screen |
| `trip.completed` | Push to rider: receipt summary + rate driver prompt |
| `trip.cancelled` | Push to rider + driver: cancellation confirmation |
| `trip.sos_triggered` | SMS to rider's emergency contacts + internal ops alert |
| `payment.charged_successfully` | Push to rider: payment confirmation |
| `payment.charge_failed` | Push to rider: payment failed, retry or use cash |
| `matching.no_drivers_available` | Push to rider: no drivers nearby |
| `user.registered` | Push: welcome message |

**Notification priority levels:**

- `CRITICAL` (SOS, payment failure) → Send via SMS + FCM push simultaneously, retry 3 times
- `HIGH` (trip state changes) → FCM push only, retry 2 times, fall back to SMS if FCM fails
- `LOW` (receipt, promo, welcome) → Queued BullMQ job, best-effort, no retry

---

### 5.7 KYC Module

**Directory:** `modules/kyc/`  
**Language:** TypeScript  
**Database schema:** `kyc.*`

**Purpose:** Driver document collection, verification, and approval workflow.

**Owns these tables:**
- `kyc.driver_profiles` — driver-specific data (vehicle details, UPI ID, bank account)
- `kyc.documents` — uploaded document records with S3 keys and verification status
- `kyc.verification_attempts` — audit log of each external verification API call
- `kyc.approval_decisions` — manual approval decisions by ops team

**Documents required at onboarding:**

| Document | Verification API | Notes |
|---|---|---|
| Aadhaar card (front + back) | Digilocker API or OCR | Mandatory |
| Selfie (live capture) | Face match against Aadhaar photo | Mandatory |
| Driving licence | Vahan API (DL verification) | Mandatory |
| Vehicle RC (Registration Certificate) | Parivahan API | Mandatory |
| Vehicle photo (4 angles) | Manual ops review | Mandatory |
| Insurance certificate | Manual ops review | Mandatory |

**Approval flow:**
1. Driver submits all documents via app
2. Automated checks run (Aadhaar OCR → face match → DL API → RC API)
3. If all automated checks pass → goes into ops approval queue
4. Ops team reviews vehicle photos + insurance in Admin dashboard
5. Ops approves or rejects with a reason
6. Driver notified of decision via push + SMS
7. If approved → driver can go online immediately

**Public API (`modules/kyc/index.ts`):**

```typescript
submitDocument(driverId: DriverId, docType: DocumentType, s3Key: string): Promise<Document>
getKycStatus(driverId: DriverId): Promise<KycStatus>
runAutomatedVerification(driverId: DriverId): Promise<VerificationResult>
approveDriver(driverId: DriverId, approvedBy: AdminId): Promise<void>
rejectDriver(driverId: DriverId, reason: string, approvedBy: AdminId): Promise<void>
getPendingApprovals(page: number, limit: number): Promise<PaginatedDrivers>
```

**Emits these events:**
- `kyc.submitted` — all docs uploaded, awaiting verification
- `kyc.approved` — driver cleared to go online
- `kyc.rejected` — driver notified of failure reason

---

### 5.8 Analytics Module

**Directory:** `modules/analytics/`  
**Language:** TypeScript  
**Database schema:** `analytics.*` (event staging only; final store is ClickHouse)

**Purpose:** Capture all business events, write to ClickHouse for reporting. Non-operational — no other module depends on this module.

**Subscribes to:** All domain events from all modules. Acts as a passive observer.

**What it writes to ClickHouse:**
- Trip funnel (request → match → accept → complete) with timestamps
- Payment success/failure rates by city, gateway, method
- Driver utilization (online hours vs active trip hours)
- Surge pricing effectiveness (ride volume before/after surge)
- City-level KPIs (rides/day, avg fare, cancellation rate, average ETA)

**Public API (`modules/analytics/index.ts`):**

```typescript
trackEvent(event: AnalyticsEvent): Promise<void>  // batched, writes to ClickHouse every 30s
getCityKpis(cityId: CityId, dateRange: DateRange): Promise<CityKpis>
getDriverPerformance(driverId: DriverId, dateRange: DateRange): Promise<DriverMetrics>
```

**Implementation note:** Analytics writes are non-blocking. The module uses an in-memory buffer and flushes to ClickHouse every 30 seconds via a BullMQ job. If ClickHouse is unreachable, events are written to `analytics.event_staging` in PostgreSQL as a fallback and replayed when ClickHouse recovers.

---

## 6. Database Design

### Guiding principles

1. **One PostgreSQL instance.** Shared by all modules. Boundaries enforced by schema namespacing, not separate databases.
2. **Schema-per-module.** `auth.*` belongs to Auth module. `trip.*` belongs to Trip module. No exceptions.
3. **No cross-schema foreign keys.** Foreign keys that cross schema boundaries are forbidden. Use application-level joins (via module APIs) instead.
4. **Append-only event tables.** `trip.trip_events` and `payment.payments` are append-only. Never UPDATE or DELETE from them.
5. **PgBouncer in transaction mode.** App connects to PgBouncer, not directly to PostgreSQL. Keeps connection count manageable.

### Full schema definition

```sql
-- ============================================================
-- AUTH SCHEMA
-- ============================================================
CREATE SCHEMA auth;

CREATE TABLE auth.users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       VARCHAR(15) UNIQUE NOT NULL,
    name        VARCHAR(100),
    email       VARCHAR(255),
    role        VARCHAR(20) NOT NULL DEFAULT 'RIDER',  -- RIDER | DRIVER | ADMIN
    status      VARCHAR(20) NOT NULL DEFAULT 'ACTIVE', -- ACTIVE | SUSPENDED | DELETED
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE auth.sessions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL,  -- No FK to avoid cross-schema dep; enforced in app
    refresh_token_hash  VARCHAR(64) UNIQUE NOT NULL,
    device_id           VARCHAR(255),
    user_agent          TEXT,
    expires_at          TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON auth.sessions(user_id, expires_at);

CREATE TABLE auth.otp_codes (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       VARCHAR(15) NOT NULL,
    code_hash   VARCHAR(64) NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    used_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON auth.otp_codes(phone, expires_at);

-- ============================================================
-- TRIP SCHEMA
-- ============================================================
CREATE SCHEMA trip;

CREATE TABLE trip.trips (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rider_id            UUID NOT NULL,   -- References auth.users.id (enforced in app)
    driver_id           UUID,            -- Null until matched
    city_id             VARCHAR(50) NOT NULL,
    vehicle_type        VARCHAR(20) NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'REQUESTED',
    pickup_lat          DECIMAL(10, 7) NOT NULL,
    pickup_lng          DECIMAL(10, 7) NOT NULL,
    pickup_address      TEXT,
    dropoff_lat         DECIMAL(10, 7) NOT NULL,
    dropoff_lng         DECIMAL(10, 7) NOT NULL,
    dropoff_address     TEXT,
    estimated_fare      DECIMAL(10, 2),
    final_fare          DECIMAL(10, 2),
    distance_km         DECIMAL(8, 3),
    duration_minutes    INTEGER,
    rider_otp           VARCHAR(4),      -- Hashed, for trip-start verification
    surge_multiplier    DECIMAL(4, 2) NOT NULL DEFAULT 1.00,
    promo_code          VARCHAR(30),
    promo_discount      DECIMAL(10, 2),
    cancelled_by        UUID,
    cancellation_reason VARCHAR(100),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ
);
CREATE INDEX ON trip.trips(rider_id, created_at DESC);
CREATE INDEX ON trip.trips(driver_id, status);
CREATE INDEX ON trip.trips(status, created_at DESC);
CREATE INDEX ON trip.trips(status) WHERE status = 'IN_PROGRESS';  -- Partial index

CREATE TABLE trip.trip_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     UUID NOT NULL,
    event_type  VARCHAR(50) NOT NULL,
    actor_id    UUID,
    payload     JSONB,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON trip.trip_events(trip_id, occurred_at);

-- TimescaleDB hypertable for GPS tracks
CREATE TABLE trip.gps_tracks (
    trip_id     UUID NOT NULL,
    lat         DECIMAL(10, 7) NOT NULL,
    lng         DECIMAL(10, 7) NOT NULL,
    heading     SMALLINT,
    speed_kmh   DECIMAL(6, 2),
    recorded_at TIMESTAMPTZ NOT NULL
);
SELECT create_hypertable('trip.gps_tracks', 'recorded_at', chunk_time_interval => INTERVAL '1 day');
CREATE INDEX ON trip.gps_tracks(trip_id, recorded_at DESC);

CREATE TABLE trip.ratings (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     UUID NOT NULL UNIQUE,
    rider_id    UUID NOT NULL,
    driver_id   UUID NOT NULL,
    rider_rating    SMALLINT CHECK (rider_rating BETWEEN 1 AND 5),
    driver_rating   SMALLINT CHECK (driver_rating BETWEEN 1 AND 5),
    rider_comment   TEXT,
    driver_comment  TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PAYMENT SCHEMA
-- ============================================================
CREATE SCHEMA payment;

CREATE TABLE payment.payments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id             UUID NOT NULL UNIQUE,  -- Idempotency key
    rider_id            UUID NOT NULL,
    amount              DECIMAL(10, 2) NOT NULL,
    currency            VARCHAR(3) NOT NULL DEFAULT 'INR',
    method              VARCHAR(30) NOT NULL,  -- UPI | WALLET | CASH | CARD
    status              VARCHAR(30) NOT NULL DEFAULT 'PENDING',
    gateway             VARCHAR(20),           -- RAZORPAY | CASHFREE | null (cash)
    gateway_payment_id  VARCHAR(100),
    gateway_order_id    VARCHAR(100),
    failure_reason      TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    settled_at          TIMESTAMPTZ
);
CREATE INDEX ON payment.payments(rider_id, created_at DESC);
CREATE INDEX ON payment.payments(status, created_at);

CREATE TABLE payment.wallets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL UNIQUE,
    balance     DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT wallet_balance_non_negative CHECK (balance >= 0)
);

CREATE TABLE payment.wallet_transactions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id   UUID NOT NULL,
    type        VARCHAR(20) NOT NULL,  -- CREDIT | DEBIT
    amount      DECIMAL(10, 2) NOT NULL,
    balance_after DECIMAL(10, 2) NOT NULL,
    description TEXT,
    reference_id UUID,                -- trip_id or payout_id
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON payment.wallet_transactions(wallet_id, created_at DESC);

CREATE TABLE payment.payouts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id       UUID NOT NULL,
    gross_amount    DECIMAL(10, 2) NOT NULL,
    commission      DECIMAL(10, 2) NOT NULL,
    net_amount      DECIMAL(10, 2) NOT NULL,
    period_start    DATE NOT NULL,
    period_end      DATE NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    utr             VARCHAR(50),        -- Unique Transaction Reference from bank
    upi_id          VARCHAR(100),
    initiated_at    TIMESTAMPTZ,
    settled_at      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON payment.payouts(driver_id, period_start DESC);

-- ============================================================
-- PRICING SCHEMA
-- ============================================================
CREATE SCHEMA pricing;

CREATE TABLE pricing.city_configs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_id         VARCHAR(50) NOT NULL,
    vehicle_type    VARCHAR(20) NOT NULL,
    base_fare       DECIMAL(8, 2) NOT NULL,
    per_km_rate     DECIMAL(8, 2) NOT NULL,
    per_min_rate    DECIMAL(8, 2) NOT NULL,
    minimum_fare    DECIMAL(8, 2) NOT NULL,
    commission_pct  DECIMAL(5, 2) NOT NULL DEFAULT 20.00,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    effective_from  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(city_id, vehicle_type, effective_from)
);

CREATE TABLE pricing.surge_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    city_id         VARCHAR(50) NOT NULL,
    h3_cell         VARCHAR(20) NOT NULL,  -- H3 index at resolution 9
    multiplier      DECIMAL(4, 2) NOT NULL,
    demand_ratio    DECIMAL(6, 2),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ
);
CREATE INDEX ON pricing.surge_events(city_id, h3_cell, started_at DESC);

CREATE TABLE pricing.promo_codes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(30) UNIQUE NOT NULL,
    discount_type   VARCHAR(20) NOT NULL,  -- FLAT | PERCENTAGE
    discount_value  DECIMAL(8, 2) NOT NULL,
    max_discount    DECIMAL(8, 2),
    min_fare        DECIMAL(8, 2),
    max_uses        INTEGER,
    uses_count      INTEGER NOT NULL DEFAULT 0,
    user_max_uses   INTEGER NOT NULL DEFAULT 1,
    valid_from      TIMESTAMPTZ NOT NULL,
    valid_until     TIMESTAMPTZ NOT NULL,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

-- ============================================================
-- KYC SCHEMA
-- ============================================================
CREATE SCHEMA kyc;

CREATE TABLE kyc.driver_profiles (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id       UUID NOT NULL UNIQUE,
    vehicle_type    VARCHAR(20) NOT NULL,
    vehicle_make    VARCHAR(50),
    vehicle_model   VARCHAR(50),
    vehicle_year    SMALLINT,
    vehicle_color   VARCHAR(30),
    licence_plate   VARCHAR(15) NOT NULL,
    upi_id          VARCHAR(100),
    kyc_status      VARCHAR(20) NOT NULL DEFAULT 'PENDING',  -- PENDING | SUBMITTED | APPROVED | REJECTED
    approved_by     UUID,
    approval_note   TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE kyc.documents (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_id       UUID NOT NULL,
    doc_type        VARCHAR(30) NOT NULL,  -- AADHAAR_FRONT | AADHAAR_BACK | DL | RC | SELFIE | VEHICLE_PHOTO | INSURANCE
    s3_key          VARCHAR(500) NOT NULL,
    verification_status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    verified_at     TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON kyc.documents(driver_id, doc_type);
```

### Migration conventions

- All migration files live in `infra/db/migrations/`
- File naming: `{sequence}_{schema}_{description}.sql` — example: `0012_trip_add_disputed_status.sql`
- Sequence is 4 digits, zero-padded, global (not per-module)
- Migrations are append-only — never edit a migration file after it has been committed
- Zero-downtime rule: never DROP COLUMN or ALTER COLUMN in a single deployment. Always: add new column → deploy → migrate data → remove old column in the next deployment

---

## 7. API Design Standards

### HTTP conventions

- **Base path:** `/api/v1/`
- **Authentication:** `Authorization: Bearer {accessToken}` header on all protected routes
- **Content type:** `application/json` for all requests and responses
- **Pagination:** All list endpoints accept `?page=1&limit=20` and return `{ data: [], total: N, page: N, limit: N }`

### Versioning

URI versioning: `/api/v1/`, `/api/v2/`. Old versions supported for minimum 12 months after deprecation notice. Mobile apps cannot be force-updated instantly — plan for old clients.

### Error format (RFC 7807)

All errors return this shape. Never return different error shapes from different endpoints.

```json
{
  "type": "https://errors.rideshare.com/trip/not-found",
  "title": "Trip not found",
  "status": 404,
  "detail": "No trip with ID a1b2c3d4 exists for this user.",
  "instance": "/api/v1/trips/a1b2c3d4",
  "requestId": "req_8f7a9b2c"
}
```

### Key API endpoints

```
POST   /api/v1/auth/otp/send          Body: { phone }
POST   /api/v1/auth/otp/verify        Body: { phone, code }
POST   /api/v1/auth/token/refresh     Body: { refreshToken }
DELETE /api/v1/auth/session           (logout)

GET    /api/v1/trips/estimate         Query: pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, vehicle_type
POST   /api/v1/trips                  Body: { pickupLat, pickupLng, dropoffLat, dropoffLng, vehicleType, promoCode? }
GET    /api/v1/trips/:tripId          
POST   /api/v1/trips/:tripId/cancel   Body: { reason }
POST   /api/v1/trips/:tripId/rate     Body: { rating, comment }
GET    /api/v1/trips                  (history, paginated)

POST   /api/v1/driver/trips/:tripId/accept
POST   /api/v1/driver/trips/:tripId/arrived
POST   /api/v1/driver/trips/:tripId/start   Body: { riderOtp }
POST   /api/v1/driver/trips/:tripId/end     Body: { finalLat, finalLng }
POST   /api/v1/driver/availability          Body: { status: 'ONLINE' | 'OFFLINE' }

GET    /api/v1/payment/wallet
POST   /api/v1/payment/wallet/topup         Body: { amount }
POST   /api/v1/payment/webhooks/razorpay    (Razorpay webhook, public, signature-verified)
POST   /api/v1/payment/webhooks/cashfree    (Cashfree webhook, public, signature-verified)

POST   /api/v1/kyc/documents                Body: { docType, file (multipart) }
GET    /api/v1/kyc/status

# Admin (requires ADMIN role JWT)
GET    /api/v1/admin/kyc/pending
POST   /api/v1/admin/kyc/:driverId/approve
POST   /api/v1/admin/kyc/:driverId/reject   Body: { reason }
GET    /api/v1/admin/cities/:cityId/metrics
POST   /api/v1/admin/pricing/city            Body: city pricing config
```

### Rate limits (enforced at Kong gateway)

| Endpoint | Limit |
|---|---|
| `POST /auth/otp/send` | 5 requests / phone / hour |
| `POST /auth/otp/verify` | 10 requests / phone / 15 minutes |
| All rider endpoints | 60 requests / user / minute |
| All driver endpoints | 120 requests / user / minute |
| Admin endpoints | 300 requests / user / minute |
| Webhook endpoints | No user limit (IP-based, Cloudflare protected) |

---

## 8. Real-Time Layer

### Architecture

Socket.io runs inside the same Node.js process as the HTTP server. No separate WebSocket service. The `io` object is exported as a singleton from `apps/api/server.ts` and imported by the Notification module.

```
Client ──WebSocket──▶ Socket.io (same process as HTTP)
                          │
                    Room: tripId
                    Room: userId
                    Room: driverId
                          │
              Notification module emits to rooms
              based on domain events
```

For horizontal scaling (multiple app instances), use `@socket.io/redis-adapter`. Rooms are then synced across all instances via Redis pub/sub.

### Connection protocol

```
Client connects:
  ws://api.rideshare.com/socket.io/?token={accessToken}

Server validates JWT on connection handshake.
If invalid → disconnect immediately.
If valid → socket.join(userId)

On trip creation:
  Server: socket.join(tripId)  -- for both rider and driver
```

### WebSocket events reference

**Client → Server events (sent by apps):**

| Event | Payload | Sender |
|---|---|---|
| `location:update` | `{ lat, lng, heading, speed }` | Driver app (every 3s while online) |
| `trip:ack` | `{ tripId, action: 'accept' \| 'reject' }` | Driver app |
| `ping` | — | Both apps (keepalive every 25s) |

**Server → Client events (received by apps):**

| Event | Payload | Recipient |
|---|---|---|
| `trip:request` | `{ tripId, pickup, dropoff, estimatedFare, riderId }` | Driver |
| `trip:cancelled` | `{ tripId, reason }` | Driver + Rider |
| `trip:driver_assigned` | `{ driver: {...}, eta }` | Rider |
| `trip:driver_arrived` | `{ tripId, otp }` | Rider |
| `trip:started` | `{ tripId }` | Rider |
| `trip:completed` | `{ tripId, fare, receipt }` | Rider |
| `driver:location` | `{ lat, lng, heading }` | Rider (while driver is en route) |
| `notification` | `{ type, title, body, data }` | Both |

### Fallback for poor connectivity

Socket.io automatically falls back to HTTP long-polling when WebSocket is not stable. This is configured via transport negotiation on connect. For Tier 2 cities with 2G/3G connections, long-polling will trigger frequently — ensure the server can handle it (stateless, horizontal scaling).

---

## 9. Mobile Applications

### Platform and framework

Both Rider App and Driver App are built with **Flutter 3.22+ (Stable)**. A single monorepo repository (`apps/mobile/`) houses the packages, using a Melos-managed multi-package workspace to maintain clean boundaries and prevent over-sharing of code:

```
apps/mobile/
├── packages/
│   ├── shared/                 # Shared assets, theme configs, network utilities
│   ├── rider_app/              # Isolated Rider application code
│   └── driver_app/             # Isolated Driver application code
```

### Rider App — screen inventory

**Onboarding flow:**
- `SplashScreen` — check for active JWT session, navigate accordingly
- `PhoneEntryScreen` — phone number input
- `OtpVerificationScreen` — 4-digit OTP, auto-fills via SMS User Consent API
- `ProfileSetupScreen` — name input (optional, can skip)

**Main app flow (post-login):**
- `HomeScreen` — Mapbox map, recent destinations, search button
- `DestinationPickerScreen` — search autocomplete (Mapbox + MapMyIndia)
- `RideSummaryScreen` — fare estimate, vehicle type selection drawer, promo codes
- `SearchingDriverScreen` — animated driver search, cancel option
- `TrackingScreen` — live driver location tracking, SOS button, share ride button
- `TripSummaryScreen` — fare breakdown, receipt, rating prompt
- `RatingScreen` — 1–5 stars + comment input
- `WalletScreen` — balance display, transaction history, top-up trigger
- `TripHistoryScreen` — paginated list of past rides
- `ProfileScreen` — emergency contacts, saved places

### Driver App — screen inventory

**Onboarding flow:**
- `PhoneEntryScreen`, `OtpVerificationScreen` (shared with Rider auth UI assets)
- `VehicleDetailsScreen` — vehicle type selection, license plate, make/model
- `DocumentUploadScreen` — camera capture interface for Aadhaar, DL, RC, insurance
- `KycPendingScreen` — displays status of approval queue

**Main app flow (post-approval):**
- `HomeScreen` — online/offline toggle, earnings dashboard, city heatmap
- `RideRequestScreen` — full-screen overlay: rider details, pickup, 15s accept timer
- `NavigationScreen` — Mapbox turn-by-turn navigation routing to pickup/destination
- `TripActiveScreen` — active trip layout, start/end buttons, SOS button
- `TripEndScreen` — earnings summary credited page
- `EarningsScreen` — daily/weekly payout history and charts
- `ProfileScreen` — bank account details, UPI ID, ratings list

### Critical technical requirements

| Requirement | Implementation |
|---|---|
| Background location (driver) | `flutter_background_geolocation` (Transistor Software). Handles battery optimization whitelists, background threads, and persistent location updates. |
| OTP autofill Android | SMS User Consent API. Integrates via the `sms_autofill` plugin. |
| OTP autofill iOS | `ASAuthorizationController` autofill via default keyboard text suggestions. |
| Maps | Mapbox Maps SDK for Flutter (`mapbox_maps_flutter`). Supports local map caching. |
| Offline storage | `isar` (High-performance NoSQL database). Stores local cache for earnings and trip logs. |
| Code Generation | `freezed` + `json_serializable` for compile-time model serialization and type safety. |
| APK size target | Under 25MB. Compile using split-apks option (`flutter build apk --split-per-abi`). |
| State management | `flutter_riverpod` (Riverpod) for declarative, testable state and dependency injection. |
| Networking | `dio` client + interceptors for JWT automatic refresh rotation. |

### Navigation structure

```
go_router (Declarative Router)
├── /auth (unauthenticated)
│   ├── /phone
│   ├── /otp
│   └── /profile-setup
└── /main (authenticated)
    ├── /rider (Rider Tabs)
    │   ├── /home -> /picker -> /summary -> /searching -> /tracking -> /receipt
    │   ├── /wallet
    │   └── /profile -> /history
    └── /driver (Driver Tabs)
        ├── /home <-> /dispatch (overlay) -> /navigation -> /trip-active -> /trip-end
        ├── /earnings
        └── /profile -> /upload
```

---

## 10. Infrastructure & DevOps

### Cloud provider and region

**Primary:** AWS Mumbai (ap-south-1)  
**Disaster recovery:** AWS Hyderabad (ap-south-2) — cross-region RDS read replica, S3 replication  
**CDN / WAF:** Cloudflare (in front of ALB for DDoS protection, SSL termination)

### Compute

The monolith runs as ECS Fargate tasks (simpler than EKS for a single-image deployment).

```
Task: api-server
  CPU: 4 vCPU
  RAM: 8 GB
  Min instances: 2 (always-on for HA)
  Max instances: 20
  Scaling trigger: CPU > 60% for 3 minutes → scale up

Task: worker-server (BullMQ processors)
  CPU: 2 vCPU
  RAM: 4 GB
  Min instances: 1
  Max instances: 5
  Scaling trigger: BullMQ queue depth > 500 jobs
```

### Networking

```
Internet → Cloudflare WAF → ALB (Application Load Balancer)
ALB → ECS Fargate tasks (port 3000)
  HTTP routes → /api/*
  WebSocket upgrade → /socket.io/*  (sticky sessions enabled, 60s draining)

Internal:
ECS → RDS (private subnet via Security Group)
ECS → ElastiCache Redis (private subnet)
ECS → MSK Kafka (if added later)
ECS → S3 (via VPC endpoint, no public internet)
```

### Database

- **RDS PostgreSQL 16** — db.r6g.large, Multi-AZ standby, automated backups 7 days
- **TimescaleDB extension** enabled for `trip.gps_tracks` hypertable
- **PgBouncer** on EC2 t3.small as a sidecar — transaction pooling mode, 20 real connections, 200 virtual connections
- **Read replica** — 1 replica in same region, used by Analytics module and reporting queries

### Redis

- **ElastiCache Redis 7** — r6g.large, 1 primary + 1 replica
- Used for: driver geo index, sessions, rate limiting, BullMQ job queues, Socket.io room adapter
- **Not** cluster mode (avoids CROSSSLOT errors from multi-key commands used by Socket.io adapter and BullMQ)

### Storage

- **S3 bucket: `rideshare-driver-docs-{env}`** — KYC documents, versioned, server-side encrypted (SSE-S3), private (no public access)
- **S3 bucket: `rideshare-assets-{env}`** — profile photos, receipt PDFs, public read via CloudFront
- **CloudFront distribution** in front of assets bucket — cache receipts and photos at edge

### CI/CD pipeline

Every merge to `main` triggers the following GitHub Actions workflow:

```yaml
Steps:
  1. Checkout + install deps (npm ci)
  2. Lint (npm run lint) — fails if ESLint module boundary rules violated
  3. Type check (npx tsc --noEmit)
  4. Unit tests (npm run test:unit) — Vitest, no external deps
  5. Integration tests (npm run test:integration) — Testcontainers spins up real PG + Redis
  6. Build Docker image + push to ECR
  7. Trivy security scan on image — fails on CRITICAL CVEs
  8. Deploy to staging (ECS rolling update)
  9. Smoke test (k6 script: send OTP → verify → create trip → cancel)
  10. [Manual approval gate for production]
  11. Deploy to production (ECS rolling update, 30% at a time)
```

Mobile CI (separate workflow, triggered on `apps/mobile/**` changes):
- EAS Build for Android (.aab) and iOS (.ipa)
- Fastlane uploads to Google Play (internal track) and TestFlight
- OTA JS update via EAS Update for JS-only changes (no store review needed)

### Observability

| Tool | Purpose |
|---|---|
| **Datadog APM** | Traces, metrics, dashboards, alerts |
| **Pino** | Structured JSON logging (every log has `requestId`, `userId`, `tripId`) |
| **OpenTelemetry SDK** | Auto-instrumentation for Fastify, Prisma, Redis, BullMQ |
| **Sentry** | Mobile crash reporting + session replay |
| **Datadog Synthetics** | Synthetic trip-request test every 5 minutes from 3 cities |
| **PagerDuty** | On-call rotation, escalation policies |

### Alert thresholds

| Alert | Threshold | Severity |
|---|---|---|
| Match success rate | < 85% | P1 |
| Payment success rate | < 95% | P1 |
| API p99 latency | > 2000ms | P1 |
| Error rate (5xx) | > 2% | P1 |
| BullMQ queue depth | > 1000 jobs | P2 |
| Redis memory usage | > 75% | P2 |
| RDS CPU | > 80% for 5 min | P2 |
| Mobile crash-free sessions | < 99.5% | P2 |

---

## 11. Build Stages & Roadmap

### Phase 1 — Foundation (Months 1–4)

**Goal:** Ship the minimum viable product in one pilot city with 300+ drivers.

**Team:** 2 backend engineers, 2 mobile engineers, 1 DevOps/infra engineer, 1 designer, 1 PM

**Backend deliverables:**

- [ ] Project scaffold: Fastify monolith, TypeScript, ESLint module boundary rules
- [ ] Shared kernel: types, errors, logger, config (Zod-validated env vars)
- [ ] Database: PostgreSQL schema for auth, trip, payment, pricing, kyc; PgBouncer setup
- [ ] Redis setup: ElastiCache cluster, client singleton, key conventions documented
- [ ] Auth module: OTP send/verify, JWT, refresh token rotation
- [ ] Matching module: Go binary with H3 geospatial, Redis geo, driver scoring, TypeScript wrapper
- [ ] Trip module: full state machine, trip creation, accept, start, end, cancel, GPS track logging
- [ ] Pricing module: fare calculation, surge (basic — demand/supply ratio), promo codes
- [ ] Payment module: Razorpay integration, UPI autopay, webhook handler, wallet, cash fallback
- [ ] Notification module: FCM push, SMS via MSG91, WebSocket emit
- [ ] KYC module: document upload to S3, Digilocker OCR, Vahan DL check, manual approval queue
- [ ] Admin dashboard v1: KYC approval UI, live ops map (drivers + active trips), basic metrics
- [ ] API Gateway: Kong setup, JWT validation plugin, rate limiting, routing rules
- [ ] CI/CD: GitHub Actions pipeline, ECR, ECS Fargate, staging + prod environments
- [ ] Observability: Datadog APM, Pino logging, basic dashboards, PagerDuty on-call

**Mobile deliverables:**

- [ ] Rider app: onboarding, home screen, booking flow, driver tracking, payment, rating
- [ ] Driver app: onboarding + KYC upload, online/offline, ride request modal, navigation, earnings
- [ ] Mapbox integration, offline tile caching for pilot city
- [ ] Socket.io client with reconnect handling and long-poll fallback
- [ ] OTP autofill (Android + iOS)
- [ ] Background location for driver app

**Phase 1 success criteria:**
- 1,000 completed rides in pilot city
- Match success rate > 85%
- Average match time < 90 seconds
- App Store rating > 4.0
- Zero P1 incidents in first 2 weeks

---

### Phase 2 — Optimize & Expand (Months 5–9)

**Goal:** Expand to 3 Tier 1 cities. Improve matching and engagement mechanics.

**Deliverables:**

- [ ] ML-based ETA prediction (XGBoost model trained on pilot city trip data)
- [ ] Advanced surge pricing (ML demand forecasting, predictive surge)
- [ ] Driver incentive engine: weekly targets, completion bonuses, streak rewards
- [ ] Rider referral program: unique referral codes, wallet credit on first ride of referee
- [ ] Scheduled rides: book up to 7 days in advance
- [ ] Multi-stop trips: up to 3 stops per ride
- [ ] Hindi + 3 regional languages (Kannada, Telugu, Tamil based on city coverage)
- [ ] Hindi voice navigation for driver app (Mapbox + text-to-speech)
- [ ] Corporate accounts: B2B billing, centralized dashboard, monthly invoicing
- [ ] Driver payout: daily payout (currently weekly), payment dashboard improvements
- [ ] Analytics module: ClickHouse integration, Metabase dashboards for ops team
- [ ] Load testing: k6 script simulating 50,000 concurrent users, identify and fix bottlenecks

**Phase 2 success criteria:**
- 5,000+ active drivers across 3 cities
- 20,000+ daily rides
- Rider 30-day retention > 35%
- ₹50L+ monthly GMV

---

### Phase 3 — Tier 2 Expansion (Months 10–14)

**Goal:** 8–10 Tier 2 cities, new vehicle categories, fleet operator model.

**Deliverables:**

- [ ] Lite APK: under 15MB for entry-level Android (strip unused Mapbox layers, lazy-load features)
- [ ] Auto-rickshaw category (city-specific fare rules, different driver app layout)
- [ ] Bike taxi category (state-by-state, only where legally permitted)
- [ ] MapMyIndia API integration for hyperlocal POI in small cities (complements Mapbox)
- [ ] Feature flags per city (some features enabled only in specific cities)
- [ ] Fleet operator portal: bulk driver onboarding, fleet-level earnings dashboard, GPS fleet tracking
- [ ] Women driver / women passenger matching option (opt-in for both)
- [ ] Intercity rides (city pair routes with fixed pricing corridors)
- [ ] RTO / aggregator license tracking per state (admin tool to track compliance status)

**Phase 3 success criteria:**
- 50,000+ daily rides across 13+ cities
- 25,000+ active drivers
- Series A fundraise window open

---

### Phase 4 — Scale & Monetize (Months 15–18)

**Goal:** Build revenue levers beyond commission. Prepare for Series A.

**Deliverables:**

- [ ] Rider subscription: ₹199/month for 20 discounted rides (RidePass)
- [ ] Driver subscription: ₹99/month for priority dispatch and reduced commission
- [ ] Courier feature: package delivery using idle driver capacity (same driver app)
- [ ] Embedded insurance: ₹1 per ride accident insurance for riders via Acko/Digit API
- [ ] Extracting Matching module to standalone service (see Section 3 exit strategy)
- [ ] Kafka adoption: replace EventEmitter2 with Kafka for cross-module events (enables analytics without polling)
- [ ] BI reporting: self-serve analytics for city ops team via Metabase + ClickHouse

**Phase 4 success criteria:**
- 100,000+ daily rides
- 5%+ rides on RidePass subscription
- Series A term sheet signed

---

## 12. Non-Functional Requirements

### Performance targets

| Metric | Target |
|---|---|
| API response time (p50) | < 200ms |
| API response time (p99) | < 1000ms |
| Driver match time (p99) | < 90 seconds from request to driver accept |
| Matching engine latency | < 800ms per match computation |
| WebSocket message delivery | < 500ms end-to-end |
| App cold start time | < 3 seconds on mid-range Android |
| Fare estimate API | < 300ms (Mapbox cached route) |

### Reliability targets

| Metric | Target |
|---|---|
| API uptime | 99.9% (8.7 hours downtime/year max) |
| Payment success rate | > 98% |
| FCM push delivery rate | > 95% |
| Data durability (PostgreSQL) | 99.999999% (RDS Multi-AZ) |
| RTO (Recovery Time Objective) | 30 minutes |
| RPO (Recovery Point Objective) | 5 minutes |

### Security requirements

- All traffic over HTTPS/WSS — no HTTP in production
- Passwords (if ever used) bcrypt with cost factor ≥12; OTP codes stored as SHA-256 hashes
- All S3 KYC documents: private, server-side encrypted, access via pre-signed URLs with 15-minute expiry
- Razorpay/Cashfree webhook signature verification on every webhook — reject unverified payloads
- PII in logs: never log phone numbers, Aadhaar numbers, or payment card details — use masked versions
- Driver document URLs: served via signed CloudFront URLs, not direct S3
- SQL injection: Prisma parameterized queries only — never string-interpolate into SQL
- Rate limiting: enforced at Kong gateway before requests reach the app

### Scalability plan

The modular monolith can handle up to approximately 100,000 daily rides (roughly 2,000 concurrent active trips at peak) before vertical scaling becomes insufficient. At that point:

1. Scale API instances horizontally to 10–15 (Socket.io Redis adapter supports this)
2. Upgrade RDS instance class and add read replicas
3. Extract Matching module to a standalone Go service (see Section 3 for the playbook)
4. Introduce Kafka to replace EventEmitter2 for cross-module events

---

## 13. Regulatory & Compliance

### Licenses required before launch

| License | Authority | Lead time | Priority |
|---|---|---|---|
| Motor Vehicle Aggregator License | State transport department | 3–6 months | Critical — apply in Month 1 |
| Company incorporation (Pvt Ltd) | MCA (ROC) | 2–4 weeks | Critical |
| DPIIT Startup registration | DPIIT | 1–2 weeks | High (for tax benefits) |
| GST registration | GST portal | 1–2 weeks | Critical |
| PPI license (if wallet > ₹10k) | RBI | 6–12 months | Avoid by using Razorpay wallet instead |

### Data privacy (DPDP Act 2023)

- User consent for data collection must be obtained explicitly at signup
- Users have the right to delete their account and all associated PII
- Data processing agreement (DPA) must be signed with all third-party vendors (Mapbox, MSG91, Razorpay, etc.)
- All PII (phone numbers, Aadhaar data, GPS history) must be stored on Indian servers (data localization)
- GPS tracking must be disclosed clearly in the privacy policy and app permissions

### GST compliance

- Platform commission (18–22%) attracts 18% GST
- Generate GST-compliant invoices for every trip where payment passes through the platform
- Corporate accounts get tax invoices monthly
- Driver is not the GST payer if registered as an individual (under ₹20L turnover threshold)

### Insurance

- Commercial vehicle insurance is the driver's responsibility (verify during KYC)
- Rider accident cover: optional, via embedded insurance API (Acko or Digit), ₹1 per ride
- Platform liability insurance: consult legal counsel for appropriate coverage level

---

## 14. Glossary

| Term | Definition |
|---|---|
| **H3** | Uber's open-source hexagonal geospatial indexing system. Resolution 9 cells are ~170m in diameter — used for driver proximity queries and surge pricing zones. |
| **BullMQ** | Redis-backed job queue library for Node.js. Used for async background jobs (KYC processing, payouts, PDF generation). |
| **ETA** | Estimated Time of Arrival — time for driver to reach rider's pickup location. |
| **Surge multiplier** | A number ≥ 1.0 that multiplies the base fare during high-demand periods. 1.5× means 50% more than normal price. |
| **UPI autopay** | A NACH (National Automated Clearing House) mandate linked to a UPI ID. Allows the platform to charge a fixed or variable amount automatically per trip without the rider needing to approve each payment. |
| **Hypertable** | A TimescaleDB abstraction that automatically partitions a PostgreSQL table by time. Used for `trip.gps_tracks`. Queries on recent time ranges are dramatically faster than plain PostgreSQL. |
| **PgBouncer** | A lightweight PostgreSQL connection pooler. Sits between the app and PostgreSQL, reducing the number of real database connections from ~200 (app connections) to ~20 (real PG connections). |
| **Domain event** | A message emitted by a module when something meaningful happens in its domain (e.g., `trip.completed`). Other modules subscribe to these events without the emitting module knowing who's listening. |
| **Shared kernel** | The `/shared` directory containing code that multiple modules depend on — but only primitives (types, errors, logger). No business logic. |
| **GTM** | Go-to-market — the plan for acquiring riders and drivers in a new city. |
| **KYC** | Know Your Customer — the document verification process for driver onboarding. |
| **DPDP Act** | Digital Personal Data Protection Act, 2023 — India's primary data privacy law. |
| **UTR** | Unique Transaction Reference — the reference number assigned by NPCI to every UPI/IMPS transaction. Used to reconcile driver payouts. |
| **Canary deploy** | A deployment strategy where a small percentage of traffic (e.g., 5%) is routed to the new version before full rollout. Used to detect regressions before they affect all users. |

---

## 15. Rules for AI Agents & Junior Engineers

This section is the most important one for day-to-day work. Read it every time you pick up a task.

### Before writing any code

1. **Find the right module.** Check Section 5. Every piece of logic belongs to exactly one module. If you are unsure which module owns something, ask before writing code.

2. **Check if it's a domain event or a direct call.** If you need Module A to trigger a side effect in Module B, use a domain event (Section 3, Rule 3). If you need Module A to query data from Module B synchronously, use Module B's public API in `index.ts`. Never access Module B's internal files.

3. **Check the database schema first.** Before writing a query, look at Section 6 to understand which table you are querying and which schema it belongs to. Ensure your query only touches tables owned by your current module.

4. **Look for the existing pattern.** Before implementing auth, look at the auth module. Before implementing a payment, look at the payment module. The existing code is the pattern. Follow it.

### When generating code (AI agents)

- **Generate TypeScript, not JavaScript.** All code is strictly typed. No `any` unless there is no alternative and it is accompanied by a comment explaining why.
- **Always add Zod validation** at the API boundary (request body, query params). Never trust unvalidated input inside module logic.
- **Always add error handling.** No unhandled promise rejections. Use the `AppError` class from `/shared/errors`.
- **Generate the test alongside the code.** Every function in a module service file needs a corresponding unit test. If generating a new endpoint, also generate a Supertest integration test.
- **Never generate a SQL query that JOINs across schemas.** This is an automatic rejection in code review.
- **Emit a domain event for side effects.** If the code you are writing causes something to happen in another module (send a notification, process a payment), do it via a domain event, not a direct import.
- **Use structured logging.** Every significant action must emit a Pino log with at minimum: `{ module, action, userId?, tripId?, durationMs }`.

### Code review checklist (for junior engineers)

Before opening a PR, verify:

- [ ] No imports from another module's `/src/` directory (only from `/index.ts`)
- [ ] No SQL queries joining across schemas
- [ ] All API inputs validated with Zod
- [ ] Error responses follow RFC 7807 format
- [ ] New tables have a migration file in `infra/db/migrations/`
- [ ] Migration file follows naming convention and does not alter existing columns in a breaking way
- [ ] Tests exist and pass locally (`npm run test`)
- [ ] Lint passes (`npm run lint`) — especially the module boundary ESLint rule
- [ ] No `console.log` — use `logger.info()` from shared kernel
- [ ] No hardcoded secrets — all config comes from environment variables via the config module
- [ ] WebSocket events are documented in Section 8 if you added or changed them
- [ ] If you created a new domain event, it is documented in the module's "Emits" list in Section 5

### What "good" looks like

A well-written feature in this codebase:
- Lives entirely within one module directory
- Exposes exactly what it needs to via `index.ts` and nothing more
- Emits a named domain event when it completes a meaningful action
- Has a repository layer (database queries) cleanly separated from the service layer (business logic)
- Has unit tests for the service layer and integration tests for the repository layer
- Fails with a clear, typed error that maps to an HTTP status code and RFC 7807 body
- Logs the key action with structured fields

A poorly written feature:
- Imports from another module's internal files
- JOINs across database schemas in SQL
- Has business logic in the route handler instead of the service
- Has no tests
- Uses `console.log` or swallows errors silently
- Hardcodes a config value that should come from environment

---

*End of PRD v1.0*

*This document should be updated whenever a significant architectural decision is changed, a new module is added, or a phase is completed. The person who implements a change owns updating the PRD to match.*
