import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/driver_state_providers.dart';
import '../providers/theme_provider.dart';

class TripEndScreen extends ConsumerWidget {
  const TripEndScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider);
    final state = ref.watch(driverStateProvider);
    final notifier = ref.read(driverStateProvider.notifier);

    final double price = state.price ?? 0.0;
    final double commission = price * 0.18;
    final double payout = price * 0.82;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Success Icon & Title
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.checkCircle2,
                    color: AppColors.success,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  "Trip Completed",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  "Passenger safely dropped off at destination",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),

              // Glass Card for Fare Breakdown
              GlassCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "FARE SUMMARY",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFareRow("Total Fare Charged", "₹${price.toStringAsFixed(2)}"),
                    const SizedBox(height: 12),
                    _buildFareRow("Platform Commission (18%)", "- ₹${commission.toStringAsFixed(2)}"),
                    Divider(color: AppColors.border, height: 32),
                    _buildFareRow(
                      "Your Payout (82%)",
                      "₹${payout.toStringAsFixed(2)}",
                      isBold: true,
                      valueColor: AppColors.success,
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Rating / Feedback Card
              GlassCard(
                borderRadius: 16,
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(LucideIcons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        "You earned 5.0 rating stars from ${state.riderName ?? 'Rider'}",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Button to Go Online Again
              ElevatedButton(
                onPressed: () {
                  notifier.resetToOnline();
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(56),
                ),
                child: const Text("READY FOR NEXT RIDE"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w300 : FontWeight.w400,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.w300 : FontWeight.w400,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
