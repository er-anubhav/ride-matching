import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/theme_provider.dart';
import '../providers/ui_state_providers.dart';
import '../widgets/ola_map_widget.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeProvider); // rebuild when theme changes so AppColors re-evaluates
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
                                Icon(LucideIcons.wallet, color: AppColors.textPrimary, size: 16),
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
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.primary, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black38,
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
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
                  const SizedBox(height: 12),

                  // Saved Places (Bookmarks + Common Tag Buttons)
                  SizedBox(
                    height: 38,
                    child: Builder(
                      builder: (context) {
                        const commonTags = [
                          {'label': 'Home', 'icon': LucideIcons.home},
                          {'label': 'Work', 'icon': LucideIcons.briefcase},
                        ];

                        final items = <Widget>[];

                        for (final tag in commonTags) {
                          final tagLabel = tag['label'] as String;
                          final tagIcon = tag['icon'] as IconData;

                          final existingIndex = bookmarks.indexWhere(
                            (b) => b.label.toLowerCase() == tagLabel.toLowerCase(),
                          );

                          if (existingIndex != -1) {
                            final bookmark = bookmarks[existingIndex];
                            items.add(
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
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
                                        Icon(tagIcon, size: 13, color: AppColors.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          bookmark.label,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          } else {
                            items.add(
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: GestureDetector(
                                  onTap: () => context.push('/destination-picker?saveTag=$tagLabel'),
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
                                        const Icon(LucideIcons.plus, size: 13, color: AppColors.primary),
                                        const SizedBox(width: 5),
                                        Icon(tagIcon, size: 13, color: AppColors.textSecondary),
                                        const SizedBox(width: 5),
                                        Text(
                                          tagLabel,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            color: AppColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }
                        }

                        final customBookmarks = bookmarks.where(
                          (b) => !commonTags.any((t) => (t['label'] as String).toLowerCase() == b.label.toLowerCase()),
                        ).toList();

                        if (customBookmarks.isNotEmpty) {
                          final customBookmark = customBookmarks.first;
                          items.add(
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  ref.read(locationProvider.notifier).setDestination(
                                        customBookmark.address,
                                        customBookmark.latitude,
                                        customBookmark.longitude,
                                      );
                                  ref.read(searchHistoryProvider.notifier).addHistory(
                                        customBookmark.address,
                                        customBookmark.latitude,
                                        customBookmark.longitude,
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
                                        customBookmark.label,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12,
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w300,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        } else {
                          items.add(
                            GestureDetector(
                              onTap: () => context.push('/destination-picker?saveTag=Other'),
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
                                    const Icon(LucideIcons.plus, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Add",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView(
                          scrollDirection: Axis.horizontal,
                          children: items,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Last Visited Place
                  if (history.isNotEmpty) ...[
                    ...history.take(1).map((item) {
                      return Column(
                        children: [
                          _buildShortcutItem(
                            icon: LucideIcons.clock,
                            title: item.address.split(',')[0],
                            subtitle: item.address.contains(',')
                                ? item.address.substring(item.address.indexOf(',') + 1).trim()
                                : item.address,
                            badgeLabel: "Recent",
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
                    const SizedBox(height: 12),
                  ],

                  // ── Refer & Earn Banner ───────────────────────────────
                  const _ReferEarnBanner(),
                  // ─────────────────────────────────────────────────────
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
            Divider(color: AppColors.border, height: 1),
            ListTile(
              leading: Icon(LucideIcons.logOut, color: AppColors.error),
              title: Text(
                "Logout",
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.error,
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () {
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


  Widget _buildShortcutItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    String? badgeLabel,
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w300,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badgeLabel != null) ...[
                        const SizedBox(width: 8),
                        Builder(
                          builder: (context) {
                            final isDark = Theme.of(context).brightness == Brightness.dark;
                            final badgeColor = isDark ? Colors.white : AppColors.primary;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: badgeColor.withValues(alpha: isDark ? 0.6 : 0.5),
                                ),
                              ),
                              child: Text(
                                badgeLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: badgeColor,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
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
class PremiumDarkMapWidget extends ConsumerStatefulWidget {
  const PremiumDarkMapWidget({super.key});

  @override
  ConsumerState<PremiumDarkMapWidget> createState() => _PremiumDarkMapWidgetState();
}

class _PremiumDarkMapWidgetState extends ConsumerState<PremiumDarkMapWidget> {
  LocationPermission _permission = LocationPermission.denied;
  bool _locationServiceEnabled = true;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequest();
  }

  Future<void> _checkAndRequest() async {
    setState(() => _checking = true);
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _locationServiceEnabled = false;
        _checking = false;
      });
      return;
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (mounted) {
      setState(() {
        _permission = perm;
        _locationServiceEnabled = true;
        _checking = false;
      });

      // Kick the provider to re-fetch location now that permission may be granted
      if (perm == LocationPermission.always || perm == LocationPermission.whileInUse) {
        ref.read(currentLocationProvider.notifier).refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Container(
        color: AppColors.surface,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_locationServiceEnabled) {
      return _PermissionOverlay(
        icon: LucideIcons.mapPin,
        title: 'Location Services Off',
        message: 'Please enable Location Services in your device settings to see the map.',
        buttonLabel: 'Open Settings',
        onTap: () async {
          await Geolocator.openLocationSettings();
          _checkAndRequest();
        },
      );
    }

    if (_permission == LocationPermission.deniedForever) {
      return _PermissionOverlay(
        icon: LucideIcons.shieldOff,
        title: 'Location Permission Required',
        message: 'Location access was permanently denied. Please enable it in App Settings to use the map.',
        buttonLabel: 'Open App Settings',
        onTap: () async {
          await Geolocator.openAppSettings();
          _checkAndRequest();
        },
      );
    }

    if (_permission == LocationPermission.denied) {
      return _PermissionOverlay(
        icon: LucideIcons.navigation,
        title: 'Allow Location Access',
        message: 'Ride Matching needs your location to show the map and find nearby drivers.',
        buttonLabel: 'Grant Permission',
        onTap: _checkAndRequest,
      );
    }

    // Permission granted — show the real map
    final currentLocAsync = ref.watch(currentLocationProvider);
    final userPosition = currentLocAsync.when(
      data: (pos) => pos,
      error: (_, __) => null,
      loading: () => null,
    );
    final nearbyDrivers = ref.watch(nearbyDriversProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && AppColors.isDark);

    return OlaMapWidget(
      centerLat: userPosition?.latitude,
      centerLng: userPosition?.longitude,
      zoom: 14.0,
      nearbyDrivers: nearbyDrivers,
      isDark: isDark,
      locationButtonTop: 128.0,
    );
  }
}

class _PermissionOverlay extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  const _PermissionOverlay({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onTap,
                  icon: Icon(LucideIcons.mapPin, size: 18),
                  label: Text(buttonLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferEarnBanner extends ConsumerWidget {
  const _ReferEarnBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && AppColors.isDark);

    final gradientColors = isDark
        ? const [Color(0xFF1E1035), Color(0xFF2D164D), Color(0xFF3C1C60)]
        : const [Color(0xFF6D0FA5), Color(0xFF9B31E8), Color(0xFFBB6BD9)];

    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.5)
        : const Color(0xFF6D0FA5).withValues(alpha: 0.35);

    final borderColor = isDark
        ? const Color(0xFF9B31E8).withValues(alpha: 0.35)
        : Colors.transparent;

    final iconBgColor = isDark
        ? const Color(0xFF9B31E8).withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.18);

    final iconColor = isDark
        ? const Color(0xFFE9D5FF)
        : Colors.white;

    final subtitleColor = isDark
        ? const Color(0xFFD8B4FE)
        : Colors.white.withValues(alpha: 0.82);

    return GestureDetector(
      onTap: () {
        // TODO: Navigate to referral screen or show share sheet
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background decorative circles
            Positioned(
              right: -18,
              top: -18,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF9B31E8).withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              right: 30,
              bottom: -24,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? const Color(0xFF9B31E8).withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  // Gift icon container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      LucideIcons.gift,
                      color: iconColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Refer & Earn',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Invite friends & get rewards on rides',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            color: subtitleColor,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF9B31E8).withValues(alpha: 0.3)
                                : Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFFC084FC).withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'Coming Soon',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
