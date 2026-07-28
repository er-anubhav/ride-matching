import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/driver_state_providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/ola_map_widget.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && AppColors.isDark);
    final state = ref.watch(driverStateProvider);
    final notifier = ref.read(driverStateProvider.notifier);

    // Watch status changes to route properly
    ref.listen<DriverState>(driverStateProvider, (previous, next) {
      if (next.dutyStatus == DriverDutyStatus.tripInProgress) {
        context.go('/trip-active');
      } else if (next.dutyStatus == DriverDutyStatus.online) {
        context.go('/home');
      }
    });

    final double dLat = state.driverLat;
    final double dLng = state.driverLng;
    final double pLat = state.pickupLat ?? (dLat + 0.01);
    final double pLng = state.pickupLng ?? (dLng + 0.01);

    final bool hasArrived = state.dutyStatus == DriverDutyStatus.arrivedAtPickup;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Navigation Route Map
          Positioned.fill(
            child: OlaMapWidget(
              centerLat: dLat,
              centerLng: dLng,
              pickupLat: dLat,
              pickupLng: dLng,
              destLat: pLat,
              destLng: pLng,
              zoom: 15.0,
              isDark: isDark,
            ),
          ),

          // 2. Top Navigation Guideline Panel
          Positioned(
            top: 56,
            left: 20,
            right: 20,
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              borderRadius: 16,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.navigation, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasArrived ? "ARRIVED" : "ROUTING TO PICKUP",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasArrived
                              ? "Wait for passenger to board"
                              : "Arriving at pickup location in 3 mins",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),



          // 4. Back button to cancel/decline
          Positioned(
            top: 140,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'cancel_btn',
              mini: true,
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onPressed: () {
                notifier.declineRide();
                context.go('/home');
              },
              child: const Icon(LucideIcons.x),
            ),
          ),

          // 5. Rider Details & Slide to Arrive Bottom Sheet
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: GlassCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.surfaceCard,
                        child: Icon(LucideIcons.user, color: AppColors.textPrimary),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.riderName ?? "Rider Name",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(LucideIcons.star, color: Colors.amber, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  "4.8 Rating",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () async {
                          final phone = state.riderPhone ?? "9876543210";
                          final uri = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          }
                        },
                        icon: const Icon(LucideIcons.phone, color: AppColors.primary),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(LucideIcons.messageSquare, color: AppColors.primary),
                      ),
                    ],
                  ),
                  Divider(color: AppColors.border, height: 32),
                  if (!hasArrived)
                    ElevatedButton(
                      onPressed: () => notifier.arriveAtPickup(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text("SLIDE TO SIGNAL ARRIVAL"),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => context.go('/trip-active'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text("VERIFY PASSENGER OTP"),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
