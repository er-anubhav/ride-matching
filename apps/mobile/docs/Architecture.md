# Mobile Architecture Documentation

## Overview

The Ride Matching mobile apps (`rider_app` and `driver_app`) follow a clean layered architecture leveraging Flutter Riverpod for state management, GoRouter for declarative navigation, and a shared core library for design tokens and API services.

---

## Architectural Layers

```
+-------------------------------------------------------+
|                    UI Layer                           |
|  (Screens, Widgets, Dialogs, Modals, Forms)           |
+-------------------------------------------------------+
                           |
                           v
+-------------------------------------------------------+
|                 State Management Layer                |
|  (Riverpod NotifierProvider, StateNotifierProvider)    |
+-------------------------------------------------------+
                           |
                           v
+-------------------------------------------------------+
|                   Service Layer                       |
|  (ApiClient, WsService, Geolocator, SharedPreferences)|
+-------------------------------------------------------+
                           |
                           v
+-------------------------------------------------------+
|                Backend API / WebSockets               |
|  (Fastify HTTP REST + Redis GEO WebSocket Gateway)    |
+-------------------------------------------------------+
```

---

## Shared Library (`packages/shared`)

- **`ApiClient`**: Standardized HTTP REST client handling JWT headers, base URL resolution (`10.0.2.2:8080` vs `localhost:8080`), token persistence, and RFC-7807 error parsing.
- **`WsService`**: Single-instance WebSocket service handling connection setup, auto-reconnect backoff, heartbeat `PING` packets every 25s, and broadcast streams for real-time location and trip state events.
- **Theme & Widgets**: Design tokens (`AppColors`, `AppTypography`), primary buttons, text inputs, card containers, and status badges.

---

## State Management (Riverpod)

- **`rider_app` (`ui_state_providers.dart`)**: Manages trip request creation, active ride tracking state, route polylines, driver location stream, fare calculation states, and profile updates.
- **`driver_app` (`driver_state_providers.dart`)**: Manages duty status (`offline`, `online`, `incomingRequest`, `arrivingToPickup`, `arrivedAtPickup`, `tripInProgress`, `paymentCollection`), incoming offer countdown timer, location position stream, and KYC document upload progress.
