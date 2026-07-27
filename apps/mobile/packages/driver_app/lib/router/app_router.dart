import 'package:go_router/go_router.dart';

import '../screens/onboarding_screens.dart';
import '../screens/home_screen.dart';
import '../screens/navigation_screen.dart';
import '../screens/trip_active_screen.dart';
import '../screens/trip_end_screen.dart';
import '../screens/earnings_screen.dart';
import '../screens/profile_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/splash',
    ),
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/auth/phone',
      builder: (context, state) => const PhoneEntryScreen(),
    ),
    GoRoute(
      path: '/auth/otp',
      builder: (context, state) => OtpVerificationScreen(
        phone: state.extra as String? ?? '',
      ),
    ),
    GoRoute(
      path: '/auth/vehicle',
      builder: (context, state) => const VehicleDetailsScreen(),
    ),
    GoRoute(
      path: '/auth/documents',
      builder: (context, state) => const DocumentUploadScreen(),
    ),
    GoRoute(
      path: '/auth/kyc-pending',
      builder: (context, state) => const KycPendingScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/navigation',
      builder: (context, state) => const NavigationScreen(),
    ),
    GoRoute(
      path: '/trip-active',
      builder: (context, state) => const TripActiveScreen(),
    ),
    GoRoute(
      path: '/trip-end',
      builder: (context, state) => const TripEndScreen(),
    ),
    GoRoute(
      path: '/earnings',
      builder: (context, state) => const EarningsScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
