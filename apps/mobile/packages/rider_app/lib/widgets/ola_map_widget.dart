import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared/theme/app_theme.dart';
import 'package:rider_app/providers/ui_state_providers.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OlaMapWidget extends StatefulWidget {
  final double? centerLat;
  final double? centerLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? pickupLngCustom; // Helper mapping to avoid naming duplicates if any
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final double zoom;

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
    this.pickupLngCustom,
    this.nearbyDrivers,
    this.zoom = 15.0,
  });

  @override
  State<OlaMapWidget> createState() => _OlaMapWidgetState();
}

class _OlaMapWidgetState extends State<OlaMapWidget> {
  late final WebViewController _webViewController;
  bool _isMapInitialized = false;

  final String _apiKey = '6ZPQI6AaSeXkgvIhqIQaxyEfscr8oXvgRTEpwPYj';

  static const String _htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="initial-scale=1,maximum-scale=1,user-scalable=no">
  <title>Ola Maps</title>
  <link href="https://unpkg.com/maplibre-gl@latest/dist/maplibre-gl.css" rel="stylesheet" />
  <script src="https://www.unpkg.com/olamaps-web-sdk@latest/dist/olamaps-web-sdk.umd.js"></script>
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background-color: transparent; }
    #map { position: absolute; top: 0; bottom: 0; width: 100%; height: 100%; }
    /* Hide all MapLibre / Ola Maps control containers */
    .maplibregl-ctrl, .olamaps-ctrl, [class*="-ctrl"], [class*="ctrl-"] { display: none !important; }
    /* Hide any logo or attribution overlays */
    .maplibregl-ctrl-attrib, .maplibregl-ctrl-logo, .olamaps-ctrl-attrib, .olamaps-ctrl-logo { display: none !important; }
    div[class*="attrib"], div[class*="logo"] { display: none !important; }
    span[class*="attrib"], span[class*="logo"] { display: none !important; }
    img[src*="ola"], img[src*="logo"], img[class*="logo"] { display: none !important; }
    a[href*="olamaps"], a[href*="ola"], a[href*="openstreetmap"], a[href*="mapbox"] { display: none !important; }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    let map;
    let userMarker;
    let driverMarker;
    let pickupMarker;
    let destMarker;
    let olaMaps;
    let isMapLoaded = false;
    let pendingRoute = null;
    let pendingUser = null;
    let pendingDriver = null;
    let myApiKey = '';

    function decodePolyline(encoded) {
      let points = [];
      let index = 0, len = encoded.length;
      let lat = 0, lng = 0;

      while (index < len) {
        let b, shift = 0, result = 0;
        do {
          b = encoded.charCodeAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        let dlat = ((result & 1) ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.charCodeAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        let dlng = ((result & 1) ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        points.push([lng / 1E5, lat / 1E5]);
      }
      return points;
    }

    function initMap(apiKey, centerLat, centerLng, zoom, isDarkMode) {
      myApiKey = apiKey;
      olaMaps = new OlaMaps({ apiKey: apiKey });
      const styleName = isDarkMode ? 'default-dark-standard' : 'default-light-standard';
      map = olaMaps.init({
        style: 'https://api.olamaps.io/tiles/vector/v1/styles/' + styleName + '/style.json?api_key=' + apiKey,
        container: 'map',
        center: [centerLng, centerLat],
        zoom: zoom || 15,
        attributionControl: false
      });

      map.on('load', () => {
        isMapLoaded = true;
        if (pendingRoute) {
          drawRoute(pendingRoute.pLat, pendingRoute.pLng, pendingRoute.dLat, pendingRoute.dLng);
          pendingRoute = null;
        }
        if (pendingUser) {
          updateUserLocation(pendingUser.lat, pendingUser.lng, pendingUser.zoom);
          pendingUser = null;
        }
        if (pendingDriver) {
          updateDriverLocation(pendingDriver.lat, pendingDriver.lng);
          pendingDriver = null;
        }
      });
    }

    function setDarkMode(isDarkMode) {
      if (!map) return;
      const styleName = isDarkMode ? 'default-dark-standard' : 'default-light-standard';
      map.setStyle('https://api.olamaps.io/tiles/vector/v1/styles/' + styleName + '/style.json?api_key=' + myApiKey);
    }

    let nearbyMarkers = {};

    function updateNearbyDrivers(driversJsonString) {
      if (!map || !olaMaps) return;
      const drivers = JSON.parse(driversJsonString);
      
      const newDriverIds = new Set(drivers.map(d => d.id));
      for (const id in nearbyMarkers) {
        if (!newDriverIds.has(id)) {
          nearbyMarkers[id].remove();
          delete nearbyMarkers[id];
        }
      }

      drivers.forEach(d => {
        const heading = d.heading || 0;
        if (nearbyMarkers[d.id]) {
          nearbyMarkers[d.id].setLngLat([d.lng, d.lat]);
          if (nearbyMarkers[d.id].setRotation) {
            nearbyMarkers[d.id].setRotation(heading);
          } else {
            // Fallback if setRotation isn't available
            const el = nearbyMarkers[d.id].getElement();
            if (el && el.firstChild) {
              el.firstChild.style.transform = 'rotate(' + heading + 'deg)';
            }
          }
        } else {
          const marker = olaMaps.addMarker({
            color: '#F59E0B'
          }).setLngLat([d.lng, d.lat]);
          
          if (marker.setRotation) {
            marker.setRotation(heading);
          }
          marker.addTo(map);

          nearbyMarkers[d.id] = marker;

          const el = marker.getElement();
          if (el) {
            // A simple top-down flat car SVG wrapper
            el.innerHTML = '<div style="width: 28px; height: 56px; display: flex; align-items: center; justify-content: center; transform-origin: center center;' +
              (!marker.setRotation ? 'transform: rotate(' + heading + 'deg);' : '') + 
              '"><svg width="28" height="56" viewBox="0 0 28 56" xmlns="http://www.w3.org/2000/svg" style="filter: drop-shadow(0px 3px 6px rgba(0,0,0,0.4));">' +
              '<rect x="2" y="4" width="24" height="48" rx="8" fill="#111827" stroke="#374151" stroke-width="1.5"/>' +
              '<path d="M 4 14 L 24 14 L 21 22 L 7 22 Z" fill="#374151"/>' +
              '<path d="M 4 42 L 24 42 L 21 34 L 7 34 Z" fill="#374151"/>' +
              '<rect x="7" y="22" width="14" height="12" rx="2" fill="#1F2937"/>' +
              '<rect x="4" y="4" width="4" height="3" rx="1" fill="#FDE047"/>' +
              '<rect x="20" y="4" width="4" height="3" rx="1" fill="#FDE047"/>' +
              '<rect x="4" y="49" width="4" height="3" rx="1" fill="#EF4444"/>' +
              '<rect x="20" y="49" width="4" height="3" rx="1" fill="#EF4444"/>' +
              '</svg></div>';

            el.style.backgroundColor = 'transparent';
            el.style.backgroundImage = 'none';
            el.style.border = 'none';
          }
        }
      });
    }

    function updateUserLocation(lat, lng, zoom) {
      if (!map || !olaMaps) return;
      if (!isMapLoaded) {
        pendingUser = { lat, lng, zoom };
        return;
      }
      if (userMarker) {
        userMarker.setLngLat([lng, lat]);
      } else {
        userMarker = olaMaps.addMarker({
          color: '#2B8CEE',
        }).setLngLat([lng, lat]).addTo(map);
      }
      map.flyTo({ center: [lng, lat], zoom: zoom || 15 });
    }

    function updateDriverLocation(lat, lng) {
      if (!map || !olaMaps) return;
      if (!isMapLoaded) {
        pendingDriver = { lat, lng };
        return;
      }
      if (driverMarker) {
        driverMarker.setLngLat([lng, lat]);
      } else {
        driverMarker = olaMaps.addMarker({
          color: '#6D0FA5',
        }).setLngLat([lng, lat]).addTo(map);
      }
    }

    function drawRoute(pLat, pLng, dLat, dLng) {
      if (!map || !olaMaps) return;
      if (!isMapLoaded) {
        pendingRoute = { pLat, pLng, dLat, dLng };
        return;
      }
      
      if (pickupMarker) pickupMarker.remove();
      if (destMarker) destMarker.remove();

      pickupMarker = olaMaps.addMarker({ color: '#10B981' }).setLngLat([pLng, pLat]).addTo(map);
      destMarker = olaMaps.addMarker({ color: '#6D0FA5' }).setLngLat([dLng, dLat]).addTo(map);

      // Fetch the actual route from Ola Maps Directions API
      const directionsUrl = 'https://api.olamaps.io/routing/v1/directions?origin=' + pLat + ',' + pLng + '&destination=' + dLat + ',' + dLng + '&api_key=' + myApiKey;
      
      fetch(directionsUrl, {
        method: 'POST',
        headers: {
          'X-Request-Id': 'mr-rideo-' + Math.floor(Math.random() * 1000000)
        }
      })
      .then(response => {
        if (!response.ok) {
          throw new Error('Directions API error: ' + response.status);
        }
        return response.json();
      })
      .then(data => {
        if (data && data.routes && data.routes.length > 0) {
          const overviewPolyline = data.routes[0].overview_polyline;
          if (overviewPolyline) {
            const decodedPoints = decodePolyline(overviewPolyline);
            if (decodedPoints && decodedPoints.length > 0) {
              renderPolyline(decodedPoints);
              return;
            }
          }
        }
        // Fallback to straight line
        renderPolyline([[pLng, pLat], [dLng, dLat]]);
      })
      .catch(error => {
        console.error('Directions error:', error);
        // Fallback to straight line
        renderPolyline([[pLng, pLat], [dLng, dLat]]);
      });

      function renderPolyline(coordinates) {
        const routeData = {
          'type': 'Feature',
          'properties': {},
          'geometry': {
            'type': 'LineString',
            'coordinates': coordinates
          }
        };

        if (map.getSource('route')) {
          map.getSource('route').setData(routeData);
        } else {
          map.addSource('route', {
            'type': 'geojson',
            'data': routeData
          });

          map.addLayer({
            'id': 'route',
            'type': 'line',
            'source': 'route',
            'layout': {
              'line-join': 'round',
              'line-cap': 'round'
            },
            'paint': {
              'line-color': '#6D0FA5',
              'line-width': 2
            }
          });
        }

        const lats = coordinates.map(c => c[1]);
        const lngs = coordinates.map(c => c[0]);
        const minLng = Math.min.apply(null, lngs);
        const maxLng = Math.max.apply(null, lngs);
        const minLat = Math.min.apply(null, lats);
        const maxLat = Math.max.apply(null, lats);
        map.fitBounds([[minLng, minLat], [maxLng, maxLat]], { padding: 80 });
      }
    }
  </script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    final isDark = AppColors.isDark;
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            debugPrint("OlaMap WebView Error: ${error.description} (code: ${error.errorCode})");
          },
          onPageFinished: (String url) {
            setState(() {
              _isMapInitialized = true;
            });
            final initialLat = widget.centerLat ?? widget.pickupLat ?? 26.8467;
            final initialLng = widget.centerLng ?? widget.pickupLng ?? 80.9462;
            _webViewController.runJavaScript(
              "initMap('$_apiKey', $initialLat, $initialLng, ${widget.zoom}, $isDark);"
            );
            _updateNearbyDrivers();
            // Delay slightly to allow the map instance to setup before drawing markers/routes
            Future.delayed(const Duration(milliseconds: 500), () {
              _updateMarkersAndRoutes();
            });
          },
        ),
      )
      ..setOnConsoleMessage((JavaScriptConsoleMessage message) {
        debugPrint("OlaMap JS Console: [${message.level.name}] ${message.message}");
      })
      ..loadHtmlString(_htmlContent);
  }

  @override
  void didUpdateWidget(OlaMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isMapInitialized) {
      _updateMarkersAndRoutes();
      _updateNearbyDrivers();
      final isDark = AppColors.isDark;
      _webViewController.runJavaScript("setDarkMode($isDark);");
      _webViewController.setBackgroundColor(AppColors.background);
    }
  }

  void _updateMarkersAndRoutes() {
    if (widget.centerLat != null && widget.centerLng != null) {
      _webViewController.runJavaScript(
        "updateUserLocation(${widget.centerLat}, ${widget.centerLng}, ${widget.zoom});"
      );
    }
    if (widget.driverLat != null && widget.driverLng != null) {
      _webViewController.runJavaScript(
        "updateDriverLocation(${widget.driverLat}, ${widget.driverLng});"
      );
    }
    if (widget.pickupLat != null && widget.pickupLng != null &&
        widget.destLat != null && widget.destLng != null) {
      _webViewController.runJavaScript(
        "drawRoute(${widget.pickupLat}, ${widget.pickupLng}, ${widget.destLat}, ${widget.destLng});"
      );
    }
  }

  void _updateNearbyDrivers() {
    if (widget.nearbyDrivers != null) {
      final driversJson = jsonEncode(widget.nearbyDrivers!.map((d) => {
        'id': d.id,
        'name': d.name,
        'lat': d.lat,
        'lng': d.lng,
        'vehicleType': d.vehicleType,
        'heading': d.heading,
      }).toList());
      _webViewController.runJavaScript("updateNearbyDrivers('$driversJson');");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}
