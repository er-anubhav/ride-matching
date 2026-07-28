# Ride Matching Production Execution Roadmap

This is the tactical execution plan to take Ride Matching from its current functional prototype state to a production-ready system capable of handling a real-world pilot in a single city with paying users. 

**Core Directive:** We are optimizing for time-to-market. No overengineering. No rewrites. We fix what is broken, replace the mocks with real integrations, and ship.

---

## Phases & Remaining Tasks

### 1. Infrastructure & Backend Services

#### Task: Enforce Strict PostgreSQL Persistence & Remove Memory Bypasses
* **Objective:** Ensure all state (Users, Trips, Pricing) is written to PostgreSQL, removing the `memoryStore` try/catch bypasses.
* **Why it matters for production:** A system running on an in-memory store will lose all data on crash and cannot scale horizontally.
* **Dependencies:** None
* **Estimated effort:** 2 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** High (Touches core trip state machine)
* **Deliverables:** Updated `TripService`, `UserService`, `PricingService`.
* **Definition of Done:** 100% of trips and users are persisted to PostgreSQL. In-memory fallback is deleted from the codebase.
* **Testing required:** Integration tests verifying DB writes. Load test simulated trips.
* **Rollback strategy:** Git revert (Code level only; DB schema is already correct).

#### Task: Introduce Redis for Geo-Hashing & WebSocket State
* **Objective:** Replace in-memory driver location tracking with Redis GEO and Pub/Sub.
* **Why it matters for production:** Required to scale WebSockets across multiple Node.js instances and accurately match drivers spatially.
* **Dependencies:** AWS ElastiCache / Redis Deployment
* **Estimated effort:** 3 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Medium
* **Deliverables:** `redisClient.ts`, updated `ws_handler.ts`, updated Matching Engine logic.
* **Definition of Done:** Driver locations are updated and queried exclusively via Redis. WebSocket broadcasts utilize Redis Pub/Sub.
* **Testing required:** Multi-instance WebSocket load testing.
* **Rollback strategy:** Feature flag to fallback to single-instance memory (not recommended for prod).

#### Task: Background Job Queue (BullMQ)
* **Objective:** Implement BullMQ on top of Redis for asynchronous tasks (e.g., sending receipts, delayed trip timeout checks).
* **Why it matters for production:** Prevents the main Node.js event loop from blocking during heavy I/O or network failures.
* **Dependencies:** Redis Implementation
* **Estimated effort:** 2 Days
* **Priority:** P1 (Blocks Pilot: No, but highly recommended)
* **Risk level:** Low
* **Deliverables:** BullMQ worker setup, job producers for receipts.
* **Definition of Done:** Long-running tasks are offloaded to queues with retry mechanisms.
* **Testing required:** Unit testing job failures and retries.
* **Rollback strategy:** Revert to synchronous execution.

### 2. Authentication & Security

#### Task: Integrate Real SMS OTP Gateway
* **Objective:** Replace hardcoded `rider-123` mocks with a real SMS provider (Fast2SMS/Twilio).
* **Why it matters for production:** We cannot launch a pilot without verifying real phone numbers.
* **Dependencies:** Fast2SMS API Key (Configured)
* **Estimated effort:** 1 Day
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Low
* **Deliverables:** `OtpService` integration, rate-limiting on OTP requests.
* **Definition of Done:** Users can only log in by receiving and submitting a valid SMS code.
* **Testing required:** Manual E2E testing on real devices.
* **Rollback strategy:** Toggle mock OTP generation via environment variable for testing.

#### Task: Implement API Rate Limiting
* **Objective:** Protect public endpoints (especially OTP and Trip Request) from abuse.
* **Why it matters for production:** Prevents SMS toll fraud and DDOS attacks.
* **Dependencies:** Redis
* **Estimated effort:** 1 Day
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Low
* **Deliverables:** Fastify rate-limit middleware configured with Redis backend.
* **Definition of Done:** 429 Too Many Requests returned when thresholds are exceeded.
* **Testing required:** Automated script to trigger rate limits.
* **Rollback strategy:** Disable middleware via ENV.

### 3. Payments & KYC

#### Task: Payment Gateway Integration (Razorpay/Stripe)
* **Objective:** Replace the `PaymentService` stub with actual payment processing.
* **Why it matters for production:** We need to collect money.
* **Dependencies:** Payment Gateway Sandbox/Prod Credentials
* **Estimated effort:** 3 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** High
* **Deliverables:** Payment intent creation, webhook listener for success/failure, DB updates.
* **Definition of Done:** Real money can be captured for a completed trip.
* **Testing required:** Extensive testing with gateway mock cards and edge cases (declines, timeouts).
* **Rollback strategy:** Revert to Cash-only trips.

#### Task: Cloudflare R2 Document Upload (KYC)
* **Objective:** Enable drivers to upload DL and Registration documents to Cloudflare R2.
* **Why it matters for production:** Regulatory compliance and safety.
* **Dependencies:** Cloudflare R2 Setup (Completed)
* **Estimated effort:** 2 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Low
* **Deliverables:** Pre-signed URL generation API, Webhook/DB update on successful upload.
* **Definition of Done:** Documents are securely stored in R2 and linked to the Driver's profile.
* **Testing required:** File upload limits, format validation (PDF/JPG only).
* **Rollback strategy:** Manual email collection (Fallback).

### 4. Admin Dashboard & Operations

#### Task: Basic Admin Operations API
* **Objective:** Create endpoints to manually verify KYC and view active trips.
* **Why it matters for production:** Operations team needs to approve drivers before they can accept rides.
* **Dependencies:** KYC Uploads
* **Estimated effort:** 2 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Low
* **Deliverables:** Admin Auth middleware, `/admin/drivers/approve` endpoint, `/admin/trips` endpoint.
* **Definition of Done:** Support staff can toggle a driver's `isVerified` status to true.
* **Testing required:** Role-based access control (RBAC) tests.
* **Rollback strategy:** DB manual SQL updates (Fallback).

### 5. Maps, Navigation & Pricing

#### Task: Dynamic Pricing & Ola Maps Integration
* **Objective:** Calculate accurate trip distances and ETAs using Ola Maps instead of raw Haversine distances. Read base prices from DB.
* **Why it matters for production:** Haversine (straight-line) distance severely underprices rides in urban areas.
* **Dependencies:** Ola Maps API Key (Configured)
* **Estimated effort:** 2 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Medium
* **Deliverables:** `MapsService` fetching routing data, updated `PricingService`.
* **Definition of Done:** Fares are calculated based on road distance and dynamic DB configuration.
* **Testing required:** Compare API responses with Google Maps for accuracy.
* **Rollback strategy:** Fallback to Haversine with a 1.4x road-multiplier.

### 6. Notifications & Real-time Systems

#### Task: Push Notifications (FCM)
* **Objective:** Integrate Firebase Cloud Messaging to wake up the Driver/Rider app when in the background.
* **Why it matters for production:** WebSockets drop when the app is backgrounded. Drivers will miss ride requests without FCM.
* **Dependencies:** Firebase Project (Needs setup)
* **Estimated effort:** 3 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Medium
* **Deliverables:** FCM token registration API, backend push triggers for Trip states.
* **Definition of Done:** Push notifications reliably arrive on iOS/Android devices.
* **Testing required:** Physical device testing across OS versions.
* **Rollback strategy:** None. Mandatory for operation.

#### Task: Disable "Virtual Driver" Simulation
* **Objective:** Remove the fallback logic that spawns virtual drivers when no real driver accepts.
* **Why it matters for production:** Riders must only be matched with actual humans on the road.
* **Dependencies:** Real driver apps deployed.
* **Estimated effort:** 0.5 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Low
* **Deliverables:** Cleaned `ws_handler.ts` and `TripService`.
* **Definition of Done:** Trips timeout and fail if no physical driver accepts.
* **Testing required:** E2E test of the "No drivers available" flow.
* **Rollback strategy:** Re-enable via ENV for demo purposes only.

### 7. Deployment, Monitoring & Logging

#### Task: Dockerization & CI/CD Pipeline
* **Objective:** Containerize the Node.js backend and Golang matching engine. Setup GitHub Actions for automated deployment.
* **Why it matters for production:** Ensures repeatable, safe deployments without manual SSH.
* **Dependencies:** Production Host (AWS ECS/DigitalOcean)
* **Estimated effort:** 2 Days
* **Priority:** P0 (Blocks Pilot: Yes)
* **Risk level:** Medium
* **Deliverables:** `Dockerfile`, `.github/workflows/deploy.yml`.
* **Definition of Done:** Merging to `main` triggers a build and zero-downtime deployment.
* **Testing required:** Triggering a staging deployment.
* **Rollback strategy:** Revert GitHub commit or redeploy previous Docker image tag.

#### Task: APM and Uptime Monitoring
* **Objective:** Hook up Datadog, New Relic, or Sentry for application performance and error tracking.
* **Why it matters for production:** We cannot operate blindly. We need alerts when trips fail or APIs 500.
* **Dependencies:** None
* **Estimated effort:** 1 Day
* **Priority:** P1 (Blocks Pilot: No, but reckless to skip)
* **Risk level:** Low
* **Deliverables:** APM agent injected into Node.js, Slack alert integration.
* **Definition of Done:** Unhandled exceptions post to a Slack #alerts channel.
* **Testing required:** Manually throw an error and verify alert delivery.
* **Rollback strategy:** Remove APM agent.

---

## Master Production Checklist

- [ ] Remove `try/catch` in-memory DB bypasses.
- [ ] Disable Virtual Driver auto-dispatch logic.
- [ ] Implement Redis for WebSocket State & Geo-hashing.
- [ ] Integrate Fast2SMS for real OTP login.
- [ ] Integrate Razorpay/Stripe for Payment processing.
- [ ] Implement Cloudflare R2 KYC Document Upload.
- [ ] Integrate Ola Maps for routing distance/ETA (replace Haversine).
- [ ] Read pricing configurations dynamically from PostgreSQL.
- [ ] Integrate Firebase Cloud Messaging (FCM) for background push notifications.
- [ ] Implement Redis-backed API Rate Limiting.
- [ ] Build basic Admin KYC Verification API.
- [ ] Dockerize Backend Services.
- [ ] Setup CI/CD Pipeline (GitHub Actions).
- [ ] Configure Sentry/APM Error Tracking.
- [ ] Execute E2E Load Test on Production Infrastructure.

---

## Critical Path (Blockers for First Real Customer)

1. **Persistence:** Remove Memory Bypasses -> PostgreSQL Strict Mode.
2. **Real World Logic:** Disable Virtual Drivers + Integrate Ola Maps for Routing.
3. **Scale:** Implement Redis (WebSockets/Geo).
4. **Security:** Real SMS OTP + Rate Limiting.
5. **Legality & Safety:** R2 KYC Uploads + Admin KYC Approval API.
6. **Revenue:** Payment Gateway Integration.
7. **Reliability:** Push Notifications (FCM).
8. **Deployment:** Dockerization + Production Hosting.

---

## Nice-to-Have After Launch (P2 / Post-Pilot)

* **BullMQ Background Jobs:** (If volume is low, synchronous async/await is fine for Week 1).
* **ClickHouse Analytics:** (PostgreSQL read-replicas are fine for initial dashboarding).
* **Automated Refund Processing:** (Can be done manually via Stripe/Razorpay dashboard initially).
* **Complex Surge Pricing:** (Static pricing per zone is sufficient for a 1-city pilot).
* **Advanced Fraud Detection:** (Basic rate limiting and manual KYC review is enough initially).

---

## 30-Day Sprint Plan

### Week 1: Core State & Infrastructure
* **Deliverables:** PostgreSQL strict enforcement, Redis integration, Virtual Drivers removed, Dockerfile created.
* **Milestones:** Backend is stateless, horizontally scalable, and purely DB-driven.
* **Testing goals:** Multi-container WebSocket load testing.
* **Demo goals:** Run a full trip locally with zero in-memory fallback.

### Week 2: External Integrations (The Heavy Lifting)
* **Deliverables:** Fast2SMS OTP, Ola Maps Routing, Cloudflare R2 Uploads, Razorpay/Stripe Integration.
* **Milestones:** System interacts with the real world (SMS, Money, Real Roads).
* **Testing goals:** Process a live $1.00 transaction and verify a physical SMS delivery.
* **Demo goals:** End-to-end signup and payment flow.

### Week 3: Reliability & Operations
* **Deliverables:** FCM Push Notifications, Rate Limiting, Admin KYC API, Sentry Integration.
* **Milestones:** Drivers can be backgrounded and still receive trips. Support team can approve drivers.
* **Testing goals:** iOS/Android background push delivery tests.
* **Demo goals:** Complete driver onboarding flow from upload to admin approval.

### Week 4: Deployment & QA
* **Deliverables:** CI/CD Pipeline, Staging & Production environments provisioned, Load Testing.
* **Milestones:** Infrastructure is hardened and live.
* **Testing goals:** Simulate 50 concurrent drivers and 20 concurrent trip requests in production.
* **Demo goals:** Company-wide E2E test day (Alpha test on real streets).

---

## Ship Readiness Report

* **Infrastructure:** 20%
* **Backend:** 40%
* **APIs:** 40%
* **Authentication:** 30%
* **Driver App:** (Assumed 50% based on backend mocks)
* **Rider App:** (Assumed 50% based on backend mocks)
* **Matching:** 50%
* **Pricing:** 30%
* **Maps:** 10%
* **Payments:** 5%
* **Notifications:** 0%
* **Admin:** 0%
* **Monitoring:** 20%
* **Security:** 30%
* **CI/CD:** 0%
* **Documentation:** 60%
* **Testing:** 5%
* **DevOps:** 10%
* **Scalability:** 10%
* **Pilot Readiness:** 15%
* **Production Readiness:** 10%

---

> "If the engineering team had to launch in 10 days, this is exactly what I would build next in order."

1. **Days 1-2:** Strip all `try/catch` memory bypasses and virtual drivers. Force PostgreSQL strict mode. Implement Redis for WebSocket pub/sub so the app doesn't break under load.
2. **Days 3-4:** Integrate Ola Maps for real routing/pricing and Fast2SMS so users can actually log in.
3. **Days 5-6:** Plug in Stripe/Razorpay. Hardcode the checkout flow if necessary, but get money flowing.
4. **Days 7-8:** Setup FCM Push Notifications (without this, the driver app is useless when minimized) and build a bare-bones Admin endpoint to approve Driver KYC manually.
5. **Days 9-10:** Wrap it in a Dockerfile, push to a managed service (Render/AWS ECS), hook up Sentry, and launch. Everything else (BullMQ, ClickHouse, Surge Pricing) waits until Day 11.
