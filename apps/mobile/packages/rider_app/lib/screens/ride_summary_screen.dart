import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/theme_provider.dart';
import '../providers/ui_state_providers.dart';
import '../widgets/ola_map_widget.dart';

class RideSummaryScreen extends ConsumerStatefulWidget {
  const RideSummaryScreen({super.key});

  @override
  ConsumerState<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends ConsumerState<RideSummaryScreen> {
  int _selectedVehicleIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && AppColors.isDark);
    final location = ref.watch(locationProvider);
    final currentLoc = ref.watch(currentLocationProvider);
    final defaultLat = currentLoc.value?.latitude ?? 26.8500;
    final defaultLng = currentLoc.value?.longitude ?? 80.9400;

    final routeMetricsAsync = ref.watch(routeMetricsProvider);
    final isRoutingLoading = routeMetricsAsync.isLoading;
    final routeMetricsVal = routeMetricsAsync.value;

    final double distanceMeters = routeMetricsVal?.distanceMeters ?? 5000.0; // 5 km fallback
    final double durationSeconds = routeMetricsVal?.durationSeconds ?? 600.0; // 10 mins fallback

    final double distanceKm = distanceMeters / 1000.0;
    final double durationMins = durationSeconds / 60.0;

    final fareEstimateAsync = ref.watch(fareEstimateProvider);
    final isEstimating = fareEstimateAsync.isLoading || isRoutingLoading;
    final estimates = fareEstimateAsync.value;

    final bikePrice = (estimates?['bike'] as num?)?.toDouble() ?? (15.0 + distanceKm * 8.0);
    final autoPrice = (estimates?['auto'] as num?)?.toDouble() ?? (30.0 + distanceKm * 12.0);
    final cabPrice = (estimates?['cab'] as num?)?.toDouble() ?? (50.0 + distanceKm * 18.0);
    final cabXlPrice = (estimates?['cab'] as num?)?.toDouble() ?? (75.0 + distanceKm * 26.0); // using cab price as fallback basis

    final bikeEta = "${(durationMins * 0.4).round().clamp(2, 15)} min";
    final autoEta = "${(durationMins * 0.6).round().clamp(3, 15)} min";
    final cabEta = "${(durationMins * 0.7).round().clamp(4, 20)} min";
    final cabXlEta = "${(durationMins * 0.9).round().clamp(5, 25)} min";

    final List<Map<String, dynamic>> vehicles = [
      {
        "name": "Mr. Rideo Bike",
        "subtitle": "Fastest. Skip traffic.",
        "price": bikePrice,
        "eta": bikeEta,
        "icon": Icons.motorcycle,
      },
      {
        "name": "Mr. Rideo Auto",
        "subtitle": "Affordable 3-wheeler.",
        "price": autoPrice,
        "eta": autoEta,
        "icon": Icons.electric_rickshaw,
      },
      {
        "name": "Mr. Rideo Cab",
        "subtitle": "Spacious. AC rides.",
        "price": cabPrice,
        "eta": cabEta,
        "icon": Icons.directions_car,
      },
      {
        "name": "Cab XL (7-Seater)",
        "subtitle": "Extra space for group trips.",
        "price": cabXlPrice,
        "eta": cabXlEta,
        "icon": Icons.airport_shuttle,
      },
    ];
    final pLat = location.pickupLat ?? defaultLat;
    final pLng = location.pickupLng ?? defaultLng;

    final String activeVehicleType = _selectedVehicleIndex == 0
        ? 'bike'
        : _selectedVehicleIndex == 1
            ? 'auto'
            : _selectedVehicleIndex == 2
                ? 'cab'
                : 'cab_xl';

    final nearbyVehicles = [
      NearbyDriver(
        id: '${activeVehicleType}_1',
        name: 'Captain 1',
        lat: pLat + 0.0018,
        lng: pLng + 0.0014,
        vehicleType: activeVehicleType,
        heading: 45.0,
      ),
      NearbyDriver(
        id: '${activeVehicleType}_2',
        name: 'Captain 2',
        lat: pLat - 0.0014,
        lng: pLng + 0.0021,
        vehicleType: activeVehicleType,
        heading: 135.0,
      ),
      NearbyDriver(
        id: '${activeVehicleType}_3',
        name: 'Captain 3',
        lat: pLat + 0.0022,
        lng: pLng - 0.0016,
        vehicleType: activeVehicleType,
        heading: 220.0,
      ),
      NearbyDriver(
        id: '${activeVehicleType}_4',
        name: 'Captain 4',
        lat: pLat - 0.0019,
        lng: pLng - 0.0012,
        vehicleType: activeVehicleType,
        heading: 310.0,
      ),
      NearbyDriver(
        id: '${activeVehicleType}_5',
        name: 'Captain 5',
        lat: pLat + 0.0009,
        lng: pLng - 0.0024,
        vehicleType: activeVehicleType,
        heading: 90.0,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          // 1. Map with Route line and Back button
          Expanded(
            child: Stack(
              children: [
                OlaMapWidget(
                  pickupLat: pLat,
                  pickupLng: pLng,
                  destLat: location.destLat ?? defaultLat,
                  destLng: location.destLng ?? defaultLng,
                  nearbyDrivers: nearbyVehicles,
                  isDark: isDark,
                ),
                // Back Floating Navigation Button
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black38,
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              )
                            ],
                          ),
                          child: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Bottom Ride Drawer (Uber-style selection drawer)
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pick / Drop Summary Header
                  Row(
                    children: [
                      Column(
                        children: [
                          Icon(LucideIcons.circle, color: AppColors.success, size: 12),
                          Container(
                            width: 1,
                            height: 16,
                            color: AppColors.textMuted.withValues(alpha: 0.5),
                          ),
                          Icon(LucideIcons.mapPin, color: AppColors.success, size: 12),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              location.pickupAddress,
                              style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              location.destinationAddress.isEmpty
                                  ? "Selected Destination"
                                  : location.destinationAddress,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Ride Services Selection List
                  ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = vehicles[index];
                      final isSelected = _selectedVehicleIndex == index;
                      return _buildVehicleCard(vehicle, index, isSelected, isEstimating);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Payment & Promo Details Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(LucideIcons.creditCard, color: AppColors.primary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Mr. Rideo Wallet (₹345)",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                             Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 16),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(
                          "Add Promo",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Confirm booking action
                  PrimaryButton(
                    text: "Confirm ${vehicles[_selectedVehicleIndex]['name']}",
                    isLoading: isEstimating,
                    onPressed: () {
                      final vehicle = vehicles[_selectedVehicleIndex];
                      final vehicleName = vehicle['name'] as String;
                      final driverArrivalEta = vehicle['eta'] as String;
                      final tripDurationEta = "${durationMins.round().clamp(1, 120)} min";
                      final price = vehicle['price'] as double;
                      ref.read(bookingProvider.notifier).startSearch(
                        vehicleName: vehicleName,
                        driverArrivalEta: driverArrivalEta,
                        tripDurationEta: tripDurationEta,
                        price: price,
                      );
                      context.push('/searching-driver');
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle, int index, bool isSelected, bool isEstimating) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedVehicleIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.textPrimary.withValues(alpha: 0.2) : AppColors.surfaceCard,
                shape: BoxShape.circle,
              ),
              child: Icon(
                vehicle['icon'] as IconData,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle['name'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle['subtitle'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isEstimating ? "--" : "₹${(vehicle['price'] as double).toStringAsFixed(0)}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEstimating ? "Calculating..." : vehicle['eta'] as String,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: isEstimating ? AppColors.textSecondary : AppColors.success,
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

// Route Map Painter drawing a purple routing line
class RouteMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Standard dark background
    final bgPaint = Paint()..color = AppColors.mapBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = AppColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    // Background Road grids
    canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.4), roadPaint);
    canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.3, size.height), roadPaint);
    canvas.drawLine(Offset(size.width * 0.7, 0), Offset(size.width * 0.7, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.75), roadPaint);

    // Plotted Route Path in Brand Purple
    final routePaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.0;

    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.4) // Pickup
      ..lineTo(size.width * 0.5, size.height * 0.4)
      ..lineTo(size.width * 0.5, size.height * 0.75)
      ..lineTo(size.width * 0.7, size.height * 0.75); // Dropoff

    canvas.drawPath(path, routePaint);

    // Pickup circle (Green)
    final pickupPaint = Paint()..color = AppColors.success;
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.4), 8.0, pickupPaint);

    // Dropoff circle (Purple)
    final dropPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.75), 8.0, dropPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
