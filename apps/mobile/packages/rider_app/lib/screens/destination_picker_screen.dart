import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared/shared.dart';

import '../providers/ui_state_providers.dart';

class OlaPrediction {
  final String description;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  OlaPrediction({
    required this.description,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  factory OlaPrediction.fromJson(Map<String, dynamic> json) {
    final structured = json['structured_formatting'] ?? {};
    final geometry = json['geometry'] ?? {};
    final location = geometry['location'] ?? {};
    return OlaPrediction(
      description: json['description'] ?? '',
      title: structured['main_text'] ?? '',
      subtitle: structured['secondary_text'] ?? '',
      latitude: (location['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (location['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DestinationPickerScreen extends ConsumerStatefulWidget {
  final String? saveTag;
  const DestinationPickerScreen({super.key, this.saveTag});

  @override
  ConsumerState<DestinationPickerScreen> createState() => _DestinationPickerScreenState();
}

class _DestinationPickerScreenState extends ConsumerState<DestinationPickerScreen> {
  final TextEditingController _pickupController = TextEditingController(text: "My Current Location");
  final TextEditingController _destController = TextEditingController();

  List<OlaPrediction> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  void _handleLocationSelected(String address, double lat, double lng) {
    FocusScope.of(context).unfocus();
    final tag = widget.saveTag;

    if (tag != null && tag.isNotEmpty) {
      if (tag == 'Other') {
        _showAddBookmarkDialog(context, address, lat, lng);
      } else {
        ref.read(bookmarksProvider.notifier).addBookmark(tag, address, lat, lng);
        context.pop();
      }
    } else {
      ref.read(locationProvider.notifier).setDestination(address, lat, lng);
      ref.read(searchHistoryProvider.notifier).addHistory(address, lat, lng);
      context.push('/ride-summary');
    }
  }


  @override
  void initState() {
    super.initState();
    _destController.addListener(() {
      _onSearchChanged(_destController.text);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pickupController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchSuggestions(text.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 4) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      const apiKey = '6ZPQI6AaSeXkgvIhqIQaxyEfscr8oXvgRTEpwPYj';
      
      // Target area: Bias results around current location (or Lucknow center) with a 50km radius (covers Lucknow & Kanpur region)
      const double defaultLat = 26.8500;
      const double defaultLng = 80.9400;
      final currentLoc = ref.read(currentLocationProvider);
      final lat = currentLoc.value?.latitude ?? defaultLat;
      final lng = currentLoc.value?.longitude ?? defaultLng;

      final url = 'https://api.olamaps.io/places/v1/autocomplete'
          '?input=${Uri.encodeComponent(query)}'
          '&location=$lat,$lng'
          '&radius=50000'
          '&api_key=$apiKey';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final predictions = decoded['predictions'] as List?;
        if (predictions != null) {
          final fetched = predictions
              .map((p) => OlaPrediction.fromJson(p as Map<String, dynamic>))
              // Client-side strict filter: restrict to specific cities/region (Lucknow, Kanpur, Uttar Pradesh)
              .where((p) => p.description.toLowerCase().contains("lucknow") ||
                            p.description.toLowerCase().contains("kanpur") ||
                            p.description.toLowerCase().contains("uttar pradesh"))
              .toList();
          setState(() {
            _suggestions = fetched;
            _isLoading = false;
          });
          return;
        }
      }
      _useFallback(query);
    } catch (e) {
      debugPrint("Error fetching autocomplete: $e");
      _useFallback(query);
    }
  }

  void _useFallback(String query) {
    setState(() {
      _suggestions = [];
      _isLoading = false;
    });
  }

  void _showAddBookmarkDialog(BuildContext context, String address, double lat, double lng) {
    final controller = TextEditingController(text: address.split(',')[0]);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "Pin Location",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: GoogleFonts.plusJakartaSans(color: AppColors.textPrimary),
          decoration: InputDecoration(
            labelText: "Label (e.g., Home, Work, Gym)",
            labelStyle: GoogleFonts.plusJakartaSans(color: AppColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              ref.read(bookmarksProvider.notifier).addBookmark(controller.text, address, lat, lng);
              Navigator.pop(context);
            },
            child: Text(
              "Save",
              style: GoogleFonts.plusJakartaSans(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(searchHistoryProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Plan Your Route",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Dual Input Card (Pickup / Destination)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppColors.surface,
              child: Row(
                children: [
                  // Left side dot/line visual indicator
                  Column(
                    children: [
                      Icon(LucideIcons.circle, color: AppColors.success, size: 14),
                      Container(
                        width: 2,
                        height: 28,
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                      ),
                      Icon(LucideIcons.mapPin, color: AppColors.success, size: 16),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Inputs
                  Expanded(
                    child: Column(
                      children: [
                        // Pickup Input
                        SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _pickupController,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              hintText: "Enter Pickup Location",
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.textPrimary, width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.textPrimary, width: 1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: TextField(
                            controller: _destController,
                            autofocus: true,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                            onChanged: _onSearchChanged,
                            onSubmitted: (value) {
                              if (value.trim().length >= 4) {
                                final address = value.trim();
                                double lat = 26.8500;
                                double lng = 80.9400;
                                if (_suggestions.isNotEmpty) {
                                  lat = _suggestions.first.latitude;
                                  lng = _suggestions.first.longitude;
                                }
                                _handleLocationSelected(address, lat, lng);
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              hintText: widget.saveTag != null && widget.saveTag!.isNotEmpty
                                  ? "Search address for ${widget.saveTag}..."
                                  : "Where to?",
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Suggestions List
            Expanded(
              child: _destController.text.trim().length < 4
                  ? _buildEmptyState(history, bookmarks)
                  : _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _suggestions.isEmpty
                          ? ListView(
                              children: [
                                ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceCard,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(LucideIcons.mapPin, color: AppColors.primary, size: 14),
                                  ),
                                  title: Text(
                                    _destController.text.trim(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "Use custom location",
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  trailing: Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 16),
                                  onTap: () {
                                    final text = _destController.text.trim();
                                    FocusScope.of(context).unfocus();
                                    ref.read(locationProvider.notifier).setDestination(text, 26.8500, 80.9400);
                                    ref.read(searchHistoryProvider.notifier).addHistory(text, 26.8500, 80.9400);
                                    context.push('/ride-summary');
                                  },
                                ),
                              ],
                            )
                          : ListView.builder(
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final suggestion = _suggestions[index];
                                return _buildSuggestionTile(suggestion);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(List<SearchHistoryItem> history, List<BookmarkItem> bookmarks) {
    final recentHistory = history.take(2).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (bookmarks.isNotEmpty) ...[
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: bookmarks.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final bookmark = bookmarks[index];
                  final labelLower = bookmark.label.toLowerCase();
                  IconData iconData = LucideIcons.bookmark;
                  if (labelLower == 'home') iconData = LucideIcons.home;
                  if (labelLower == 'work') iconData = LucideIcons.briefcase;
                  if (labelLower == 'gym') iconData = LucideIcons.dumbbell;

                  return Container(
                    padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () {
                            FocusScope.of(context).unfocus();
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(iconData, size: 13, color: AppColors.primary),
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
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () {
                            ref.read(bookmarksProvider.notifier).removeBookmark(bookmark.id ?? bookmark.address);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Removed ${bookmark.label} from saved places"),
                                backgroundColor: AppColors.textSecondary,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Icon(LucideIcons.x, size: 14, color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          Expanded(
            child: recentHistory.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    itemCount: recentHistory.length,
                     separatorBuilder: (context, index) => Divider(color: AppColors.border, height: 1),
                    itemBuilder: (context, index) {
                      final item = recentHistory[index];
                      return ListTile(
                        onTap: () {
                          _handleLocationSelected(item.address, item.latitude, item.longitude);
                        },
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceCard,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(LucideIcons.history, color: AppColors.textSecondary, size: 14),
                        ),
                        title: Text(
                          item.address.split(',')[0],
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          item.address.contains(',')
                              ? item.address.substring(item.address.indexOf(',') + 1).trim()
                              : item.address,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(LucideIcons.bookmark, color: AppColors.textMuted, size: 16),
                              onPressed: () => _showAddBookmarkDialog(
                                context,
                                item.address,
                                item.latitude,
                                item.longitude,
                              ),
                              tooltip: "Bookmark place",
                            ),
                            IconButton(
                              icon: Icon(LucideIcons.trash2, color: AppColors.textSecondary, size: 16),
                              onPressed: () {
                                ref.read(searchHistoryProvider.notifier).removeHistory(item.address);
                              },
                              tooltip: "Remove from history",
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          // Choose on Map Button
          SecondaryButton(
            text: "Choose on Map",
            icon: const Icon(LucideIcons.map, size: 18, color: AppColors.primary),
            onPressed: () {
              _handleLocationSelected("Selected Custom Location", 26.8500, 80.9400);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(OlaPrediction prediction) {
    return ListTile(
      onTap: () {
        _handleLocationSelected(
          prediction.description,
          prediction.latitude,
          prediction.longitude,
        );
      },
      dense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          shape: BoxShape.circle,
        ),
        child: Icon(LucideIcons.mapPin, color: AppColors.textSecondary, size: 14),
      ),
      title: Text(
        prediction.title.isNotEmpty ? prediction.title : prediction.description,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        prediction.subtitle,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Icon(LucideIcons.chevronRight, color: AppColors.textMuted, size: 16),
    );
  }
}
