# Mr. Rideo Integration Audit Report

This audit verifies end-to-end user journeys to determine if the Rider App, Driver App, Backend, and third-party services are fully integrated.

The reality: **The mobile applications are completely disconnected from the newly developed REST APIs.** They currently rely on a mock/legacy WebSocket implementation and hardcoded UI states.

---

## RIDER APP JOURNEY

| Flow | UI Complete | Backend Complete | API Connected | Tested | Status |
|------|------------|------------------|---------------|--------|--------|
| **Login (OTP)** | Yes | Yes | ❌ No | No | DISCONNECTED |
| **Search Pickup** | Yes | N/A | 🟡 Direct to Ola | No | NO BACKEND ROUTING |
| **Estimate Fare** | Yes | Yes | ❌ No | No | DISCONNECTED |
| **Book Ride** | Yes | Yes | 🟡 Legacy WS | No | USING OBSOLETE WS |
| **Driver Assigned** | Yes | Yes | ✅ WS Event | No | WS INTEGRATED |
| **Live Tracking** | Yes | Yes | ✅ WS Event | No | WS INTEGRATED |
| **Chat/Call** | ❌ No | ❌ No | ❌ No | No | NOT IMPLEMENTED |
| **Trip Started** | Yes | Yes | ❌ No | No | DISCONNECTED |
| **Trip Completed** | Yes | Yes | ❌ No | No | DISCONNECTED |
| **Payment** | 🟡 Stub | 🟡 Stub | ❌ No | No | NOT IMPLEMENTED |
| **Rating** | ❌ No | 🟡 Schema Only | ❌ No | No | NOT IMPLEMENTED |
| **History** | Yes | ❌ No Endpoint | ❌ No | No | MOCK DATA ONLY |

---

## DRIVER APP JOURNEY

| Flow | UI Complete | Backend Complete | API Connected | Tested | Status |
|------|------------|------------------|---------------|--------|--------|
| **Login (OTP)** | Yes | Yes | ❌ No | No | DISCONNECTED |
| **Upload KYC** | ❌ No | Yes (R2 URLs) | ❌ No | No | DISCONNECTED |
| **Online/Offline** | Yes | Yes | ✅ WS Event | No | WS INTEGRATED |
| **Accept Ride** | Yes | Yes | ❌ No | No | DISCONNECTED (MOCK) |
| **Navigation** | Yes | N/A | 🟡 Direct to Ola | No | NO BACKEND ROUTING |
| **Arrive at Pickup** | Yes | Yes | ❌ No | No | DISCONNECTED (MOCK) |
| **Start Trip (OTP)** | Yes | Yes | ❌ No | No | DISCONNECTED (MOCK) |
| **End Trip** | Yes | Yes | ❌ No | No | DISCONNECTED (MOCK) |
| **Earnings/Wallet** | Yes | ❌ No Endpoint | ❌ No | No | MOCK DATA ONLY |

---

## PUNCH LIST (Ordered by Impact)

To make the first real ride succeed from beginning to end, we must execute this integration checklist immediately:

### P0 - CRITICAL (Blocks Core Flow)
1. **Wire Authentication:** Connect Rider and Driver apps to `POST /api/auth/otp/request` and `POST /api/auth/otp/verify`. Store the returned JWT securely.
2. **Inject JWT:** Update the Flutter HTTP clients to inject the `Authorization: Bearer <token>` header in all requests.
3. **Trip Estimation & Booking:** Replace the Rider App's WebSocket `request_ride` message with standard HTTP calls to `POST /api/trips/estimate` and `POST /api/trips/request`.
4. **Driver Trip Lifecycle:** Connect the Driver App UI buttons (Accept, Arrive, Start, Complete) to their respective HTTP endpoints (`/api/trips/:id/accept`, etc.) instead of updating local state.
5. **WebSocket Authentication:** Refactor the WebSocket connection in Flutter to pass the JWT/UserId so the backend knows which user is connecting.

### P1 - HIGH (Blocks Pilot Reliability)
6. **FCM Token Registration:** Immediately after login, both mobile apps must call `POST /api/auth/fcm-token` to register for push notifications.
7. **KYC Upload UI:** Build the screens in the Driver App to take photos of documents and POST them using the `GET /api/kyc/upload-url` presigned bucket URLs.
8. **Map API Key Protection:** Move direct Ola Maps calls (`autocomplete`, `directions`) from the mobile client to the backend to prevent API key theft, OR enforce strict referrer restrictions in the Ola Maps dashboard.

### P2 - MEDIUM (Post-Pilot)
9. **Trip History Endpoint:** Build `GET /api/trips` on the backend so the History tab in the Rider App doesn't show mock data.
10. **Driver Earnings Endpoint:** Build a wallet/payout endpoint for the Driver App's earnings tab.
