import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';

class TripSummaryScreen extends ConsumerStatefulWidget {
  const TripSummaryScreen({super.key});

  @override
  ConsumerState<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends ConsumerState<TripSummaryScreen> {
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingProvider);
    final location = ref.watch(locationProvider);

    // Dynamic fare breakdown from booking price
    final double totalPrice = booking.price ?? 120.0;
    final double baseFare = (totalPrice / 1.08).roundToDouble(); // reverse 8% tax
    final double taxes = double.parse((totalPrice - baseFare).toStringAsFixed(2));
    const double platformFee = 5.0;
    final double grandTotal = totalPrice + platformFee;

    final String vehicleLabel = booking.vehicleName ?? "Ride Matching Ride";
    final String destination = location.destinationAddress.isNotEmpty
        ? location.destinationAddress
        : "Destination";
    // Truncate long destination names for wallet label
    final String walletLabel = destination.length > 30
        ? destination.substring(0, 30)
        : destination;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Success check circle
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    LucideIcons.checkCircle,
                    color: AppColors.success,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  "You Have Arrived",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Center(
                child: Text(
                  "Hope you had a comfortable ride with Ride Matching",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // 1. Receipt Breakdown Card
              GlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Trip Receipt",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            vehicleLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildReceiptRow("Base Fare", "₹${baseFare.toStringAsFixed(2)}"),
                    const SizedBox(height: 8),
                    _buildReceiptRow("Taxes & GST", "₹${taxes.toStringAsFixed(2)}"),
                    const SizedBox(height: 8),
                    _buildReceiptRow("Platform Fee", "₹${platformFee.toStringAsFixed(2)}"),
                    const SizedBox(height: 12),
                    Divider(color: AppColors.border),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Total Amount Paid",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          "₹${grandTotal.toStringAsFixed(2)}",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 2. Interactive Star Rating Picker
              Center(
                child: Text(
                  "Rate Your Ride Experience",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  final isLit = starVal <= _selectedRating;
                  return IconButton(
                    iconSize: 36,
                    icon: Icon(
                      isLit ? Icons.star : Icons.star_border,
                      color: isLit ? AppColors.primary : AppColors.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRating = starVal;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Feedback Comments Box
              TextField(
                controller: _commentController,
                maxLines: 2,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: "Add your review (optional)...",
                  contentPadding: EdgeInsets.all(14),
                ),
              ),

              const Spacer(),

              // Submit & Done Button
              PrimaryButton(
                text: "Done",
                onPressed: () {
                  // Save user rating to the most recent trip
                  final trips = ref.read(tripHistoryProvider);
                  if (trips.isNotEmpty) {
                    final latestTripId = trips.first["id"] as String;
                    ref.read(tripHistoryProvider.notifier).updateTripRating(latestTripId, _selectedRating);
                  }
                  // Deduct actual ride fare from wallet
                  ref.read(walletProvider.notifier).deductMoney(grandTotal, walletLabel);
                  ref.read(bookingProvider.notifier).reset();
                  ref.read(locationProvider.notifier).clearDestination();
                  context.go('/home');
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isPromo = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            
            color: isPromo ? AppColors.success : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
