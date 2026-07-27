import 'package:go_router/go_router.dart';

import '../screens/onboarding_screens.dart';
import '../screens/home_screen.dart';
import '../screens/destination_picker_screen.dart';
import '../screens/ride_summary_screen.dart';
import '../screens/searching_driver_screen.dart';
import '../screens/tracking_screen.dart';
import '../screens/trip_summary_screen.dart';
import '../screens/user_profile_screens.dart';
import '../screens/trip_history_screen.dart';

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
      path: '/auth/profile-setup',
      builder: (context, state) => const ProfileSetupScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/destination-picker',
      builder: (context, state) => const DestinationPickerScreen(),
    ),
    GoRoute(
      path: '/ride-summary',
      builder: (context, state) => const RideSummaryScreen(),
    ),
    GoRoute(
      path: '/searching-driver',
      builder: (context, state) => const SearchingDriverScreen(),
    ),
    GoRoute(
      path: '/tracking',
      builder: (context, state) => const TrackingScreen(),
    ),
    GoRoute(
      path: '/trip-summary',
      builder: (context, state) => const TripSummaryScreen(),
    ),
    GoRoute(
      path: '/wallet',
      builder: (context, state) => const WalletScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
    GoRoute(
      path: '/profile/payment',
      builder: (context, state) => const WalletPaymentScreen(),
    ),
    GoRoute(
      path: '/profile/security',
      builder: (context, state) => const SecuritySosScreen(),
    ),
    GoRoute(
      path: '/profile/help',
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const TripHistoryScreen(),
    ),
  ],
);
