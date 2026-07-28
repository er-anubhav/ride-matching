# Mobile Setup & Configuration Guide

## Prerequisites

1. **Flutter SDK**: Ensure Flutter SDK version `3.0.0` or higher is installed and present in `$PATH`.
2. **Melos Package Manager**:
   ```bash
   dart pub global activate melos
   ```

---

## Installation Steps

1. Clone the repository:
   ```bash
   git clone <repo-url>
   cd ride-matching/apps/mobile
   ```

2. Bootstrap dependencies for all packages:
   ```bash
   melos bootstrap
   ```

3. Ensure Firebase Android configuration files exist:
   - `packages/rider_app/android/app/google-services.json`
   - `packages/driver_app/android/app/google-services.json`

---

## Running Applications

### Rider App
```bash
cd packages/rider_app
flutter run
```

### Driver App
```bash
cd packages/driver_app
flutter run
```
