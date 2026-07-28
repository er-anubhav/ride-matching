import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';

class SearchingDriverScreen extends ConsumerStatefulWidget {
  const SearchingDriverScreen({super.key});

  @override
  ConsumerState<SearchingDriverScreen> createState() => _SearchingDriverScreenState();
}

class _SearchingDriverScreenState extends ConsumerState<SearchingDriverScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state change to matched
    ref.listen<BookingState>(bookingProvider, (previous, next) {
      if (next.status == RideBookingStatus.driverArriving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🎉 Captain ${next.driverName ?? 'found'}! On the way to you.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        context.go('/tracking');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Pulsing Radar Circle Animation
            Center(
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildPulseRing(1.0 * _pulseController.value),
                      _buildPulseRing(0.6 * _pulseController.value),
                      _buildPulseRing(0.2 * _pulseController.value),
                      // Brand motorbike icon center node
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.motorcycle,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 48),

            Text(
              "Finding your ride...",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                
                letterSpacing: -0.5,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Matching you with the nearest UrbanPulse captains",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // Cancellation Box Drawer
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.shieldCheck, color: AppColors.success, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Your price is locked. No surge will be applied.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SecondaryButton(
                    text: "Cancel Ride Request",
                    onPressed: () {
                      ref.read(bookingProvider.notifier).reset();
                      context.pop();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRing(double scale) {
    return Container(
      width: 88 + (160 * scale),
      height: 88 + (160 * scale),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.12 * (1.0 - scale)),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.24 * (1.0 - scale)),
          width: 1.5,
        ),
      ),
    );
  }
}
