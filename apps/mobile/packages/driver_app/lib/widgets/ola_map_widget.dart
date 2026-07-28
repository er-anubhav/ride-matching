import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const String _apiKey = 'YOUR_OLA_MAPS_API_KEY';

String _styleUrl(bool isDark) =>
    'https://api.olamaps.io/tiles/vector/v1/styles/'
    '${isDark ? 'default-dark-standard' : 'default-light-standard'}'
    '/style.json?api_key=$_apiKey';

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
  final List<List<double>>? routePoints;

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
    this.zoom = 16.0,
    this.isDark = false,
    this.showUserLocation = true,
    this.showLocationButton = true,
    this.routePoints,
  });

  @override
  State<OlaMapWidget> createState() => _OlaMapWidgetState();
}

class _OlaMapWidgetState extends State<OlaMapWidget> {
  MapLibreMapController? _controller;
  Symbol? _driverSymbol;
  Symbol? _pickupSymbol;
  Symbol? _destSymbol;
  Line? _routeLine;
  bool _styleLoaded = false;
  String? _resolvedStyleString;
  bool _loadingStyle = true;

  static final Map<bool, String> _styleCache = {};

  LatLng get _initialCenter {
    final lat = widget.driverLat ?? widget.centerLat ?? widget.pickupLat;
    final lng = widget.driverLng ?? widget.centerLng ?? widget.pickupLng;
    return LatLng(lat ?? 0, lng ?? 0);
  }

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
      final curLat = widget.driverLat ?? widget.centerLat;
      final curLng = widget.driverLng ?? widget.centerLng;
      final oldLat = oldWidget.driverLat ?? oldWidget.centerLat;
      final oldLng = oldWidget.driverLng ?? oldWidget.centerLng;
      if ((curLat != oldLat || curLng != oldLng) && curLat != null && curLng != null) {
        _controller!.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(curLat, curLng),
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

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
  }

  void _onStyleLoaded() {
    setState(() => _styleLoaded = true);
    _syncMarkersAndRoute();
  }

  Future<void> _syncMarkersAndRoute() async {
    final ctrl = _controller;
    if (ctrl == null) return;

    await _ensureMarkerImages(ctrl);
    await _syncDriverMarker(ctrl);
    await _syncPickupMarker(ctrl);
    await _syncDestMarker(ctrl);
    await _syncRoute(ctrl);
  }

  Future<void> _ensureMarkerImages(MapLibreMapController ctrl) async {
    try {
      final pickupBytes = await _createCustomMarkerBitmap(
        label: 'PICKUP',
        color: const Color(0xFF10B981),
      );
      await ctrl.addImage('driver_pickup_img', pickupBytes);

      final destBytes = await _createCustomMarkerBitmap(
        label: 'DROP-OFF',
        color: const Color(0xFFEF4444),
      );
      await ctrl.addImage('driver_dest_img', destBytes);
    } catch (e) {
      debugPrint('Error creating driver marker bitmaps: $e');
    }
  }

  Future<Uint8List> _createCustomMarkerBitmap({
    required String label,
    required Color color,
  }) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    const size = Size(160, 68);

    final bgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final RRect rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 160, 48),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, bgPaint);

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(24, 24), 8, dotPaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(42, (48 - textPainter.height) / 2));

    final path = Path()
      ..moveTo(70, 48)
      ..lineTo(90, 48)
      ..lineTo(80, 64)
      ..close();
    canvas.drawPath(path, bgPaint);

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.width.toInt(), size.height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _syncDriverMarker(MapLibreMapController ctrl) async {
    final lat = widget.driverLat;
    final lng = widget.driverLng;
    if (lat == null || lng == null) {
      if (_driverSymbol != null) {
        await ctrl.removeSymbol(_driverSymbol!);
        _driverSymbol = null;
      }
      return;
    }

    final pos = LatLng(lat, lng);
    if (_driverSymbol == null) {
      _driverSymbol = await ctrl.addSymbol(
        SymbolOptions(
          geometry: pos,
          iconImage: 'car-15',
          iconSize: 2.0,
        ),
      );
    } else {
      await ctrl.updateSymbol(_driverSymbol!, SymbolOptions(geometry: pos));
    }
  }

  Future<void> _syncPickupMarker(MapLibreMapController ctrl) async {
    final lat = widget.pickupLat;
    final lng = widget.pickupLng;
    if (lat == null || lng == null) {
      if (_pickupSymbol != null) {
        await ctrl.removeSymbol(_pickupSymbol!);
        _pickupSymbol = null;
      }
      return;
    }

    final pos = LatLng(lat, lng);
    if (_pickupSymbol == null) {
      _pickupSymbol = await ctrl.addSymbol(
        SymbolOptions(
          geometry: pos,
          iconImage: 'driver_pickup_img',
          iconSize: 0.7,
          iconAnchor: 'bottom',
        ),
      );
    } else {
      await ctrl.updateSymbol(_pickupSymbol!, SymbolOptions(geometry: pos));
    }
  }

  Future<void> _syncDestMarker(MapLibreMapController ctrl) async {
    final lat = widget.destLat;
    final lng = widget.destLng;
    if (lat == null || lng == null) {
      if (_destSymbol != null) {
        await ctrl.removeSymbol(_destSymbol!);
        _destSymbol = null;
      }
      return;
    }

    final pos = LatLng(lat, lng);
    if (_destSymbol == null) {
      _destSymbol = await ctrl.addSymbol(
        SymbolOptions(
          geometry: pos,
          iconImage: 'driver_dest_img',
          iconSize: 0.7,
          iconAnchor: 'bottom',
        ),
      );
    } else {
      await ctrl.updateSymbol(_destSymbol!, SymbolOptions(geometry: pos));
    }
  }

  Future<void> _syncRoute(MapLibreMapController ctrl) async {
    final points = widget.routePoints;
    if (points == null || points.isEmpty) {
      if (_routeLine != null) {
        await ctrl.removeLine(_routeLine!);
        _routeLine = null;
      }
      return;
    }

    final latLngs = points.map((p) => LatLng(p[0], p[1])).toList();
    if (_routeLine == null) {
      _routeLine = await ctrl.addLine(
        LineOptions(
          geometry: latLngs,
          lineColor: '#6D0FA5',
          lineWidth: 5.5,
          lineOpacity: 0.9,
        ),
      );
    } else {
      await ctrl.updateLine(_routeLine!, LineOptions(geometry: latLngs));
    }

    // Fit camera to bounds
    if (latLngs.length > 1) {
      double minLat = latLngs.first.latitude;
      double maxLat = latLngs.first.latitude;
      double minLng = latLngs.first.longitude;
      double maxLng = latLngs.first.longitude;

      for (final p in latLngs) {
        if (p.latitude < minLat) minLat = p.latitude;
        if (p.latitude > maxLat) maxLat = p.latitude;
        if (p.longitude < minLng) minLng = p.longitude;
        if (p.longitude > maxLng) maxLng = p.longitude;
      }

      await ctrl.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLng),
            northeast: LatLng(maxLat, maxLng),
          ),
          left: 50,
          top: 70,
          right: 50,
          bottom: 100,
        ),
      );
    }
  }

  void _recenter() {
    final ctrl = _controller;
    if (ctrl == null) return;
    ctrl.animateCamera(
      CameraUpdate.newLatLngZoom(_initialCenter, widget.zoom),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLat = widget.driverLat ?? widget.centerLat ?? widget.pickupLat;
    final activeLng = widget.driverLng ?? widget.centerLng ?? widget.pickupLng;

    if (_loadingStyle || _resolvedStyleString == null || activeLat == null || activeLng == null || activeLat == 0 || activeLng == 0) {
      return Container(
        color: widget.isDark ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6D0FA5)),
        ),
      );
    }

    return Stack(
      children: [
        MapLibreMap(
          initialCameraPosition: CameraPosition(
            target: _initialCenter,
            zoom: widget.zoom,
          ),
          styleString: _resolvedStyleString!,
          onMapCreated: _onMapCreated,
          onStyleLoadedCallback: _onStyleLoaded,
          myLocationEnabled: widget.showUserLocation,
          myLocationRenderMode: MyLocationRenderMode.normal,
          compassEnabled: false,
          attributionButtonMargins: const math.Point(-100, -100),
        ),

        if (widget.showLocationButton)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'driver_recenter_fab',
              mini: true,
              backgroundColor: widget.isDark ? const Color(0xFF27272A) : Colors.white,
              foregroundColor: widget.isDark ? Colors.white : const Color(0xFF18181B),
              elevation: 4,
              onPressed: _recenter,
              child: const Icon(LucideIcons.crosshair, size: 20),
            ),
          ),
      ],
    );
  }
}
