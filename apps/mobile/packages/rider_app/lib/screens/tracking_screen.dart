import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';
import '../widgets/ola_map_widget.dart';

class TrackingScreen extends ConsumerWidget {
  const TrackingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booking = ref.watch(bookingProvider);
    final location = ref.watch(locationProvider);
    final currentLoc = ref.watch(currentLocationProvider);
    final defaultLat = currentLoc.value?.latitude ?? 26.8500;
    final defaultLng = currentLoc.value?.longitude ?? 80.9400;

    // Listen for state changes to show notifications or navigate
    ref.listen<BookingState>(bookingProvider, (previous, next) {
      if (next.status == RideBookingStatus.completed) {
        context.go('/trip-summary');
      } else if (previous?.status == RideBookingStatus.driverArriving &&
          next.status == RideBookingStatus.inProgress) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🚀 Ride started! Enjoy your trip.",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // 1. Live Tracking Map + SOS Button
          Expanded(
            child: Stack(
              children: [
                OlaMapWidget(
                  pickupLat: booking.status == RideBookingStatus.driverArriving
                      ? (booking.driverStartLat ?? booking.driverLat ?? defaultLat)
                      : (location.pickupLat ?? defaultLat),
                  pickupLng: booking.status == RideBookingStatus.driverArriving
                      ? (booking.driverStartLng ?? booking.driverLng ?? defaultLng)
                      : (location.pickupLng ?? defaultLng),
                  destLat: booking.status == RideBookingStatus.driverArriving
                      ? (location.pickupLat ?? defaultLat)
                      : (location.destLat ?? defaultLat),
                  destLng: booking.status == RideBookingStatus.driverArriving
                      ? (location.pickupLng ?? defaultLng)
                      : (location.destLng ?? defaultLng),
                  driverLat: booking.driverLat,
                  driverLng: booking.driverLng,
                ),
                if (booking.webSocketStatus == WebSocketStatus.connectionError)
                  Positioned(
                    top: 56,
                    left: 16,
                    right: booking.status == RideBookingStatus.inProgress ? 96 : 16,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
                        child: Row(
                          children: [
                            Icon(LucideIcons.wifiOff, color: AppColors.error, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Connection Issue",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Live tracking disconnected.",
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                ref.read(bookingProvider.notifier).retryConnection();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                "Retry",
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (booking.status == RideBookingStatus.inProgress)
                  Positioned(
                    top: 56,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => _showSosDialog(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "SOS",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Bottom sliding drawer card showing details
          Container(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 24, bottom: 32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ride status pill badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: booking.status == RideBookingStatus.driverArriving
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        booking.status == RideBookingStatus.driverArriving
                            ? "CAPTAIN ARRIVING"
                            : "TRIP IN PROGRESS",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: booking.status == RideBookingStatus.driverArriving
                              ? AppColors.textPrimary
                              : AppColors.success,
                        ),
                      ),
                    ),
                    if (booking.webSocketStatus == WebSocketStatus.connectionError) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          ref.read(bookingProvider.notifier).retryConnection();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.wifiOff, color: AppColors.error, size: 12),
                              const SizedBox(width: 6),
                              Text(
                                "CONNECTION ERROR - RETRY",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (booking.webSocketStatus == WebSocketStatus.connecting) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "CONNECTING...",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // ETA & Trip Info Summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.status == RideBookingStatus.driverArriving
                                ? "Arriving in"
                                : "Arriving at destination in",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            booking.eta ?? "5 min",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 28,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Driver code PIN (only visible during pickup phase)
                    if (booking.status == RideBookingStatus.driverArriving)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Text(
                              "START CODE",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              booking.otp ?? "0000",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 20,
                                color: AppColors.textPrimary,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Divider
                Container(
                  height: 1,
                  color: AppColors.border,
                ),
                const SizedBox(height: 20),

                // Captain Details Card
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: NetworkImage("https://images.unsplash.com/photo-1500648767791-00dcc994a43e"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.driverName ?? "Captain",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                "4.8",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(color: AppColors.textMuted, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  booking.vehicleModel ?? "Bajaj Pulsar 150",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Vehicle plate code card
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        booking.vehicleNumber ?? "UP 32 AA 0000",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Call / Message shortcuts row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        side: BorderSide(color: AppColors.border),
                        shape: const StadiumBorder(),
                        backgroundColor: Colors.transparent,
                        foregroundColor: AppColors.textPrimary,
                      ).button(
                        onPressed: () {},
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.phone, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Call Captain",
                                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: AppColors.primary,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.messageSquare, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                "Message",
                                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Cancel ride option — only visible during driverArriving phase
                if (booking.status == RideBookingStatus.driverArriving) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => _showCancelDialog(context, ref),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.xCircle, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            "Cancel Ride",
                            style: GoogleFonts.plusJakartaSans(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSosDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.alertOctagon, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Text(
              "Emergency SOS",
              style: GoogleFonts.plusJakartaSans(
                
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you in distress? Tapping below will immediately share your current location and ride tracking details with our 24/7 safety command center and local emergency authorities.",
          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Emergency safety response team has been alerted!",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(120, 44),
            ),
            child: Text(
              "Trigger SOS",
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(LucideIcons.alertTriangle, color: AppColors.error, size: 24),
            const SizedBox(width: 12),
            Text(
              "Cancel Ride?",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          "Your captain is already on the way. A cancellation fee of ₹25 may apply if you cancel now.",
          style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "Keep Ride",
              style: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              // Deduct cancellation fee from wallet
              ref.read(walletProvider.notifier).deductMoney(25.0, "Cancellation Fee");
              ref.read(bookingProvider.notifier).reset();
              ref.read(locationProvider.notifier).clearDestination();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Ride cancelled. ₹25 cancellation fee applied.",
                    style: GoogleFonts.plusJakartaSans(color: Colors.white),
                  ),
                  backgroundColor: AppColors.error,
                ),
              );

              context.go('/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(120, 44),
            ),
            child: Text(
              "Cancel Ride",
              style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

// Extends button helper
extension on ButtonStyle {
  Widget button({required VoidCallback onPressed, required Widget child}) {
    return OutlinedButton(onPressed: onPressed, style: this, child: child);
  }
}

// Map tracking painter
class TrackingMapPainter extends CustomPainter {
  final double driverLat;
  final double driverLng;

  TrackingMapPainter({required this.driverLat, required this.driverLng});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.mapBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = AppColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), roadPaint);

    // Route path line
    final routePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawLine(Offset(size.width * 0.35, size.height * 0.4), Offset(size.width * 0.35, size.height * 0.75), routePaint);

    // Rider/Destination Node
    final destPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.75), 10.0, destPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.75), 4.0, Paint()..color = Colors.white);

    // Moving Driver Node in Vibrant Purple matching brand
    final driverPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.52), 12.0, driverPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.52), 5.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
