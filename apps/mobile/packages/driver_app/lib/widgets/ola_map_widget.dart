import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class OlaMapWidget extends StatefulWidget {
  final double? centerLat;
  final double? centerLng;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? pickupLngCustom;
  final double? destLng;
  final double? driverLat;
  final double? driverLng;
  final double zoom;

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
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; overflow: hidden; background-color: #18181B; }
    #map { position: absolute; top: 0; bottom: 0; width: 100%; height: 100%; }
    .maplibregl-ctrl, .olamaps-ctrl, [class*="-ctrl"], [class*="ctrl-"] { display: none !important; }
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

    function initMap(apiKey, centerLat, centerLng, zoom) {
      myApiKey = apiKey;
      olaMaps = new OlaMaps({ apiKey: apiKey });
      map = olaMaps.init({
        style: 'https://api.olamaps.io/tiles/vector/v1/styles/default-dark-standard/style.json?api_key=' + apiKey,
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
        renderPolyline([[pLng, pLat], [dLng, dLat]]);
      })
      .catch(error => {
        console.error('Directions error:', error);
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
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF18181B))
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
              "initMap('$_apiKey', $initialLat, $initialLng, ${widget.zoom});"
            );
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

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _webViewController);
  }
}
