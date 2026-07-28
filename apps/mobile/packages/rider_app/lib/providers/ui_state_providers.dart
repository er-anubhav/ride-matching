import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shared/shared.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class RouteMetrics {
  final double durationSeconds;
  final double distanceMeters;
  final String? overviewPolyline;

  RouteMetrics({
    required this.durationSeconds,
    required this.distanceMeters,
    this.overviewPolyline,
  });
}

final routeMetricsProvider = FutureProvider<RouteMetrics?>((ref) async {
  final location = ref.watch(locationProvider);
  final currentLoc = ref.watch(currentLocationProvider);
  
  final pLat = location.pickupLat ?? currentLoc.value?.latitude;
  final pLng = location.pickupLng ?? currentLoc.value?.longitude;
  final dLat = location.destLat;
  final dLng = location.destLng;

  if (pLat == null || pLng == null || dLat == null || dLng == null || (pLat == dLat && pLng == dLng)) {
    return null;
  }

  try {
    const apiKey = '6ZPQI6AaSeXkgvIhqIQaxyEfscr8oXvgRTEpwPYj';
    final directionsUrl = 'https://api.olamaps.io/routing/v1/directions?origin=$pLat,$pLng&destination=$dLat,$dLng&api_key=$apiKey';
    
    final response = await http.post(
      Uri.parse(directionsUrl),
      headers: {
        'X-Request-Id': 'mr-rideo-${DateTime.now().millisecondsSinceEpoch}',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data != null && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final firstRoute = data['routes'][0];
        final overviewPolyline = firstRoute['overview_polyline'] as String?;
        final legs = firstRoute['legs'] as List?;
        if (legs != null && legs.isNotEmpty) {
          final leg = legs[0];
          
          final durationData = leg['duration'];
          double? durationSecs;
          if (durationData is Map) {
            durationSecs = (durationData['value'] as num?)?.toDouble();
          } else if (durationData is num) {
            durationSecs = durationData.toDouble();
          }

          final distanceData = leg['distance'];
          double? distanceMets;
          if (distanceData is Map) {
            distanceMets = (distanceData['value'] as num?)?.toDouble();
          } else if (distanceData is num) {
            distanceMets = distanceData.toDouble();
          }

          if (durationSecs != null && distanceMets != null) {
            return RouteMetrics(
              durationSeconds: durationSecs,
              distanceMeters: distanceMets,
              overviewPolyline: overviewPolyline,
            );
          }
        }
      }
    }
  } catch (e) {
    // Fail silently
  }
  return null;
});

// User Profile Model
class UserProfile {
  final String name;
  final String phone;
  final double rating;
  final String avatarUrl;

  UserProfile({
    required this.name,
    required this.phone,
    required this.rating,
    required this.avatarUrl,
  });
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier()
      : super(UserProfile(
          name: "",
          phone: "",
          rating: 5.0,
          avatarUrl: "",
        )) {
    loadFromToken();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final res = await ApiClient().get('/profile');
      if (res != null && res is Map<String, dynamic>) {
        final profileData = res['data'] ?? res;
        state = UserProfile(
          name: profileData['name'] ?? profileData['fullName'] ?? state.name,
          phone: profileData['phone'] ?? profileData['phoneNumber'] ?? state.phone,
          rating: (profileData['rating'] as num?)?.toDouble() ?? state.rating,
          avatarUrl: profileData['avatarUrl'] ?? profileData['avatar'] ?? state.avatarUrl,
        );
      }
    } catch (_) {}
  }

  Future<void> loadFromToken() async {
    try {
      final token = await ApiClient().getToken();
      if (token != null) {
        final payload = _decodeJwt(token);
        if (payload != null) {
          final phone = payload['phone'] as String? ?? state.phone;
          final rawName = payload['name'] as String?;
          final name = (rawName != null && rawName.isNotEmpty) ? rawName : state.name;
          state = UserProfile(
            name: name,
            phone: phone,
            rating: state.rating,
            avatarUrl: state.avatarUrl,
          );
        }
      }
    } catch (_) {}
  }

  void updateName(String name) {
    state = UserProfile(
      name: name,
      phone: state.phone,
      rating: state.rating,
      avatarUrl: state.avatarUrl,
    );
    updateProfile(name: name);
  }

  void updateAvatarUrl(String avatarUrl) {
    state = UserProfile(
      name: state.name,
      phone: state.phone,
      rating: state.rating,
      avatarUrl: avatarUrl,
    );
    updateProfile(avatarUrl: avatarUrl);
  }

  Future<void> updateProfile({String? name, String? phone, String? avatarUrl}) async {
    state = UserProfile(
      name: name ?? state.name,
      phone: phone ?? state.phone,
      rating: state.rating,
      avatarUrl: avatarUrl ?? state.avatarUrl,
    );
    try {
      await ApiClient().put('/profile', {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
      });
    } catch (_) {}
  }
}

Map<String, dynamic>? _decodeJwt(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final normalized = base64Url.normalize(parts[1]);
    final payloadString = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(payloadString) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});

final fareEstimateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final location = ref.watch(locationProvider);
  final currentLoc = ref.watch(currentLocationProvider);

  final pLat = location.pickupLat ?? currentLoc.value?.latitude;
  final pLng = location.pickupLng ?? currentLoc.value?.longitude;
  final dLat = location.destLat;
  final dLng = location.destLng;

  if (pLat == null || pLng == null || dLat == null || dLng == null || (pLat == dLat && pLng == dLng)) {
    return null;
  }

  try {
    final response = await ApiClient().post('/trips/estimate', {
      'pickupLat': pLat,
      'pickupLng': pLng,
      'dropoffLat': dLat,
      'dropoffLng': dLng,
    });
    return response['estimates'] as Map<String, dynamic>?;
  } catch (e) {
    debugPrint('Error fetching fare estimates: $e');
    return null;
  }
});

// Location State Model
class LocationState {
  final String pickupAddress;
  final String destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? destLat;
  final double? destLng;

  LocationState({
    this.pickupAddress = "My Current Location",
    this.destinationAddress = "",
    this.pickupLat,
    this.pickupLng,
    this.destLat,
    this.destLng,
  });

  LocationState copyWith({
    String? pickupAddress,
    String? destinationAddress,
    double? pickupLat,
    double? pickupLng,
    double? destLat,
    double? destLng,
  }) {
    return LocationState(
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destLat: destLat ?? this.destLat,
      destLng: destLng ?? this.destLng,
    );
  }
}

class LocationStateNotifier extends StateNotifier<LocationState> {
  final Ref _ref;

  LocationStateNotifier(this._ref) : super(LocationState()) {
    // Listen to currentLocationProvider to update pickup coordinates if they aren't explicitly set yet
    _ref.listen<AsyncValue<Position>>(currentLocationProvider, (previous, next) {
      next.whenData((position) {
        if (state.pickupLat == null && state.pickupLng == null) {
          state = state.copyWith(
            pickupLat: position.latitude,
            pickupLng: position.longitude,
          );
        }
      });
    }, fireImmediately: true);
  }

  void setPickup(String address, double lat, double lng) {
    state = state.copyWith(pickupAddress: address, pickupLat: lat, pickupLng: lng);
  }

  void setDestination(String address, double lat, double lng) {
    state = state.copyWith(destinationAddress: address, destLat: lat, destLng: lng);
  }

  void clearDestination() {
    state = state.copyWith(destinationAddress: "", destLat: null, destLng: null);
  }
}

final locationProvider = StateNotifierProvider<LocationStateNotifier, LocationState>((ref) {
  return LocationStateNotifier(ref);
});

class SearchHistoryItem {
  final String address;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  SearchHistoryItem({
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });
}

class SearchHistoryNotifier extends StateNotifier<List<SearchHistoryItem>> {
  SearchHistoryNotifier() : super([]) {
    fetchRecentSearches();
  }

  Future<void> fetchRecentSearches() async {
    try {
      final res = await ApiClient().get('/recent-searches');
      if (res != null && res is List) {
        state = res.map((item) {
          return SearchHistoryItem(
            address: item['address'] ?? '',
            latitude: (item['latitude'] as num?)?.toDouble() ?? 0.0,
            longitude: (item['longitude'] as num?)?.toDouble() ?? 0.0,
            timestamp: item['timestamp'] != null
                ? DateTime.tryParse(item['timestamp'].toString()) ?? DateTime.now()
                : DateTime.now(),
          );
        }).toList();
      }
    } catch (_) {}
  }

  Future<void> addHistory(String address, double lat, double lng) async {
    if (address.isEmpty) return;
    state = [
      SearchHistoryItem(address: address, latitude: lat, longitude: lng, timestamp: DateTime.now()),
      ...state.where((item) => item.address != address)
    ].take(10).toList();

    try {
      await ApiClient().post('/recent-searches', {
        'address': address,
        'latitude': lat,
        'longitude': lng,
      });
    } catch (_) {}
  }

  void clearHistory() {
    state = [];
  }

  Future<void> removeHistory(String address) async {
    state = state.where((item) => item.address != address).toList();
    try {
      await ApiClient().delete('/recent-searches?address=${Uri.encodeComponent(address)}');
    } catch (_) {}
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<SearchHistoryItem>>((ref) {
  return SearchHistoryNotifier();
});

class BookmarkItem {
  final String? id;
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  BookmarkItem({
    this.id,
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  factory BookmarkItem.fromJson(Map<String, dynamic> json) {
    return BookmarkItem(
      id: json['id']?.toString(),
      label: json['label'] ?? json['name'] ?? 'Saved Place',
      address: json['address'] ?? '',
      latitude: (json['latitude'] ?? json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] ?? json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class BookmarksNotifier extends StateNotifier<List<BookmarkItem>> {
  BookmarksNotifier() : super([]) {
    fetchSavedPlaces();
  }

  Future<void> fetchSavedPlaces() async {
    try {
      final response = await ApiClient().get('/saved-places');
      if (response != null && response is List) {
        state = response.map((item) => BookmarkItem.fromJson(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint("Saved places fetch notice: $e");
    }
  }

  Future<void> addBookmark(String label, String address, double lat, double lng) async {
    if (label.isEmpty || address.isEmpty) return;

    final tempItem = BookmarkItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      address: address,
      latitude: lat,
      longitude: lng,
    );
    state = [...state.where((item) => item.address != address), tempItem];

    try {
      final response = await ApiClient().post('/saved-places', {
        'label': label,
        'address': address,
        'latitude': lat,
        'longitude': lng,
      });

      if (response != null && response['id'] != null) {
        await fetchSavedPlaces();
      }
    } catch (e) {
      debugPrint("Failed to post saved place to backend: $e");
    }
  }

  Future<void> removeBookmark(String idOrAddress) async {
    final target = state.firstWhere(
      (item) => item.id == idOrAddress || item.address == idOrAddress,
      orElse: () => BookmarkItem(label: '', address: '', latitude: 0, longitude: 0),
    );

    state = state.where((item) => item.id != idOrAddress && item.address != idOrAddress).toList();

    if (target.id != null && target.id!.isNotEmpty) {
      try {
        await ApiClient().delete('/saved-places/${target.id}');
      } catch (e) {
        debugPrint("Failed to delete saved place from backend: $e");
      }
    }
  }
}

final bookmarksProvider = StateNotifierProvider<BookmarksNotifier, List<BookmarkItem>>((ref) {
  return BookmarksNotifier();
});

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  connectionError,
}

// Booking State
enum RideBookingStatus {
  idle,
  searching,
  driverArriving,
  inProgress,
  completed,
}

class BookingState {
  final RideBookingStatus status;
  final String? driverName;
  final String? vehicleNumber;
  final String? otp;
  final double? driverLat;
  final double? driverLng;
  final double? driverStartLat;
  final double? driverStartLng;
  final String? eta;
  final String? tripId;
  final String? vehicleName;
  final String? vehicleModel;
  final String? driverArrivalEta;
  final String? tripDurationEta;
  final double? price;
  final WebSocketStatus webSocketStatus;

  BookingState({
    required this.status,
    this.driverName,
    this.vehicleNumber,
    this.otp,
    this.driverLat,
    this.driverLng,
    this.driverStartLat,
    this.driverStartLng,
    this.eta,
    this.vehicleName,
    this.vehicleModel,
    this.tripId,
    this.driverArrivalEta,
    this.tripDurationEta,
    this.price,
    this.webSocketStatus = WebSocketStatus.disconnected,
  });

  BookingState copyWith({
    RideBookingStatus? status,
    String? driverName,
    String? vehicleNumber,
    String? otp,
    double? driverLat,
    double? driverLng,
    double? driverStartLat,
    double? driverStartLng,
    String? eta,
    String? vehicleName,
    String? vehicleModel,
    String? driverArrivalEta,
    String? tripDurationEta,
    double? price,
    String? tripId,
    WebSocketStatus? webSocketStatus,
  }) {
    return BookingState(
      status: status ?? this.status,
      driverName: driverName ?? this.driverName,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      otp: otp ?? this.otp,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      driverStartLat: driverStartLat ?? this.driverStartLat,
      driverStartLng: driverStartLng ?? this.driverStartLng,
      eta: eta ?? this.eta,
      vehicleName: vehicleName ?? this.vehicleName,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      tripId: tripId ?? this.tripId,
      driverArrivalEta: driverArrivalEta ?? this.driverArrivalEta,
      tripDurationEta: tripDurationEta ?? this.tripDurationEta,
      price: price ?? this.price,
      webSocketStatus: webSocketStatus ?? this.webSocketStatus,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  final Ref _ref;
  Timer? _driverSimTimer;
  int _simStep = 0;
  WebSocket? _webSocket;

  BookingNotifier(this._ref) : super(BookingState(status: RideBookingStatus.idle));

  void _cancelSimTimer() {
    _driverSimTimer?.cancel();
    _driverSimTimer = null;
    _simStep = 0;
  }

  void startSearch({
    required String vehicleName,
    required String driverArrivalEta,
    required String tripDurationEta,
    required double price,
  }) {
    _cancelSimTimer();
    _closeWebSocket();
    state = BookingState(
      status: RideBookingStatus.searching,
      vehicleName: vehicleName,
      driverArrivalEta: driverArrivalEta,
      tripDurationEta: tripDurationEta,
      price: price,
      webSocketStatus: WebSocketStatus.connecting,
    );
    
    // Request trip on backend
    _requestTripOnBackend(vehicleName, price);
    
    // Attempt WebSocket connection
    _connectWebSocket();
  }

  Future<void> _requestTripOnBackend(String vehicleName, double price) async {
    final location = _ref.read(locationProvider);
    String vehicleType = 'cab';
    if (vehicleName.contains('Bike')) {
      vehicleType = 'bike';
    } else if (vehicleName.contains('Auto')) {
      vehicleType = 'auto';
    }

    try {
      final response = await ApiClient().post('/trips/request', {
        'pickupLat': location.pickupLat ?? 26.8500,
        'pickupLng': location.pickupLng ?? 80.9400,
        'pickupAddress': location.pickupAddress,
        'dropoffLat': location.destLat ?? 26.8600,
        'dropoffLng': location.destLng ?? 80.9500,
        'dropoffAddress': location.destinationAddress,
        'vehicleType': vehicleType,
      });
      if (response != null && response['trip'] != null) {
        final trip = response['trip'];
        final tripId = trip['id'] as String?;
        debugPrint("Trip created on backend: $tripId");
        if (tripId != null && mounted) {
          state = state.copyWith(tripId: tripId);
        }
      }
    } catch (e) {
      debugPrint("Failed to request trip on backend: $e");
      // Continue anyway — WebSocket will still attempt matching
    }
  }

  Future<void> _connectWebSocket() async {
    final token = await ApiClient().getToken();
    final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
    final query = token != null ? '/ride-tracking?token=$token' : '/ride-tracking';
    final urls = _getWebSocketUrls(query);

    for (final wsUrl in urls) {
      try {
        debugPrint("Attempting Booking connection to $wsUrl");
        _webSocket = await WebSocket.connect(wsUrl, headers: headers).timeout(const Duration(seconds: 2));
        debugPrint("✅ Booking WebSocket connected successfully to $wsUrl");
        
        if (!mounted) return;
        state = state.copyWith(webSocketStatus: WebSocketStatus.connected);

        final location = _ref.read(locationProvider);
        final initialMsg = jsonEncode({
          'type': 'request_ride',
          'vehicleName': state.vehicleName,
          'pickupLat': location.pickupLat,
          'pickupLng': location.pickupLng,
          'pickupAddress': location.pickupAddress,
          'destLat': location.destLat,
          'destLng': location.destLng,
          'dropoffAddress': location.destinationAddress,
          'price': state.price,
        });
        _webSocket!.add(initialMsg);

        _webSocket!.listen(
          (message) {
            if (!mounted) return;
            try {
              final data = jsonDecode(message as String);
              _handleWebSocketMessage(data);
            } catch (e) {
              debugPrint("Error parsing WebSocket message: $e");
            }
          },
          onError: (error) {
            if (!mounted) return;
            debugPrint("WebSocket error: $error");
            _handleWebSocketDisconnect();
          },
          onDone: () {
            if (!mounted) return;
            debugPrint("WebSocket connection closed");
            _handleWebSocketDisconnect();
          },
        );
        return; // Connection succeeded, exit loop
      } catch (e) {
        debugPrint("Booking connection to $wsUrl failed: $e");
      }
    }

    // If all fail:
    _handleWebSocketDisconnect();
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (!mounted) return;
    final type = data['type'] as String?;
    if (type == null) return;

    switch (type) {
      case 'driver_matched':
        final driverName = data['driverName'] as String? ?? "Vikram Singh";
        final vehicleNumber = data['vehicleNumber'] as String? ?? "UP 32 BK 1234";
        final vehicleModel = data['vehicleModel'] as String? ?? "Bajaj Pulsar 150";
        final otp = data['otp'] as String? ?? "4820";
        final eta = data['eta'] as String? ?? "3 mins";
        final dLat = (data['driverLat'] as num?)?.toDouble();
        final dLng = (data['driverLng'] as num?)?.toDouble();
        final startLat = (data['driverStartLat'] as num?)?.toDouble();
        final startLng = (data['driverStartLng'] as num?)?.toDouble();

        state = state.copyWith(
          status: RideBookingStatus.driverArriving,
          driverName: driverName,
          vehicleNumber: vehicleNumber,
          vehicleModel: vehicleModel,
          otp: otp,
          eta: eta,
          driverLat: dLat,
          driverLng: dLng,
          driverStartLat: startLat,
          driverStartLng: startLng,
        );
        break;

      case 'location_update':
        final dLat = (data['lat'] as num?)?.toDouble();
        final dLng = (data['lng'] as num?)?.toDouble();
        final eta = data['eta'] as String?;
        if (dLat != null && dLng != null) {
          state = state.copyWith(
            driverLat: dLat,
            driverLng: dLng,
            eta: eta ?? state.eta,
          );
        }
        break;

      case 'ride_started':
        state = state.copyWith(
          status: RideBookingStatus.inProgress,
          eta: state.tripDurationEta ?? "12 mins",
        );
        break;

      case 'ride_completed':
        completeRide();
        break;
      
      case 'error':
        state = state.copyWith(webSocketStatus: WebSocketStatus.connectionError);
        break;
    }
  }

  void _handleWebSocketDisconnect() {
    _closeWebSocket();
    if (!mounted) return;
    state = state.copyWith(webSocketStatus: WebSocketStatus.connectionError);
  }

  void _closeWebSocket() {
    _webSocket?.close();
    _webSocket = null;
  }

  void retryConnection() {
    _closeWebSocket();
    _cancelSimTimer();
    state = state.copyWith(webSocketStatus: WebSocketStatus.connecting);
    _connectWebSocket();
  }

  Future<void> matchDriver() async {
    final vName = state.vehicleName ?? "Mr. Rideo Bike";
    String vNum = "UP 32 BK 1234";
    String eta = state.driverArrivalEta ?? "3 mins";
    String vModel = "Bajaj Pulsar 150";

    if (vName.contains("Bike")) {
      vNum = "UP 32 BK 1234";
      vModel = "Bajaj Pulsar 150";
    } else if (vName.contains("Auto")) {
      vNum = "UP 32 AT 5678";
      vModel = "Bajaj RE E-Auto";
    } else if (vName.contains("Cab XL") || vName.contains("7-Seater")) {
      vNum = "UP 32 XL 7777";
      vModel = "Maruti Ertiga (7-Seater)";
    } else { // Cab normal
      vNum = "UP 32 CB 4321";
      vModel = "Suzuki Swift Dzire";
    }

    // Start driver far from pickup and animate toward it
    final location = _ref.read(locationProvider);
    final pickupLat = location.pickupLat ?? 26.8500;
    final pickupLng = location.pickupLng ?? 80.9400;
    // Driver starts ~0.008 degrees (~900m) offset from pickup
    final driverStartLat = pickupLat + 0.008;
    final driverStartLng = pickupLng - 0.005;

    state = state.copyWith(
      status: RideBookingStatus.driverArriving,
      driverName: "Vikram Singh",
      vehicleNumber: vNum,
      otp: "4820",
      eta: eta,
      driverLat: driverStartLat,
      driverLng: driverStartLng,
      driverStartLat: driverStartLat,
      driverStartLng: driverStartLng,
      vehicleName: vName,
      vehicleModel: vModel,
    );
  }

  List<List<double>> _decodePolyline(String encoded) {
    List<List<double>> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add([lat / 1E5, lng / 1E5]);
    }
    return points;
  }

  void startRide() {
    _cancelSimTimer();
    final location = _ref.read(locationProvider);
    final pickupLat = location.pickupLat;
    final pickupLng = location.pickupLng;

    state = state.copyWith(
      status: RideBookingStatus.inProgress,
      eta: state.tripDurationEta ?? "12 mins",
      driverLat: pickupLat,
      driverLng: pickupLng,
    );
  }

  void completeRide() {
    _closeWebSocket();
    final location = _ref.read(locationProvider);
    final metrics = _ref.read(routeMetricsProvider).value;

    final double distanceKm = (metrics?.distanceMeters ?? 5000.0) / 1000.0;
    
    // Choose appropriate vehicle icon
    IconData vehicleIcon = LucideIcons.car;
    if (state.vehicleName?.contains("Bike") == true) {
      vehicleIcon = LucideIcons.bike;
    } else if (state.vehicleName?.contains("Auto") == true) {
      vehicleIcon = LucideIcons.car;
    }

    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? "PM" : "AM";
    final minuteStr = now.minute.toString().padLeft(2, '0');
    final timeStr = "$hour:$minuteStr $amPm";
    final dateStr = "Today, $timeStr";

    final newTrip = {
      "id": "TRP-${now.millisecondsSinceEpoch.toString().substring(7)}",
      "date": dateStr,
      "pickup": location.pickupAddress,
      "destination": location.destinationAddress,
      "vehicle": state.vehicleName ?? "Ride",
      "vehicleIcon": vehicleIcon,
      "price": state.price ?? 120.0,
      "status": "Completed",
      "driver": state.driverName ?? "Vikram Singh",
      "driverRating": 4.8,
      "duration": state.tripDurationEta ?? "10 min",
      "distance": "${distanceKm.toStringAsFixed(1)} km",
      "promo": null,
      "promoDiscount": 0.00,
    };

    _ref.read(tripHistoryProvider.notifier).addTrip(newTrip);

    state = state.copyWith(
      status: RideBookingStatus.completed,
      eta: "0 mins",
    );
  }

  void reset() {
    _closeWebSocket();
    _cancelSimTimer();
    state = BookingState(status: RideBookingStatus.idle);
  }

  @override
  void dispose() {
    _closeWebSocket();
    _cancelSimTimer();
    super.dispose();
  }
}

final bookingProvider = StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier(ref);
});

// Trip History Notifier & Provider
class TripHistoryNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  TripHistoryNotifier() : super([]) {
    fetchTripHistory();
  }

  Future<void> fetchTripHistory() async {
    try {
      final res = await ApiClient().get('/rides/history');
      if (res != null && res is List) {
        state = res.cast<Map<String, dynamic>>();
      }
    } catch (_) {}
  }

  void addTrip(Map<String, dynamic> trip) {
    state = [trip, ...state];
  }

  void updateTripRating(String tripId, int rating) {
    state = state.map((trip) {
      if (trip["id"] == tripId) {
        return {...trip, "userRating": rating};
      }
      return trip;
    }).toList();
  }
}

final tripHistoryProvider = StateNotifierProvider<TripHistoryNotifier, List<Map<String, dynamic>>>((ref) {
  return TripHistoryNotifier();
});

// Wallet Balance State
class WalletState {
  final double balance;
  final List<String> transactions;

  WalletState({
    required this.balance,
    required this.transactions,
  });
}

class WalletNotifier extends StateNotifier<WalletState> {
  WalletNotifier()
      : super(WalletState(
          balance: 0.0,
          transactions: [],
        )) {
    fetchWallet();
  }

  Future<void> fetchWallet() async {
    try {
      final res = await ApiClient().get('/wallet');
      if (res != null && res is Map<String, dynamic>) {
        final bal = (res['balance'] as num?)?.toDouble() ?? 0.0;
        final txs = (res['transactions'] as List?)?.map((t) => t.toString()).toList() ?? [];
        state = WalletState(balance: bal, transactions: txs);
      }
    } catch (_) {}
  }

  Future<void> addMoney(double amount) async {
    state = WalletState(
      balance: state.balance + amount,
      transactions: [
        "Added Money via UPI - ₹${amount.toStringAsFixed(2)} added",
        ...state.transactions
      ],
    );
    try {
      await ApiClient().post('/wallet/add-money', {'amount': amount});
    } catch (_) {}
  }

  void deductMoney(double amount, String tripName) {
    state = WalletState(
      balance: state.balance - amount,
      transactions: [
        "Trip to $tripName - ₹${amount.toStringAsFixed(2)} deducted",
        ...state.transactions
      ],
    );
  }
}

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier();
});

// SOS Contacts state models & providers
class SosContact {
  final String id;
  final String name;
  final String phone;

  SosContact({required this.id, required this.name, required this.phone});

  factory SosContact.fromJson(Map<String, dynamic> json) {
    return SosContact(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? json['phoneNumber'] ?? '',
    );
  }
}

class SosContactsNotifier extends StateNotifier<List<SosContact>> {
  SosContactsNotifier() : super([]) {
    fetchContacts();
  }

  Future<void> fetchContacts() async {
    try {
      final res = await ApiClient().get('/sos/contacts');
      if (res != null && res is List) {
        state = res.map((c) => SosContact.fromJson(c)).toList();
      }
    } catch (_) {}
  }

  Future<void> addContact(String name, String phone) async {
    final tempContact = SosContact(id: DateTime.now().toString(), name: name, phone: phone);
    state = [...state, tempContact];

    try {
      await ApiClient().post('/sos/contact', {
        'name': name,
        'phone': phone,
      });
    } catch (_) {}
  }

  Future<void> removeContact(String id) async {
    state = state.where((c) => c.id != id).toList();
    try {
      await ApiClient().delete('/sos/contact/$id');
    } catch (_) {}
  }
}

final sosContactsProvider = StateNotifierProvider<SosContactsNotifier, List<SosContact>>((ref) {
  return SosContactsNotifier();
});

// Payment Methods state models & providers
class PaymentMethod {
  final String id;
  final String type; // 'card' or 'upi'
  final String label; // e.g. "Visa **** 4242"
  final bool isDefault;

  PaymentMethod({required this.id, required this.type, required this.label, this.isDefault = false});

  PaymentMethod copyWith({String? id, String? type, String? label, bool? isDefault}) {
    return PaymentMethod(
      id: id ?? this.id,
      type: type ?? this.type,
      label: label ?? this.label,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id']?.toString() ?? '',
      type: json['type'] ?? 'card',
      label: json['label'] ?? json['cardNumber'] ?? 'Saved Method',
      isDefault: json['isDefault'] ?? false,
    );
  }
}

class PaymentMethodsNotifier extends StateNotifier<List<PaymentMethod>> {
  PaymentMethodsNotifier() : super([]) {
    fetchPaymentMethods();
  }

  Future<void> fetchPaymentMethods() async {
    try {
      final res = await ApiClient().get('/wallet/payment-methods');
      if (res != null && res is List) {
        state = res.map((p) => PaymentMethod.fromJson(p)).toList();
      }
    } catch (_) {}
  }

  Future<void> addCard(String lastFour) async {
    state = [
      ...state.map((e) => e.copyWith(isDefault: false)),
      PaymentMethod(id: DateTime.now().toString(), type: "card", label: "Card •••• $lastFour", isDefault: true),
    ];
    try {
      await ApiClient().post('/wallet/payment-methods', {
        'type': 'card',
        'lastFour': lastFour,
      });
    } catch (_) {}
  }

  Future<void> addUpi(String upiId) async {
    state = [
      ...state.map((e) => e.copyWith(isDefault: false)),
      PaymentMethod(id: DateTime.now().toString(), type: "upi", label: upiId, isDefault: true),
    ];
    try {
      await ApiClient().post('/wallet/payment-methods', {
        'type': 'upi',
        'upiId': upiId,
      });
    } catch (_) {}
  }

  void setDefault(String id) {
    state = state.map((item) {
      return item.copyWith(isDefault: item.id == id);
    }).toList();
  }

  Future<void> deleteMethod(String id) async {
    final wasDefault = state.firstWhere((element) => element.id == id, orElse: () => state.first).isDefault;
    state = state.where((m) => m.id != id).toList();
    if (wasDefault && state.isNotEmpty) {
      state = [
        state.first.copyWith(isDefault: true),
        ...state.sublist(1),
      ];
    }
    try {
      await ApiClient().delete('/wallet/payment-methods/$id');
    } catch (_) {}
  }

  Future<void> removeMethod(String id) => deleteMethod(id);
}

final paymentMethodsProvider = StateNotifierProvider<PaymentMethodsNotifier, List<PaymentMethod>>((ref) {
  return PaymentMethodsNotifier();
});

// Support Tickets Notifier & Provider
class SupportTicket {
  final String id;
  final String category;
  final String message;
  final String date;
  final String status;

  SupportTicket({
    required this.id,
    required this.category,
    required this.message,
    required this.date,
    required this.status,
  });
}

class SupportTicketsNotifier extends StateNotifier<List<SupportTicket>> {
  SupportTicketsNotifier() : super([]) {
    fetchTickets();
  }

  Future<void> fetchTickets() async {
    try {
      final res = await ApiClient().get('/support/tickets');
      if (res != null && res is List) {
        state = res.map((t) => SupportTicket(
          id: t['id']?.toString() ?? 'TCK-${Random().nextInt(9000) + 1000}',
          category: t['category'] ?? 'General',
          message: t['message'] ?? '',
          date: t['date'] ?? 'Recently',
          status: t['status'] ?? 'Pending',
        )).toList();
      }
    } catch (_) {}
  }

  Future<void> raiseTicket(String category, String message) async {
    final tempTicket = SupportTicket(
      id: "TCK-${4821 + state.length}",
      category: category,
      message: message,
      date: "Just now",
      status: "Pending",
    );
    state = [tempTicket, ...state];

    try {
      await ApiClient().post('/support/ticket', {
        'category': category,
        'message': message,
      });
    } catch (_) {}
  }
}

final supportTicketsProvider = StateNotifierProvider<SupportTicketsNotifier, List<SupportTicket>>((ref) {
  return SupportTicketsNotifier();
});

// Promo Validation Function
Future<Map<String, dynamic>?> validatePromoCode(String code) async {
  try {
    final res = await ApiClient().post('/promo/validate', {'code': code});
    if (res != null && res is Map<String, dynamic>) {
      return res;
    }
  } catch (_) {}
  return null;
}

class CurrentLocationNotifier extends StateNotifier<AsyncValue<Position>> {
  CurrentLocationNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  /// Call this after the user grants location permission to re-fetch the position.
  void refresh() => _init();


  void _init() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        state = AsyncValue.error('Location services are disabled.', StackTrace.current);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          state = AsyncValue.error('Location permissions are denied', StackTrace.current);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        state = AsyncValue.error('Location permissions are permanently denied.', StackTrace.current);
        return;
      }

      // Check last known location first for immediate response
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        state = AsyncValue.data(lastKnown);
      }

      // Get current position with a timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      ).catchError((e) async {
        debugPrint("Error or timeout getting high accuracy position: $e. Retrying with low accuracy.");
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 5),
          ),
        );
      });

      state = AsyncValue.data(position);

      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        state = AsyncValue.data(position);
      });
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final currentLocationProvider = StateNotifierProvider<CurrentLocationNotifier, AsyncValue<Position>>((ref) {
  return CurrentLocationNotifier();
});

class NearbyDriver {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final String vehicleType;
  final double heading;

  NearbyDriver({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.vehicleType,
    required this.heading,
  });
}

class NearbyDriversNotifier extends StateNotifier<List<NearbyDriver>> {
  final Ref _ref;
  WebSocket? _webSocket;
  Timer? _reconnectTimer;
  double? _lastLat;
  double? _lastLng;

  NearbyDriversNotifier(this._ref) : super([]) {
    _ref.listen(currentLocationProvider, (prev, next) {
      final position = next.whenOrNull(data: (pos) => pos);
      if (position != null) {
        _lastLat = position.latitude;
        _lastLng = position.longitude;
        _sendSubscription();
      }
    });
    _connect();
  }

  void _connect() async {
    final token = await ApiClient().getToken();
    final profile = _ref.read(userProfileProvider);
    final rawRiderId = profile.phone.isNotEmpty ? profile.phone : 'rider-123';
    final riderId = Uri.encodeComponent(rawRiderId);
    final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
    final encodedToken = token != null ? Uri.encodeComponent(token) : null;
    final queryPath = encodedToken != null
        ? '/ride-tracking?riderId=$riderId&token=$encodedToken'
        : '/ride-tracking?riderId=$riderId';
    final urls = _getWebSocketUrls(queryPath);

    for (final wsUrl in urls) {
      try {
        debugPrint("Attempting NearbyDrivers connection to $wsUrl");
        _webSocket = await WebSocket.connect(wsUrl, headers: headers).timeout(const Duration(seconds: 2));
        debugPrint("✅ NearbyDrivers WebSocket connected successfully to $wsUrl");
        
        _webSocket!.listen(
          (message) {
            try {
              final data = jsonDecode(message as String);
              if (data['type'] == 'nearby_drivers') {
                final List<dynamic> driversList = data['drivers'] ?? [];
                state = driversList.map((d) => NearbyDriver(
                  id: d['id'] ?? '',
                  name: d['name'] ?? '',
                  lat: (d['lat'] as num).toDouble(),
                  lng: (d['lng'] as num).toDouble(),
                  vehicleType: d['vehicleType'] ?? 'bike',
                  heading: (d['heading'] as num? ?? 0.0).toDouble(),
                )).toList();
              }
            } catch (e) {
              debugPrint("NearbyDrivers parsing error: $e");
            }
          },
          onError: (err) => _handleDisconnect(),
          onDone: () => _handleDisconnect(),
        );

        final position = _ref.read(currentLocationProvider).whenOrNull(data: (pos) => pos);
        if (position != null) {
          _lastLat = position.latitude;
          _lastLng = position.longitude;
        }
        
        _sendSubscription();
        return; // Connection succeeded, exit loop
      } catch (e) {
        debugPrint("NearbyDrivers connection to $wsUrl failed: $e");
      }
    }

    // If all fail:
    _handleDisconnect();
  }

  void _sendSubscription() {
    final lat = _lastLat ?? 26.8467;
    final lng = _lastLng ?? 80.9462;
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      _webSocket!.add(jsonEncode({
        'type': 'subscribe_nearby',
        'latitude': lat,
        'longitude': lng,
      }));
    }
  }

  void _handleDisconnect() {
    _webSocket = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      _connect();
    });
  }

  @override
  void dispose() {
    _webSocket?.close();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

final nearbyDriversProvider = StateNotifierProvider<NearbyDriversNotifier, List<NearbyDriver>>((ref) {
  return NearbyDriversNotifier(ref);
});

List<String> _getWebSocketUrls(String pathAndQuery) {
  final baseApi = ApiClient().baseUrl;
  final urls = <String>[];

  try {
    final uri = Uri.parse(baseApi);
    if (uri.host.isNotEmpty) {
      final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portStr = uri.hasPort ? ':${uri.port}' : '';
      urls.add('$scheme://${uri.host}$portStr$pathAndQuery');
    }
  } catch (_) {}

  final fallbackHosts = [
    '222.167.207.239',
    if (!kIsWeb && Platform.isAndroid) '10.0.2.2',
    'localhost',
    '127.0.0.1',
  ];

  for (final host in fallbackHosts) {
    urls.add('ws://$host:8080$pathAndQuery');
  }

  return urls;
}


