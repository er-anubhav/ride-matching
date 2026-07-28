# UrbanPulse Mobile Applications Monorepo

Welcome to the **UrbanPulse** mobile client repository. This monorepo contains the Flutter applications for both **Riders** and **Drivers**, along with a shared UI and API library.

---

## 📱 Workspace Structure

```
apps/mobile/
├── packages/
│   ├── rider_app/       # Flutter application for Riders
│   ├── driver_app/      # Flutter application for Drivers
│   └── shared/          # Shared design design system, widgets, theme, & API services
├── pubspec.yaml         # Workspace root configuration
└── melos.yaml           # Melos monorepo management configuration
```

---

## 🚀 Quick Start

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.0.0`)
- [Dart SDK](https://dart.dev) (`>= 3.0.0`)
- Melos (`dart pub global activate melos`)

### Installation & Setup

1. **Bootstrap Workspace Dependencies**:
   ```bash
   cd apps/mobile
   melos bootstrap
   ```

2. **Run Rider App**:
   ```bash
   cd packages/rider_app
   flutter run
   ```

3. **Run Driver App**:
   ```bash
   cd packages/driver_app
   flutter run
   ```

---

## 🛠 Features Overview

### Rider App (`packages/rider_app`)
- **Ride Booking**: Destination search, route preview, and vehicle category fare estimations (Bike, Auto, Cab) powered by server-side Ola Maps API.
- **Live Ride Tracking**: Real-time driver vehicle location marker updates via WebSockets.
- **Trip Lifecycle**: Complete request → match → arrival → trip progress → completion flow.
- **Trip History & Profile**: Past rides history, emergency contacts, profile edit, and photo upload.

### Driver App (`packages/driver_app`)
- **Duty Toggle**: Instant Online/Offline duty state switch with automatic GPS location broadcasts to backend.
- **Trip Dispatch Acceptance**: Real-time trip offer notifications with pickup/dropoff details and countdown timer.
- **Active Navigation HUD**: Pickup and dropoff navigation HUD with state transitions (`ARRIVED`, `START_TRIP`, `COMPLETED`).
- **KYC Onboarding**: Document upload (Driving License, Aadhaar, Vehicle RC) using Cloudflare R2 pre-signed URLs.
- **Earnings & Stats**: Daily/weekly fare summaries and trip completion metrics.
