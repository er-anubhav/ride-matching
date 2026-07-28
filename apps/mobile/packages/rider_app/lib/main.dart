import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/shared.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/theme_provider.dart';
import 'router/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const RideMatchingRiderApp(),
    ),
  );
}

class RideMatchingRiderApp extends ConsumerWidget {
  const RideMatchingRiderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    
    // Automatically keep AppColors.brightness in sync with the current active theme
    if (themeMode == ThemeMode.light) {
      AppColors.brightness = Brightness.light;
    } else if (themeMode == ThemeMode.dark) {
      AppColors.brightness = Brightness.dark;
    } else {
      // By accessing MediaQuery platformBrightness, this build method will run
      // again whenever the system theme switches (light -> dark or vice versa).
      AppColors.brightness = MediaQuery.platformBrightnessOf(context);
    }

    return MaterialApp.router(
      title: 'Ride Matching',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
