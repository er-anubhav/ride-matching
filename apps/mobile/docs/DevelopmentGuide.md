# Development & Best Practices Guide

## Code Style & Analysis

1. Always run static analysis before opening pull requests:
   ```bash
   melos exec -- flutter analyze
   ```

2. Format Dart code according to official guidelines:
   ```bash
   melos exec -- dart format .
   ```

## Adding New Features

- **Shared Components**: Place reusable UI tokens, icons, or widgets in `packages/shared/lib/widgets/shared_widgets.dart`.
- **API Endpoints**: Add HTTP helper methods in `packages/shared/lib/api/api_client.dart`.
- **WebSocket Messages**: Register message types in `packages/shared/lib/api/ws_service.dart`.
- **Navigation**: Define new screen paths in `app_router.dart` for the target application.
