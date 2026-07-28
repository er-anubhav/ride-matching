import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/driver_state_providers.dart';
import '../providers/theme_provider.dart';
import '../widgets/ola_map_widget.dart';

class TripActiveScreen extends ConsumerStatefulWidget {
  const TripActiveScreen({super.key});

  @override
  ConsumerState<TripActiveScreen> createState() => _TripActiveScreenState();
}

class _TripActiveScreenState extends ConsumerState<TripActiveScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  String _errorMessage = '';

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && AppColors.isDark);
    final state = ref.watch(driverStateProvider);
    final notifier = ref.read(driverStateProvider.notifier);

    // If completed, go to trip completed screen
    ref.listen<DriverState>(driverStateProvider, (previous, next) {
      if (next.dutyStatus == DriverDutyStatus.tripCompleted) {
        context.go('/trip-end');
      } else if (next.dutyStatus == DriverDutyStatus.online) {
        context.go('/home');
      }
    });

    final double dLat = state.driverLat;
    final double dLng = state.driverLng;
    final double destLat = state.dropoffLat ?? (dLat - 0.01);
    final double destLng = state.dropoffLng ?? (dLng - 0.01);

    final bool isTripStarted = state.dutyStatus == DriverDutyStatus.tripInProgress;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // 1. Map Navigation
          Positioned.fill(
            child: OlaMapWidget(
              centerLat: dLat,
              centerLng: dLng,
              pickupLat: dLat,
              pickupLng: dLng,
              destLat: destLat,
              destLng: destLng,
              zoom: 15.0,
              isDark: isDark,
            ),
          ),

          // 2. Top Banner Card
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
                    child: Icon(
                      isTripStarted ? LucideIcons.navigation : LucideIcons.lock,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isTripStarted ? "ONGOING TRIP" : "RIDER BOARDING",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            color: AppColors.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isTripStarted
                              ? "Navigating to dropoff destination"
                              : "Verify passenger OTP code to start ride",
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



          // 4. Back button to cancel
          Positioned(
            top: 140,
            left: 20,
            child: FloatingActionButton(
              heroTag: 'trip_cancel_btn',
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

          // 5. Bottom Ride Management Panel
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
                              state.riderName ?? "Passenger Name",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isTripStarted ? "Dropoff Destination" : "Pickup point boarding",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
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
                    ],
                  ),
                  Divider(color: AppColors.border, height: 24),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isTripStarted
                              ? (state.dropoffAddress ?? "Dropoff Location")
                              : (state.pickupAddress ?? "Pickup Location"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (isTripStarted)
                    ElevatedButton(
                      onPressed: () => notifier.endTrip(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text("SLIDE TO END TRIP"),
                    )
                  else
                    ElevatedButton(
                      onPressed: () {
                        // Open OTP entry sheet
                        _showOtpBottomSheet(context, state.otp ?? "1234", notifier);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(56),
                      ),
                      child: const Text("ENTER PASSENGER OTP"),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOtpBottomSheet(BuildContext context, String expectedOtp, DriverStateNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 24,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Start Trip OTP",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Ask the passenger for the 4-digit code shown on their application to begin the journey.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 56,
                        height: 56,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textPrimary,
                          ),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1),
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.zero,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 3) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage,
                      style: GoogleFonts.plusJakartaSans(color: AppColors.error, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      final otpString = _controllers.map((c) => c.text).join();
                      if (otpString.length < 4) {
                        setModalState(() {
                          _errorMessage = "Please enter all 4 digits";
                        });
                        return;
                      }
                      final success = await notifier.startTrip(otpString);
                      if (success) {
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        setModalState(() {
                          _errorMessage = "Invalid OTP code";
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const Text("START RIDE"),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
