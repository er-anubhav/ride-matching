import 'dart:async';
import 'dart:convert';
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
  
  final defaultLat = currentLoc.value?.latitude ?? 26.8500;
  final defaultLng = currentLoc.value?.longitude ?? 80.9400;

  final pLat = location.pickupLat ?? defaultLat;
  final pLng = location.pickupLng ?? defaultLng;
  final dLat = location.destLat ?? defaultLat;
  final dLng = location.destLng ?? defaultLng;

  if (pLat == dLat && pLng == dLng) {
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
          name: "Anubhav Tripathi",
          phone: "+91 98765 43210",
          rating: 4.9,
          avatarUrl: "https://images.unsplash.com/photo-1534528741775-53994a69daeb",
        ));

  void updateName(String name) {
    state = UserProfile(
      name: name,
      phone: state.phone,
      rating: state.rating,
      avatarUrl: state.avatarUrl,
    );
  }

  void updateAvatarUrl(String avatarUrl) {
    state = UserProfile(
      name: state.name,
      phone: state.phone,
      rating: state.rating,
      avatarUrl: avatarUrl,
    );
  }
}

final userProfileProvider = StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier();
});

final fareEstimateProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final location = ref.watch(locationProvider);
  final currentLoc = ref.watch(currentLocationProvider);

  final defaultLat = currentLoc.value?.latitude ?? 26.8500;
  final defaultLng = currentLoc.value?.longitude ?? 80.9400;

  final pLat = location.pickupLat ?? defaultLat;
  final pLng = location.pickupLng ?? defaultLng;
  final dLat = location.destLat ?? defaultLat;
  final dLng = location.destLng ?? defaultLng;

  if (pLat == dLat && pLng == dLng) {
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
  SearchHistoryNotifier() : super([]);

  void addHistory(String address, double lat, double lng) {
    if (address.isEmpty) return;
    state = [
      SearchHistoryItem(address: address, latitude: lat, longitude: lng, timestamp: DateTime.now()),
      ...state.where((item) => item.address != address)
    ].take(10).toList();
  }

  void clearHistory() {
    state = [];
  }

  void removeHistory(String address) {
    state = state.where((item) => item.address != address).toList();
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<SearchHistoryItem>>((ref) {
  return SearchHistoryNotifier();
});

class BookmarkItem {
  final String label;
  final String address;
  final double latitude;
  final double longitude;

  BookmarkItem({
    required this.label,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class BookmarksNotifier extends StateNotifier<List<BookmarkItem>> {
  BookmarksNotifier() : super([]);

  void addBookmark(String label, String address, double lat, double lng) {
    if (label.isEmpty || address.isEmpty) return;
    state = [
      ...state.where((item) => item.address != address),
      BookmarkItem(label: label, address: address, latitude: lat, longitude: lng)
    ];
  }

  void removeBookmark(String address) {
    state = state.where((item) => item.address != address).toList();
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
    final hosts = [
      if (!kIsWeb && Platform.isAndroid) '10.0.2.2',
      'localhost',
      '127.0.0.1',
    ];

    for (final host in hosts) {
      try {
        final token = await ApiClient().getToken();
        final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
        final wsUrl = 'ws://$host:8080/ride-tracking';
        debugPrint("Attempting Booking connection to $wsUrl");
        _webSocket = await WebSocket.connect(wsUrl, headers: headers).timeout(const Duration(seconds: 2));
        
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
        debugPrint("Booking connection to $host failed: $e");
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

    // Fetch arrival route polyline from Ola Maps Directions API
    List<List<double>> arrivalPolylinePoints = [];
    try {
      const apiKey = '6ZPQI6AaSeXkgvIhqIQaxyEfscr8oXvgRTEpwPYj';
      final directionsUrl = 'https://api.olamaps.io/routing/v1/directions?origin=$driverStartLat,$driverStartLng&destination=$pickupLat,$pickupLng&api_key=$apiKey';
      final response = await http.post(
        Uri.parse(directionsUrl),
        headers: {
          'X-Request-Id': 'mr-rideo-arrival-${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0];
          final overviewPolyline = firstRoute['overview_polyline'] as String?;
          if (overviewPolyline != null) {
            arrivalPolylinePoints = _decodePolyline(overviewPolyline);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching arrival polyline: $e");
    }

    // Animate driver toward pickup over 5 seconds (5 steps × 1s)
    const totalArrivalSteps = 5;
    _simStep = 0;
    _cancelSimTimer();

    _driverSimTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != RideBookingStatus.driverArriving || !mounted) {
        timer.cancel();
        return;
      }
      _simStep++;

      double newLat;
      double newLng;

      if (arrivalPolylinePoints.isNotEmpty) {
        final int index = (_simStep * (arrivalPolylinePoints.length - 1) / totalArrivalSteps).round();
        final clampedIndex = index.clamp(0, arrivalPolylinePoints.length - 1);
        newLat = arrivalPolylinePoints[clampedIndex][0];
        newLng = arrivalPolylinePoints[clampedIndex][1];
      } else {
        // Fallback to straight line
        newLat = driverStartLat + (((pickupLat - driverStartLat) / totalArrivalSteps) * _simStep);
        newLng = driverStartLng + (((pickupLng - driverStartLng) / totalArrivalSteps) * _simStep);
      }

      state = state.copyWith(
        driverLat: newLat,
        driverLng: newLng,
      );

      if (_simStep >= totalArrivalSteps) {
        timer.cancel();
        _driverSimTimer = null;
        // Driver has arrived at pickup — start ride
        Future.delayed(const Duration(milliseconds: 500), () {
          if (state.status == RideBookingStatus.driverArriving) {
            startRide();
          }
        });
      }
    });
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
    final pickupLat = location.pickupLat ?? 26.8500;
    final pickupLng = location.pickupLng ?? 80.9400;
    final destLat = location.destLat ?? 26.8600;
    final destLng = location.destLng ?? 80.9500;

    final metrics = _ref.read(routeMetricsProvider).value;
    List<List<double>> polylinePoints = [];
    if (metrics?.overviewPolyline != null) {
      try {
        polylinePoints = _decodePolyline(metrics!.overviewPolyline!);
      } catch (e) {
        debugPrint("Error decoding polyline in simulation: $e");
      }
    }

    state = state.copyWith(
      status: RideBookingStatus.inProgress,
      eta: state.tripDurationEta ?? "12 mins",
      driverLat: pickupLat,
      driverLng: pickupLng,
    );

    // Animate driver from pickup toward destination over 8 seconds
    const totalTripSteps = 8;
    _simStep = 0;

    _driverSimTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.status != RideBookingStatus.inProgress || !mounted) {
        timer.cancel();
        return;
      }
      _simStep++;

      double newLat;
      double newLng;

      if (polylinePoints.isNotEmpty) {
        // Map step to index in the polyline coordinates list
        final int index = (_simStep * (polylinePoints.length - 1) / totalTripSteps).round();
        // Clamp index to avoid index out of bounds
        final clampedIndex = index.clamp(0, polylinePoints.length - 1);
        newLat = polylinePoints[clampedIndex][0];
        newLng = polylinePoints[clampedIndex][1];
      } else {
        // Fallback to straight line
        newLat = pickupLat + (((destLat - pickupLat) / totalTripSteps) * _simStep);
        newLng = pickupLng + (((destLng - pickupLng) / totalTripSteps) * _simStep);
      }

      state = state.copyWith(
        driverLat: newLat,
        driverLng: newLng,
      );

      if (_simStep >= totalTripSteps) {
        timer.cancel();
        _driverSimTimer = null;
        completeRide();
      }
    });
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
  TripHistoryNotifier() : super([
    {
      "id": "TRP-837482",
      "date": "Today, 10:30 AM",
      "pickup": "HSR Layout Sector 3",
      "destination": "Kempegowda International Airport",
      "vehicle": "Prime Sedan",
      "vehicleIcon": LucideIcons.car,
      "price": 849.00,
      "status": "Completed",
      "driver": "Ramesh Kumar",
      "driverRating": 4.9,
      "duration": "45 mins",
      "distance": "38.2 km",
      "promo": "AIRPORT150",
      "promoDiscount": 150.00,
    },
    {
      "id": "TRP-836109",
      "date": "Yesterday, 6:15 PM",
      "pickup": "Indiranagar 100ft Road",
      "destination": "Nexus Mall Koramangala",
      "vehicle": "Mini",
      "vehicleIcon": LucideIcons.car,
      "price": 182.50,
      "status": "Completed",
      "driver": "Anil Singh",
      "driverRating": 4.8,
      "duration": "22 mins",
      "distance": "7.4 km",
      "promo": null,
      "promoDiscount": 0.00,
    },
    {
      "id": "TRP-832104",
      "date": "22 June, 8:45 AM",
      "pickup": "Whitefield ITPL Main Gate",
      "destination": "Phoenix Marketcity Mall",
      "vehicle": "Moto",
      "vehicleIcon": LucideIcons.bike,
      "price": 75.00,
      "status": "Completed",
      "driver": "Vijay Prasad",
      "driverRating": 4.7,
      "duration": "14 mins",
      "distance": "4.8 km",
      "promo": "MOTO50",
      "promoDiscount": 15.00,
    },
    {
      "id": "TRP-831102",
      "date": "20 June, 11:20 PM",
      "pickup": "MG Road Metro Station",
      "destination": "Indiranagar Metro Station",
      "vehicle": "Mini",
      "vehicleIcon": LucideIcons.car,
      "price": 0.00,
      "status": "Cancelled",
      "driver": "No driver assigned",
      "driverRating": 0.0,
      "duration": "0 mins",
      "distance": "0.0 km",
      "promo": null,
      "promoDiscount": 0.00,
    },
  ]);

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
          balance: 345.50,
          transactions: [
            "Ride to Tech Park - ₹145.00 deducted",
            "Added Money via UPI - ₹500.00 added",
            "Ride to Airport - ₹280.00 deducted",
          ],
        ));

  void addMoney(double amount) {
    state = WalletState(
      balance: state.balance + amount,
      transactions: [
        "Added Money via UPI - ₹${amount.toStringAsFixed(2)} added",
        ...state.transactions
      ],
    );
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
}

class SosContactsNotifier extends StateNotifier<List<SosContact>> {
  SosContactsNotifier()
      : super([
          SosContact(id: "1", name: "Papa (Primary)", phone: "+91 98765 98765"),
          SosContact(id: "2", name: "Riya (Sister)", phone: "+91 91234 56789"),
        ]);

  void addContact(String name, String phone) {
    state = [
      ...state,
      SosContact(id: DateTime.now().toString(), name: name, phone: phone),
    ];
  }

  void removeContact(String id) {
    state = state.where((c) => c.id != id).toList();
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
}

class PaymentMethodsNotifier extends StateNotifier<List<PaymentMethod>> {
  PaymentMethodsNotifier()
      : super([
          PaymentMethod(id: "1", type: "card", label: "HDFC Visa •••• 4820", isDefault: true),
          PaymentMethod(id: "2", type: "upi", label: "tripathi@okaxis", isDefault: false),
        ]);

  void addCard(String lastFour) {
    state = [
      ...state.map((e) => e.copyWith(isDefault: false)),
      PaymentMethod(id: DateTime.now().toString(), type: "card", label: "Card •••• $lastFour", isDefault: true),
    ];
  }

  void addUpi(String upiId) {
    state = [
      ...state.map((e) => e.copyWith(isDefault: false)),
      PaymentMethod(id: DateTime.now().toString(), type: "upi", label: upiId, isDefault: true),
    ];
  }

  void deleteMethod(String id) {
    final wasDefault = state.firstWhere((element) => element.id == id, orElse: () => state.first).isDefault;
    state = state.where((m) => m.id != id).toList();
    if (wasDefault && state.isNotEmpty) {
      state = [
        state.first.copyWith(isDefault: true),
        ...state.sublist(1),
      ];
    }
  }

  void setDefault(String id) {
    state = state.map((m) => m.copyWith(isDefault: m.id == id)).toList();
  }
}

final paymentMethodsProvider = StateNotifierProvider<PaymentMethodsNotifier, List<PaymentMethod>>((ref) {
  return PaymentMethodsNotifier();
});

// Support Tickets state models & providers
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
  SupportTicketsNotifier()
      : super([
          SupportTicket(
            id: "TCK-4820",
            category: "Refund Issue",
            message: "Double charged for ride TRP-831102 on Indiranagar Route.",
            date: "22 June, 04:30 PM",
            status: "Resolved",
          ),
        ]);

  void raiseTicket(String category, String message) {
    state = [
      SupportTicket(
        id: "TCK-${4821 + state.length}",
        category: category,
        message: message,
        date: "Just now",
        status: "Pending",
      ),
      ...state,
    ];
  }
}

final supportTicketsProvider = StateNotifierProvider<SupportTicketsNotifier, List<SupportTicket>>((ref) {
  return SupportTicketsNotifier();
});

class CurrentLocationNotifier extends StateNotifier<AsyncValue<Position>> {
  CurrentLocationNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

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
    final hosts = [
      if (!kIsWeb && Platform.isAndroid) '10.0.2.2',
      'localhost',
      '127.0.0.1',
    ];

    for (final host in hosts) {
      try {
        final wsUrl = 'ws://$host:8080/ride-tracking?riderId=rider-123';
        debugPrint("Attempting NearbyDrivers connection to $wsUrl");
        _webSocket = await WebSocket.connect(wsUrl).timeout(const Duration(seconds: 2));
        
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
        debugPrint("NearbyDrivers connection to $host failed: $e");
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


