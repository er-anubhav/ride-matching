# Monorepo Folder Structure

```
apps/mobile/
├── melos.yaml
├── pubspec.yaml
└── packages/
    ├── shared/
    │   ├── lib/
    │   │   ├── api/
    │   │   │   ├── api_client.dart       # HTTP REST client with JWT interceptor
    │   │   │   └── ws_service.dart       # WebSocket event client & location stream
    │   │   ├── theme/
    │   │   │   └── app_theme.dart        # Color tokens & typography styles
    │   │   ├── widgets/
    │   │   │   └── shared_widgets.dart   # Reusable buttons, cards, & loaders
    │   │   └── shared.dart               # Library exports
    │   └── pubspec.yaml
    │
    ├── rider_app/
    │   ├── android/
    │   │   └── app/
    │   │       └── google-services.json  # FCM Android SDK config
    │   ├── lib/
    │   │   ├── main.dart                 # App entry point & Riverpod Scope
    │   │   ├── providers/
    │   │   │   └── ui_state_providers.dart # Rider state management & GPS
    │   │   ├── router/
    │   │   │   └── app_router.dart       # GoRouter route definitions
    │   │   ├── screens/
    │   │   │   ├── home_screen.dart
    │   │   │   ├── destination_picker_screen.dart
    │   │   │   ├── searching_driver_screen.dart
    │   │   │   ├── tracking_screen.dart
    │   │   │   ├── ride_summary_screen.dart
    │   │   │   ├── trip_history_screen.dart
    │   │   │   ├── user_profile_screens.dart
    │   │   │   └── onboarding_screens.dart
    │   │   └── widgets/
    │   └── pubspec.yaml
    │
    └── driver_app/
        ├── android/
        │   └── app/
        │       └── google-services.json  # FCM Android SDK config
        ├── lib/
        │   ├── main.dart                 # App entry point
        │   ├── providers/
        │   │   └── driver_state_providers.dart # Driver state machine & GPS stream
        │   ├── router/
        │   │   └── app_router.dart       # GoRouter route definitions
        │   ├── screens/
        │   │   ├── home_screen.dart      # Duty status switch & radar
        │   │   ├── navigation_screen.dart# Pickup navigation HUD
        │   │   ├── trip_active_screen.dart# OTP verification & dropoff HUD
        │   │   ├── trip_end_screen.dart   # Cash collection & summary
        │   │   ├── earnings_screen.dart  # Payouts & fare history
        │   │   ├── onboarding_screens.dart# Vehicle details & R2 KYC upload
        │   │   └── profile_screen.dart   # Driver info & KYC badge
        │   └── widgets/
        └── pubspec.yaml
```
