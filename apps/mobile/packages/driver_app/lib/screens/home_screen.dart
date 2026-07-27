import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/driver_state_providers.dart';
import '../widgets/ola_map_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverStateProvider);
    final notifier = ref.read(driverStateProvider.notifier);

    // Watch for state changes that redirect to navigation screens
    ref.listen<DriverState>(driverStateProvider, (previous, next) {
      if (next.dutyStatus == DriverDutyStatus.arrivingToPickup ||
          next.dutyStatus == DriverDutyStatus.arrivedAtPickup) {
        context.go('/navigation');
      } else if (next.dutyStatus == DriverDutyStatus.tripInProgress) {
        context.go('/trip-active');
      } else if (next.dutyStatus == DriverDutyStatus.tripCompleted) {
        context.go('/trip-end');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const DriverDrawer(),
      body: Stack(
        children: [
          // 1. Map View Background
          Positioned.fill(
            child: OlaMapWidget(
              centerLat: state.driverLat,
              centerLng: state.driverLng,
              zoom: 18.0,
            ),
          ),

          // 2. Hamburger Drawer Button
          Positioned(
            top: 56,
            left: 20,
            child: Builder(
              builder: (context) {
                return FloatingActionButton(
                  heroTag: 'drawer_btn',
                  mini: true,
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  child: const Icon(LucideIcons.menu),
                );
              },
            ),
          ),



          // 4. WebSocket Status Banner
          if (state.dutyStatus != DriverDutyStatus.offline)
            Positioned(
              top: 120,
              left: 20,
              right: 20,
              child: _buildWebSocketBanner(state.webSocketStatus),
            ),

          // 5. Top Metrics Panel
          Positioned(
            top: state.dutyStatus != DriverDutyStatus.offline ? 176 : 120,
            left: 20,
            right: 20,
            child: _buildTopMetricsPanel(state),
          ),

          // 6. Bottom Controls Sheet
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: _buildBottomControlsSheet(context, state, notifier),
          ),

          // 7. Incoming Dispatch Request Modal Overlay
          if (state.dutyStatus == DriverDutyStatus.incomingRequest)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                alignment: Alignment.bottomCenter,
                child: _buildIncomingRequestOverlay(context, state, notifier),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWebSocketBanner(WebSocketStatus status) {
    if (status == WebSocketStatus.connected) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F3A2E).withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.wifi, color: AppColors.success, size: 16),
            const SizedBox(width: 8),
            Text(
              "Connected to Real-Time Dispatch System",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    final isConnecting = status == WebSocketStatus.connecting;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isConnecting ? const Color(0xFF332001).withOpacity(0.9) : const Color(0xFF3D1313).withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isConnecting ? AppColors.warning.withOpacity(0.4) : AppColors.error.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: isConnecting
                ? CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning)
                : Icon(LucideIcons.wifiOff, color: AppColors.error, size: 14),
          ),
          const SizedBox(width: 8),
          Text(
            isConnecting ? "Connecting to dispatch server..." : "Disconnected. Offline mode fallback.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopMetricsPanel(DriverState state) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricColumn("Earnings", "₹${state.earnings.toStringAsFixed(0)}", LucideIcons.indianRupee),
          SizedBox(
            height: 32,
            child: VerticalDivider(color: AppColors.border, width: 1),
          ),
          _buildMetricColumn("Trips", "${state.tripsCompletedCount}", LucideIcons.car),
          SizedBox(
            height: 32,
            child: VerticalDivider(color: AppColors.border, width: 1),
          ),
          _buildMetricColumn("Rating", "4.9 ★", LucideIcons.star),
        ],
      ),
    );
  }

  Widget _buildMetricColumn(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControlsSheet(BuildContext context, DriverState state, DriverStateNotifier notifier) {
    final bool isOffline = state.dutyStatus == DriverDutyStatus.offline;

    return GlassCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOffline ? AppColors.textMuted : AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                isOffline ? "You are Offline" : "You are Online & Active",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isOffline
                ? "Go online to receive customer ride dispatches."
                : "Awaiting incoming passenger pickups in your area.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => notifier.toggleDutyStatus(),
            style: ElevatedButton.styleFrom(
              backgroundColor: isOffline ? AppColors.primary : AppColors.error,
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(isOffline ? "GO ONLINE" : "GO OFFLINE"),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestOverlay(BuildContext context, DriverState state, DriverStateNotifier notifier) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      child: GlassCard(
        borderRadius: 24,
        padding: const EdgeInsets.all(24.0),
        borderColor: AppColors.primary,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer & Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "RIDE REQUEST",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: AppColors.primary,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Incoming Dispatch",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: state.requestCountdown / 15,
                        backgroundColor: AppColors.surfaceCard,
                        color: AppColors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    Text(
                      "${state.requestCountdown}s",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Divider(color: AppColors.border, height: 32),

            // Ride Fare
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Estimated Net Earnings",
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textSecondary),
                ),
                Text(
                  "₹${((state.price ?? 0.0) * 0.82).toStringAsFixed(0)}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w400,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pickup & Dropoff Address
            Row(
              children: [
                Icon(LucideIcons.mapPin, size: 16, color: AppColors.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.pickupAddress ?? "Pickup Address",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    state.dropoffAddress ?? "Dropoff Address",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => notifier.declineRide(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.border),
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text("Decline"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => notifier.acceptRide(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Accept"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DriverDrawer extends ConsumerWidget {
  const DriverDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverStateProvider);

    return Drawer(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Colors.transparent),
              currentAccountPicture: const CircleAvatar(
                backgroundColor: AppColors.primary,
                child: Icon(LucideIcons.user, color: Colors.white, size: 36),
              ),
              accountName: Text(
                state.riderName ?? "Vikram Singh",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary,
                ),
              ),
              accountEmail: Text(
                state.vehicleNumber ?? "UP32-AB-9999",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
             Divider(color: AppColors.border),

            // Drawer Items
            ListTile(
              leading: Icon(LucideIcons.home, color: AppColors.textPrimary),
              title: Text("Home Console", style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
              onTap: () {
                context.pop();
                context.go('/home');
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.indianRupee, color: AppColors.textPrimary),
              title: Text("Weekly Earnings", style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
              onTap: () {
                context.pop();
                context.go('/earnings');
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.user, color: AppColors.textPrimary),
              title: Text("Driver Profile", style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary)),
              onTap: () {
                context.pop();
                context.go('/profile');
              },
            ),
            const Spacer(),
            ListTile(
              leading: Icon(LucideIcons.logOut, color: AppColors.error),
              title: Text("Go Offline & Exit", style: GoogleFonts.plusJakartaSans(color: AppColors.error)),
              onTap: () {
                ref.read(driverStateProvider.notifier).toggleDutyStatus();
                context.pop();
                context.go('/auth/phone');
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
