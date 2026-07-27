import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';
import '../widgets/ola_map_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final wallet = ref.watch(walletProvider);
    final history = ref.watch(searchHistoryProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Sleek Dark Vector Map Background
          const Positioned.fill(
            child: PremiumDarkMapWidget(),
          ),

          // 2. Floating Top Header Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Menu Button
                    Builder(
                      builder: (context) {
                        return GestureDetector(
                          onTap: () {
                            Scaffold.of(context).openDrawer();
                          },
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
                            child: Icon(LucideIcons.menu, color: AppColors.textPrimary, size: 22),
                          ),
                        );
                      }
                    ),

                    // Wallet Badge & Avatar
                    Row(
                      children: [
                        // Wallet Badge
                        GestureDetector(
                          onTap: () => context.push('/wallet'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.wallet, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "₹${wallet.balance.toStringAsFixed(0)}",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Profile Avatar
                        GestureDetector(
                          onTap: () => context.push('/profile'),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 1.5),
                              image: DecorationImage(
                                image: NetworkImage(profile.avatarUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom Glassmorphic Card (Uber-style)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
              ),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  Text(
                    "Hello, ${profile.name.split(' ')[0]} 👋",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Where are you going?",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      letterSpacing: -0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search Bar Pill
                  GestureDetector(
                    onTap: () {
                      context.push('/destination-picker');
                    },
                    child: Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.search, color: AppColors.textPrimary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            "Enter Destination...",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.clock, size: 12, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  "Now",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pinned Bookmarks
                  if (bookmarks.isNotEmpty) ...[
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: bookmarks.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final bookmark = bookmarks[index];
                          return GestureDetector(
                            onTap: () {
                              ref.read(locationProvider.notifier).setDestination(
                                    bookmark.address,
                                    bookmark.latitude,
                                    bookmark.longitude,
                                  );
                              ref.read(searchHistoryProvider.notifier).addHistory(
                                    bookmark.address,
                                    bookmark.latitude,
                                    bookmark.longitude,
                                  );
                              context.push('/ride-summary');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.bookmark, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    bookmark.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Recent Searches (History)
                  if (history.isNotEmpty) ...[
                    ...history.take(2).map((item) {
                      return Column(
                        children: [
                          _buildShortcutItem(
                            icon: LucideIcons.clock,
                            title: item.address.split(',')[0],
                            subtitle: item.address.contains(',')
                                ? item.address.substring(item.address.indexOf(',') + 1).trim()
                                : item.address,
                            onTap: () {
                              ref.read(locationProvider.notifier).setDestination(
                                    item.address,
                                    item.latitude,
                                    item.longitude,
                                  );
                              ref.read(searchHistoryProvider.notifier).addHistory(
                                    item.address,
                                    item.latitude,
                                    item.longitude,
                                  );
                              context.push('/ride-summary');
                            },
                            onRemove: () {
                              ref.read(searchHistoryProvider.notifier).removeHistory(item.address);
                            },
                          ),
                          Divider(color: AppColors.border, height: 1),
                        ],
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      // Left Drawer navigation
      drawer: Drawer(
        backgroundColor: AppColors.surface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              currentAccountPicture: CircleAvatar(
                backgroundImage: NetworkImage(profile.avatarUrl),
              ),
              accountName: Text(
                profile.name,
                style: GoogleFonts.plusJakartaSans(),
              ),
              accountEmail: Text(
                profile.phone,
                style: GoogleFonts.plusJakartaSans(),
              ),
            ),
            ListTile(
              leading: Icon(LucideIcons.wallet, color: AppColors.textPrimary),
              title: const Text("Wallet"),
              onTap: () {
                context.pop();
                context.push('/wallet');
              },
            ),
             ListTile(
              leading: Icon(LucideIcons.history, color: AppColors.textPrimary),
              title: const Text("Your Trips"),
              onTap: () {
                context.pop();
                context.push('/history');
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.settings, color: AppColors.textPrimary),
              title: const Text("Settings"),
              onTap: () {
                context.pop();
                context.push('/profile');
              },
            ),
            const Spacer(),
             Divider(color: AppColors.border),
            ListTile(
              leading: Icon(LucideIcons.logOut, color: AppColors.error),
              title: const Text("Logout"),
              onTap: () {
                context.pop();
                context.go('/auth/phone');
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onRemove,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 18),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                icon: Icon(LucideIcons.trash2, color: AppColors.textSecondary, size: 18),
                onPressed: onRemove,
              )
            else
              Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

// Custom Premium Dark Map Painter Widget
class PremiumDarkMapWidget extends ConsumerWidget {
  const PremiumDarkMapWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocAsync = ref.watch(currentLocationProvider);
    final userPosition = currentLocAsync.when(
      data: (pos) => pos,
      error: (_, __) => null,
      loading: () => null,
    );

    final nearbyDrivers = ref.watch(nearbyDriversProvider);

    return OlaMapWidget(
      centerLat: userPosition?.latitude,
      centerLng: userPosition?.longitude,
      zoom: 14.0,
      nearbyDrivers: nearbyDrivers,
    );
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.mapBg;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final roadPaint = Paint()
      ..color = AppColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;

    final roadPaintThin = Paint()
      ..color = AppColors.mapRoad
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Draw some stylized road grid networks
    canvas.drawLine(Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3), roadPaint);
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), roadPaint);
    canvas.drawLine(Offset(0, size.height * 0.65), Offset(size.width, size.height * 0.6), roadPaint);
    canvas.drawLine(Offset(size.width * 0.8, 0), Offset(size.width * 0.8, size.height), roadPaint);

    // Diagonal thin lines representing alleys
    canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), roadPaintThin);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width * 0.5, size.height * 0.3), roadPaintThin);

    // Draw a pickup marker in purple
    final pinPaint = Paint()..color = AppColors.primary;
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.3), 12.0, pinPaint);
    canvas.drawCircle(Offset(size.width * 0.35, size.height * 0.3), 4.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
