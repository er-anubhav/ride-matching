import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:rider_app/providers/ui_state_providers.dart';

// ─── Style URLs ────────────────────────────────────────────────────────────────
const String _apiKey = 'YOUR_OLA_MAPS_API_KEY';

String _styleUrl(bool isDark) =>
    'https://api.olamaps.io/tiles/vector/v1/styles/'
    '${isDark ? 'default-dark-standard' : 'default-light-standard'}'
    '/style.json?api_key=$_apiKey';

// ─── Widget ────────────────────────────────────────────────────────────────────
class OlaMapWidget extends StatefulWidget {
  final double? centerLat;
  final double? centerLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final double zoom;
  final bool isDark;
  final bool showUserLocation;
  final bool showLocationButton;
  final double? locationButtonBottom;
  final double? locationButtonTop;
  final List<NearbyDriver>? nearbyDrivers;

  const OlaMapWidget({
    super.key,
    this.centerLat,
    this.centerLng,
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
    this.driverLat,
    this.driverLng,
    this.nearbyDrivers,
    this.zoom = 15.0,
    this.isDark = false,
    this.showUserLocation = true,
    this.showLocationButton = true,
    this.locationButtonBottom,
    this.locationButtonTop,
  });

  @override
  State<OlaMapWidget> createState() => _OlaMapWidgetState();
}

class _OlaMapWidgetState extends State<OlaMapWidget> {
  MapLibreMapController? _controller;
  Symbol? _userSymbol;
  Symbol? _driverSymbol;
  Symbol? _pickupSymbol;
  Symbol? _destSymbol;
  final Map<String, Symbol> _nearbySymbols = {};
  Line? _routeLine;
  bool _styleLoaded = false;

  String? _resolvedStyleString;
  bool _loadingStyle = true;

  static final Map<bool, String> _styleCache = {};

  // ── Derived helpers ──────────────────────────────────────────────────────────
  LatLng get _initialCenter {
    final lat = widget.centerLat ?? widget.pickupLat ?? widget.driverLat;
    final lng = widget.centerLng ?? widget.pickupLng ?? widget.driverLng;
    return LatLng(lat ?? 0, lng ?? 0);
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void didUpdateWidget(OlaMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDark != oldWidget.isDark) {
      _loadStyle();
    } else if (_controller != null && _styleLoaded) {
      if ((widget.centerLat != oldWidget.centerLat || widget.centerLng != oldWidget.centerLng) &&
          widget.centerLat != null && widget.centerLng != null) {
        _controller!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(widget.centerLat!, widget.centerLng!),
          widget.zoom,
        ));
      }
      _syncMarkersAndRoute();
    }
  }

  Future<void> _loadStyle() async {
    final isDark = widget.isDark;

    // Fast path: if style is already cached in memory, use it instantly (0ms)
    if (_styleCache.containsKey(isDark)) {
      if (mounted) {
        setState(() {
          _resolvedStyleString = _styleCache[isDark]!;
          _loadingStyle = false;
          _styleLoaded = false;
        });
      }
      return;
    }

    // Only set _loadingStyle to true if we don't have a visible map yet
    final bool isFirstLoad = _resolvedStyleString == null;
    if (isFirstLoad && mounted) {
      setState(() {
        _loadingStyle = true;
        _styleLoaded = false;
      });
    }

    try {
      final styleName = isDark ? 'default-dark-standard' : 'default-light-standard';
      final url = Uri.parse('https://api.olamaps.io/tiles/vector/v1/styles/$styleName/style.json?api_key=$_apiKey');
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> styleJson = jsonDecode(response.body);

        String addApiKey(String uri) {
          if (uri.isEmpty || uri.contains('api_key=')) return uri;
          final sep = uri.contains('?') ? '&' : '?';
          return '$uri${sep}api_key=$_apiKey';
        }

        if (styleJson.containsKey('sprite') && styleJson['sprite'] is String) {
          styleJson['sprite'] = addApiKey(styleJson['sprite'] as String);
        }

        if (styleJson.containsKey('glyphs') && styleJson['glyphs'] is String) {
          styleJson['glyphs'] = addApiKey(styleJson['glyphs'] as String);
        }

        if (styleJson.containsKey('sources') && styleJson['sources'] is Map) {
          final sources = styleJson['sources'] as Map<String, dynamic>;
          for (final entry in sources.entries) {
            final src = entry.value;
            if (src is Map<String, dynamic>) {
              if (src.containsKey('url') && src['url'] is String) {
                final srcUrl = addApiKey(src['url'] as String);
                try {
                  final srcResp = await http.get(Uri.parse(srcUrl));
                  if (srcResp.statusCode == 200) {
                    final Map<String, dynamic> srcJson = jsonDecode(srcResp.body);
                    src.remove('url');
                    srcJson.forEach((k, v) {
                      if (k == 'type') {
                        src['type'] = 'vector';
                      } else if (k == 'tiles' && v is List) {
                        src['tiles'] = v.map((t) => addApiKey(t.toString())).toList();
                      } else {
                        src[k] = v;
                      }
                    });
                    src['type'] = 'vector';
                  } else {
                    src['url'] = srcUrl;
                  }
                } catch (_) {
                  src['url'] = srcUrl;
                }
              }
              if (src.containsKey('tiles') && src['tiles'] is List) {
                src['tiles'] = (src['tiles'] as List).map((t) => addApiKey(t.toString())).toList();
              }
              src['type'] = 'vector';
            }
          }
        }

        final encodedStyle = jsonEncode(styleJson);
        _styleCache[isDark] = encodedStyle;

        if (mounted) {
          setState(() {
            _resolvedStyleString = encodedStyle;
            _loadingStyle = false;
            _styleLoaded = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint('Error fetching OlaMaps style: $e');
    }

    final fallbackUrl = _styleUrl(isDark);
    _styleCache[isDark] = fallbackUrl;
    if (mounted) {
      setState(() {
        _resolvedStyleString = fallbackUrl;
        _loadingStyle = false;
        _styleLoaded = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ── Map callbacks ────────────────────────────────────────────────────────────
  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded() {
    setState(() => _styleLoaded = true);
    _syncMarkersAndRoute();
  }

  // ── Sync state → map ─────────────────────────────────────────────────────────
  Future<void> _syncMarkersAndRoute() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    await _ensureMarkerImages(ctrl);
    await _syncPickupMarker(ctrl);
    await _syncDestMarker(ctrl);
    await _syncUserMarker(ctrl);
    await _syncDriverMarker(ctrl);
    await _syncNearbyDrivers(ctrl);
    await _syncRoute(ctrl);
  }

  Future<void> _ensureMarkerImages(MapLibreMapController ctrl) async {
    try {
      final pickupBytes = await _createCustomMarkerBitmap(
        label: 'PICKUP',
        color: const Color(0xFF10B981), // Emerald Green
        isSquare: false,
      );
      await ctrl.addImage('custom_pickup_img', pickupBytes);

      final destBytes = await _createCustomMarkerBitmap(
        label: 'DROP-OFF',
        color: const Color(0xFFEF4444), // Crimson Red
        isSquare: true,
      );
      await ctrl.addImage('custom_dest_img', destBytes);
    } catch (e) {
      debugPrint('Error adding custom marker images: $e');
    }
  }

  Future<Uint8List> _createCustomMarkerBitmap({
    required String label,
    required Color color,
    bool isSquare = false,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(160, 68);

    // 1. Draw outer pill badge shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final bgPaint = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 4, size.width - 12, 42),
      const Radius.circular(12),
    );

    // Shadow & Background
    canvas.drawRRect(badgeRect.shift(const Offset(0, 3)), shadowPaint);
    canvas.drawRRect(badgeRect, bgPaint);
    canvas.drawRRect(badgeRect, borderPaint);

    // 2. Color Indicator Shape
    final indicatorPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const indicatorCenter = Offset(24, 25);
    if (isSquare) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: indicatorCenter, width: 18, height: 18),
          const Radius.circular(4),
        ),
        indicatorPaint,
      );
    } else {
      canvas.drawCircle(indicatorCenter, 10, indicatorPaint);
    }

    // Inner white dot
    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(indicatorCenter, 4, innerDotPaint);

    // 3. Text Label
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(42, 25 - textPainter.height / 2));

    // 4. Pointer Pin Arrow at Bottom Center
    final pointerPath = Path()
      ..moveTo(size.width / 2 - 8, 46)
      ..lineTo(size.width / 2 + 8, 46)
      ..lineTo(size.width / 2, 60)
      ..close();

    final pointerShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    canvas.drawPath(pointerPath.shift(const Offset(0, 1)), pointerShadow);
    canvas.drawPath(pointerPath, indicatorPaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _syncPickupMarker(MapLibreMapController ctrl) async {
    final lat = widget.pickupLat;
    final lng = widget.pickupLng;
    if (lat == null || lng == null) return;
    final pos = LatLng(lat, lng);

    if (_pickupSymbol == null) {
      _pickupSymbol = await ctrl.addSymbol(SymbolOptions(
        geometry: pos,
        iconImage: 'custom_pickup_img',
        iconSize: 0.7,
        iconAnchor: 'bottom',
      ));
    } else {
      await ctrl.updateSymbol(_pickupSymbol!, SymbolOptions(geometry: pos));
    }
  }

  Future<void> _syncDestMarker(MapLibreMapController ctrl) async {
    final lat = widget.destLat;
    final lng = widget.destLng;
    if (lat == null || lng == null) return;
    final pos = LatLng(lat, lng);

    if (_destSymbol == null) {
      _destSymbol = await ctrl.addSymbol(SymbolOptions(
        geometry: pos,
        iconImage: 'custom_dest_img',
        iconSize: 0.7,
        iconAnchor: 'bottom',
      ));
    } else {
      await ctrl.updateSymbol(_destSymbol!, SymbolOptions(geometry: pos));
    }
  }

  Future<void> _syncUserMarker(MapLibreMapController ctrl) async {
    // If pickupLat is set, pickup marker handles the location pin
    if (widget.pickupLat != null) {
      if (_userSymbol != null) {
        await ctrl.removeSymbol(_userSymbol!);
        _userSymbol = null;
      }
      return;
    }

    final lat = widget.centerLat;
    final lng = widget.centerLng;
    if (lat == null || lng == null) return;
    final pos = LatLng(lat, lng);

    if (_userSymbol == null) {
      _userSymbol = await ctrl.addSymbol(SymbolOptions(
        geometry: pos,
        iconImage: 'default_marker',
        iconColor: '#2B8CEE',
        iconSize: 1.0,
        iconAnchor: 'bottom',
      ));
    } else {
      await ctrl.updateSymbol(_userSymbol!, SymbolOptions(geometry: pos));
    }
    ctrl.animateCamera(CameraUpdate.newLatLng(pos));
  }

  Future<void> _syncDriverMarker(MapLibreMapController ctrl) async {
    final lat = widget.driverLat;
    final lng = widget.driverLng;
    if (lat == null || lng == null) return;
    final pos = LatLng(lat, lng);

    if (_driverSymbol == null) {
      _driverSymbol = await ctrl.addSymbol(SymbolOptions(
        geometry: pos,
        iconImage: 'default_marker',
        iconColor: '#6D0FA5',
        iconSize: 1.2,
        iconAnchor: 'bottom',
      ));
    } else {
      await ctrl.updateSymbol(_driverSymbol!, SymbolOptions(geometry: pos));
    }
  }

  Future<void> _syncNearbyDrivers(MapLibreMapController ctrl) async {
    final drivers = widget.nearbyDrivers;
    if (drivers == null) return;

    final currentIds = drivers.map((d) => d.id).toSet();

    // Remove stale markers
    final toRemove = _nearbySymbols.keys.where((k) => !currentIds.contains(k)).toList();
    for (final id in toRemove) {
      await ctrl.removeSymbol(_nearbySymbols[id]!);
      _nearbySymbols.remove(id);
    }

    // Add/update
    for (final d in drivers) {
      final pos = LatLng(d.lat, d.lng);
      final vType = d.vehicleType.toLowerCase();
      String color = '#F59E0B'; // default yellow for Bike
      if (vType.contains('bike') || vType == 'moto') {
        color = '#F59E0B'; // Yellow/Orange for Bike
      } else if (vType.contains('auto')) {
        color = '#10B981'; // Emerald Green for Auto
      } else if (vType.contains('xl')) {
        color = '#2563EB'; // Royal Blue for Cab XL
      } else {
        color = '#6D0FA5'; // Brand Purple for Sedan/Cab
      }

      if (_nearbySymbols.containsKey(d.id)) {
        await ctrl.updateSymbol(_nearbySymbols[d.id]!, SymbolOptions(
          geometry: pos,
          iconColor: color,
        ));
      } else {
        final sym = await ctrl.addSymbol(SymbolOptions(
          geometry: pos,
          iconImage: 'default_marker',
          iconColor: color,
          iconSize: 1.2,
          iconAnchor: 'bottom',
        ));
        _nearbySymbols[d.id] = sym;
      }
    }
  }

  Future<void> _syncRoute(MapLibreMapController ctrl) async {
    final pLat = widget.pickupLat;
    final pLng = widget.pickupLng;
    final dLat = widget.destLat;
    final dLng = widget.destLng;
    if (pLat == null || pLng == null || dLat == null || dLng == null) return;

    // Fetch route from OlaMaps Directions API
    try {
      final url = Uri.parse(
          'https://api.olamaps.io/routing/v1/directions'
          '?origin=$pLat,$pLng&destination=$dLat,$dLng&api_key=$_apiKey');
      final resp = await http.post(url, headers: {
        'X-Request-Id': 'urban-pulse-${Random().nextInt(1000000)}',
      });
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final polyline = data['routes']?[0]?['overview_polyline'];
        if (polyline != null) {
          final points = _decodePolyline(polyline);
          await _drawRoute(ctrl, points);
          return;
        }
      }
    } catch (_) {}

    // Fallback: straight line
    await _drawRoute(ctrl, [LatLng(pLat, pLng), LatLng(dLat, dLng)]);
  }

  Future<void> _drawRoute(MapLibreMapController ctrl, List<LatLng> coords) async {
    if (_routeLine != null) {
      await ctrl.removeLine(_routeLine!);
    }
    _routeLine = await ctrl.addLine(LineOptions(
      geometry: coords,
      lineColor: '#6D0FA5',
      lineWidth: 3.0,
      lineOpacity: 0.9,
    ));

    // Fit bounds
    if (coords.length >= 2) {
      double minLat = coords.map((c) => c.latitude).reduce(min);
      double maxLat = coords.map((c) => c.latitude).reduce(max);
      double minLng = coords.map((c) => c.longitude).reduce(min);
      double maxLng = coords.map((c) => c.longitude).reduce(max);
      await ctrl.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        left: 50, top: 70, right: 50, bottom: 100,
      ));
    }
  }

  // ── Polyline decoder ─────────────────────────────────────────────────────────
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  void _recenterToUserLocation() {
    final ctrl = _controller;
    if (ctrl == null) return;

    final lat = widget.centerLat ?? widget.pickupLat;
    final lng = widget.centerLng ?? widget.pickupLng;

    if (lat != null && lng != null) {
      ctrl.animateCamera(CameraUpdate.newLatLngZoom(LatLng(lat, lng), 15.5));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeLat = widget.centerLat ?? widget.pickupLat ?? widget.driverLat;
    final activeLng = widget.centerLng ?? widget.pickupLng ?? widget.driverLng;

    if (_loadingStyle || _resolvedStyleString == null || activeLat == null || activeLng == null || activeLat == 0 || activeLng == 0) {
      return Container(
        color: widget.isDark ? const Color(0xFF18181B) : const Color(0xFFF3F4F6),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF2B8CEE)),
        ),
      );
    }

    return Stack(
      children: [
        MapLibreMap(
          styleString: _resolvedStyleString!,
          initialCameraPosition: CameraPosition(
            target: _initialCenter,
            zoom: widget.zoom,
          ),
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          myLocationEnabled: widget.showUserLocation,
          myLocationRenderMode: MyLocationRenderMode.normal,
          myLocationTrackingMode: MyLocationTrackingMode.none,
          trackCameraPosition: false,
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          logoViewMargins: const Point(-200, -200), // hide logo
          attributionButtonMargins: const Point(-200, -200), // hide attribution
        ),
        if (widget.showLocationButton)
          Positioned(
            right: 16,
            top: widget.locationButtonTop,
            bottom: widget.locationButtonTop == null ? (widget.locationButtonBottom ?? 240.0) : null,
            child: Material(
              color: Colors.transparent,
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _recenterToUserLocation,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF27272A) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Icon(
                    LucideIcons.locateFixed,
                    color: widget.isDark ? const Color(0xFF2B8CEE) : const Color(0xFF1D4ED8),
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

