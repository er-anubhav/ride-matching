import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';
import '../providers/ui_state_providers.dart';

class TripHistoryScreen extends ConsumerStatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  ConsumerState<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends ConsumerState<TripHistoryScreen> {
  String _selectedFilter = "All";

  @override
  Widget build(BuildContext context) {
    final allTrips = ref.watch(tripHistoryProvider);
    
    // Filter trips
    final filteredTrips = allTrips.where((trip) {
      if (_selectedFilter == "All") return true;
      return (trip['status'] as String).toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          "Your Trips",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ["All", "Completed", "Cancelled"].map((tab) {
                  final isSelected = _selectedFilter == tab;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedFilter = tab;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            tab,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          Expanded(
            child: filteredTrips.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filteredTrips.length,
                    itemBuilder: (context, index) {
                      final trip = filteredTrips[index];
                      return _buildTripCard(trip);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.history,
              size: 48,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "No Trips Found",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "You haven't booked any rides yet.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final isCompleted = trip['status'] == "Completed";

    return GestureDetector(
      onTap: () => _showTripDetailsBottomSheet(trip),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Type Icon Circle
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isCompleted
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                trip['vehicleIcon'] as IconData,
                color: isCompleted ? AppColors.primary : AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Trip details summary
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip['date'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${trip['vehicle']} • ${trip['distance']}",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Pickup & Drop row indicator
                  Row(
                    children: [
                       Icon(LucideIcons.circle, color: AppColors.success, size: 8),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip['pickup'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                       Icon(LucideIcons.mapPin, color: AppColors.primary, size: 8),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip['destination'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
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
            const SizedBox(width: 10),
            // Status and price column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isCompleted ? "₹${(trip['price'] as double).toStringAsFixed(2)}" : "Cancelled",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: isCompleted ? AppColors.textPrimary : AppColors.error,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    trip['status'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: isCompleted ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTripDetailsBottomSheet(Map<String, dynamic> trip) {
    final isCompleted = trip['status'] == "Completed";

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pull Bar indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Trip Details",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    trip['id'] as String,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Addresses box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                         Icon(LucideIcons.circle, color: AppColors.success, size: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            trip['pickup'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.only(left: 5),
                      alignment: Alignment.centerLeft,
                      height: 16,
                      child: Container(
                        width: 1,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(LucideIcons.mapPin, color: AppColors.primary, size: 12),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            trip['destination'] as String,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Driver Details
              if (isCompleted) ...[
                Text(
                  "Driver Info",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(LucideIcons.user, color: AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip['driver'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              "${trip['driverRating']}",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          trip['duration'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          trip['distance'] as String,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 16),
                // Show user's submitted rating if available
                if (trip['userRating'] != null) ...[
                  Row(
                    children: [
                      Text(
                        "Your Rating",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Spacer(),
                      ...List.generate(5, (i) => Icon(
                        i < (trip['userRating'] as int) ? Icons.star : Icons.star_border,
                        color: i < (trip['userRating'] as int) ? Colors.amber : AppColors.textMuted,
                        size: 18,
                      )),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: AppColors.border, height: 1),
                  const SizedBox(height: 16),
                ],
              ],
              // Receipt Breakdown
              Text(
                "Receipt Breakdown",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              _buildReceiptRow("Base Fare & Distance", isCompleted ? "₹${(trip['price'] + trip['promoDiscount']).toStringAsFixed(2)}" : "₹0.00"),
              if (trip['promo'] != null) ...[
                const SizedBox(height: 8),
                _buildReceiptRow("Promo Applied (${trip['promo']})", "-₹${(trip['promoDiscount'] as double).toStringAsFixed(2)}", isPromo: true),
              ],
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
                    isCompleted ? "₹${(trip['price'] as double).toStringAsFixed(2)}" : "₹0.00",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Close button
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: "Close Details",
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
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
