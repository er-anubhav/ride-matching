import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared/shared.dart';

enum DriverDutyStatus {
  offline,
  online,
  incomingRequest,
  arrivingToPickup,
  arrivedAtPickup,
  tripInProgress,
  tripCompleted,
}

enum KycStatus {
  notStarted,
  detailsPending,
  docsPending,
  underReview,
  approved,
}

enum WebSocketStatus {
  disconnected,
  connecting,
  connected,
  connectionError,
}

class DriverState {
  final DriverDutyStatus dutyStatus;
  final KycStatus kycStatus;
  
  // KYC Info
  final String? vehicleMake;
  final String? vehicleModel;
  final String? vehicleNumber;
  final String? upiId;
  final double? rating;
  
  // Coordinates
  final double driverLat;
  final double driverLng;
  final double? startLat;
  final double? startLng;
  
  // Active Ride Info
  final String? activeTripId;
  final String? riderName;
  final String? riderPhone;
  final String? pickupAddress;
  final String? dropoffAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? price;
  final String? otp;
  final String? otpInputError;
  final int requestCountdown;
  
  // Earnings Ledger
  final double earnings;
  final int tripsCompletedCount;
  final List<Map<String, dynamic>> earningsHistory;

  // Polyline Points for Routing
  final List<List<double>> activeRoutePoints;
  final WebSocketStatus webSocketStatus;

  DriverState({
    required this.dutyStatus,
    required this.kycStatus,
    this.vehicleMake,
    this.vehicleModel,
    this.vehicleNumber,
    this.upiId,
    this.rating,
    required this.driverLat,
    required this.driverLng,
    this.startLat,
    this.startLng,
    this.activeTripId,
    this.riderName,
    this.riderPhone,
    this.pickupAddress,
    this.dropoffAddress,
    this.pickupLat,
    this.pickupLng,
    this.dropoffLat,
    this.dropoffLng,
    this.price,
    this.otp,
    this.otpInputError,
    this.requestCountdown = 15,
    required this.earnings,
    required this.tripsCompletedCount,
    required this.earningsHistory,
    required this.activeRoutePoints,
    this.webSocketStatus = WebSocketStatus.disconnected,
  });

  DriverState copyWith({
    DriverDutyStatus? dutyStatus,
    KycStatus? kycStatus,
    String? vehicleMake,
    String? vehicleModel,
    String? vehicleNumber,
    String? upiId,
    double? rating,
    double? driverLat,
    double? driverLng,
    double? startLat,
    double? startLng,
    String? activeTripId,
    String? riderName,
    String? riderPhone,
    String? pickupAddress,
    String? dropoffAddress,
    double? pickupLat,
    double? pickupLng,
    double? dropoffLat,
    double? dropoffLng,
    double? price,
    String? otp,
    String? otpInputError,
    int? requestCountdown,
    double? earnings,
    int? tripsCompletedCount,
    List<Map<String, dynamic>>? earningsHistory,
    List<List<double>>? activeRoutePoints,
    WebSocketStatus? webSocketStatus,
    bool clearRiderInfo = false,
    bool clearOtpError = false,
  }) {
    return DriverState(
      dutyStatus: dutyStatus ?? this.dutyStatus,
      kycStatus: kycStatus ?? this.kycStatus,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      upiId: upiId ?? this.upiId,
      rating: rating ?? this.rating,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      startLat: startLat ?? this.startLat,
      startLng: startLng ?? this.startLng,
      activeTripId: clearRiderInfo ? null : (activeTripId ?? this.activeTripId),
      riderName: clearRiderInfo ? null : (riderName ?? this.riderName),
      riderPhone: clearRiderInfo ? null : (riderPhone ?? this.riderPhone),
      pickupAddress: clearRiderInfo ? null : (pickupAddress ?? this.pickupAddress),
      dropoffAddress: clearRiderInfo ? null : (dropoffAddress ?? this.dropoffAddress),
      pickupLat: clearRiderInfo ? null : (pickupLat ?? this.pickupLat),
      pickupLng: clearRiderInfo ? null : (pickupLng ?? this.pickupLng),
      dropoffLat: clearRiderInfo ? null : (dropoffLat ?? this.dropoffLat),
      dropoffLng: clearRiderInfo ? null : (dropoffLng ?? this.dropoffLng),
      price: clearRiderInfo ? null : (price ?? this.price),
      otp: clearRiderInfo ? null : (otp ?? this.otp),
      otpInputError: clearOtpError ? null : (otpInputError ?? this.otpInputError),
      requestCountdown: requestCountdown ?? this.requestCountdown,
      earnings: earnings ?? this.earnings,
      tripsCompletedCount: tripsCompletedCount ?? this.tripsCompletedCount,
      earningsHistory: earningsHistory ?? this.earningsHistory,
      activeRoutePoints: activeRoutePoints ?? this.activeRoutePoints,
      webSocketStatus: webSocketStatus ?? this.webSocketStatus,
    );
  }
}

class DriverStateNotifier extends StateNotifier<DriverState> {
  Timer? _countdownTimer;
  Timer? _simulationTimer;
  WebSocket? _webSocket;
  StreamSubscription<Position>? _positionSubscription;
  int _simStep = 0;
  
  static const String apiKey = '6ZPQI6AaSeXkgvIhqIQaxyEfscr8oXvgRTEpwPYj';

  DriverStateNotifier()
      : super(DriverState(
          dutyStatus: DriverDutyStatus.offline,
          kycStatus: KycStatus.notStarted,
          driverLat: 0.0,
          driverLng: 0.0,
          earnings: 0.0,
          tripsCompletedCount: 0,
          earningsHistory: [],
          activeRoutePoints: [],
        )) {
    _initLocation();
    _fetchProfile();
  }

  void _initLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      // Get last known position first for quick initialization
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        if (_simulationTimer == null || !_simulationTimer!.isActive) {
          state = state.copyWith(driverLat: lastKnown.latitude, driverLng: lastKnown.longitude);
        }
      }

      // Fetch current position with a timeout to avoid hanging indefinitely
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

      if (_simulationTimer == null || !_simulationTimer!.isActive) {
        state = state.copyWith(driverLat: position.latitude, driverLng: position.longitude);
        if (state.dutyStatus == DriverDutyStatus.online) {
          sendLocationUpdate(position.latitude, position.longitude);
          WsService().updateDriverLocation(position.latitude, position.longitude);
        }
      }

      _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        if (_simulationTimer == null || !_simulationTimer!.isActive) {
          state = state.copyWith(driverLat: position.latitude, driverLng: position.longitude);
          if (state.dutyStatus == DriverDutyStatus.online) {
            sendLocationUpdate(position.latitude, position.longitude);
            WsService().updateDriverLocation(position.latitude, position.longitude);
          }
        }
      });
    } catch (e) {
      debugPrint("Error initializing geolocator in driver: $e");
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final response = await ApiClient().get('/driver/profile');
      if (response != null && response['status'] == 'success' && response['profile'] != null) {
        final profile = response['profile'];
        state = state.copyWith(
          vehicleMake: profile['vehicleMake'] as String?,
          vehicleModel: profile['vehicleModel'] as String?,
          vehicleNumber: profile['vehicleNumber'] as String?,
          upiId: profile['upiId'] as String?,
          rating: (profile['rating'] as num?)?.toDouble(),
        );
      }
    } catch (e) {
      debugPrint("Error fetching driver profile: $e");
    }
  }

  void setVehicleDetails(String make, String model, String number) {
    state = state.copyWith(
      vehicleMake: make,
      vehicleModel: model,
      vehicleNumber: number,
      kycStatus: KycStatus.docsPending,
    );
    ApiClient().put('/driver/profile', {
      'vehicleMake': make,
      'vehicleModel': model,
      'vehicleNumber': number,
    }).catchError((_) {});
  }

  Future<void> submitKycDocuments() async {
    state = state.copyWith(
      kycStatus: KycStatus.underReview,
    );
    try {
      await ApiClient().post('/driver/kyc/documents', {
        'vehicleMake': state.vehicleMake,
        'vehicleModel': state.vehicleModel,
        'vehicleNumber': state.vehicleNumber,
      });
    } catch (_) {}
  }

  void approveKyc() {
    state = state.copyWith(
      kycStatus: KycStatus.approved,
    );
  }

  void updateUpiId(String upi) {
    state = state.copyWith(upiId: upi);
    ApiClient().put('/driver/profile', {'upiId': upi}).catchError((_) {});
  }

  void toggleDutyStatus() {
    if (state.dutyStatus == DriverDutyStatus.offline) {
      state = state.copyWith(
        dutyStatus: DriverDutyStatus.online,
        webSocketStatus: WebSocketStatus.connecting,
      );
      _connectWebSocket();
      _initLocation();
    } else {
      _cancelSimulation();
      _cancelCountdown();
      _closeWebSocket();
      state = state.copyWith(
        dutyStatus: DriverDutyStatus.offline,
        webSocketStatus: WebSocketStatus.disconnected,
      );
    }
  }

  Future<void> _connectWebSocket() async {
    try {
      final baseApi = ApiClient().baseUrl;
      String wsUrl = 'ws://222.167.207.239:8080/ride-tracking';
      try {
        final uri = Uri.parse(baseApi);
        if (uri.host.isNotEmpty) {
          final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
          final portStr = uri.hasPort ? ':${uri.port}' : '';
          wsUrl = '$scheme://${uri.host}$portStr/ride-tracking';
        }
      } catch (_) {}
      final token = await ApiClient().getToken();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : null;
      _webSocket = await WebSocket.connect(wsUrl, headers: headers).timeout(const Duration(seconds: 4));
      
      if (!mounted) return;
      state = state.copyWith(webSocketStatus: WebSocketStatus.connected);

      // Listen for commands
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
        onError: (err) {
          debugPrint("WebSocket error: $err");
          _handleWebSocketDisconnect();
        },
        onDone: () {
          debugPrint("WebSocket closed");
          _handleWebSocketDisconnect();
        },
      );

      // Register driver with WebSocket
      final vehicleName = [state.vehicleMake, state.vehicleModel].where((s) => s != null && s.isNotEmpty).join(' ');
      final regMsg = jsonEncode({
        'type': 'register_driver',
        'driverLat': state.driverLat,
        'driverLng': state.driverLng,
        'vehicleNumber': state.vehicleNumber ?? '',
        'vehicleName': vehicleName,
      });
      _webSocket!.add(regMsg);

    } catch (e) {
      debugPrint("WebSocket connect failed: $e");
      _handleWebSocketDisconnect();
    }
  }

  void _handleWebSocketDisconnect() {
    if (!mounted) return;
    _cancelSimulation();
    _cancelCountdown();
    _closeWebSocket();
    state = state.copyWith(
      dutyStatus: DriverDutyStatus.offline,
      webSocketStatus: WebSocketStatus.disconnected,
    );
  }

  void _closeWebSocket() {
    _webSocket?.close();
    _webSocket = null;
  }

  void _handleWebSocketMessage(Map<String, dynamic> data) {
    if (data['type'] == 'incoming_dispatch') {
      receiveIncomingRequest(
        tripId: data['tripId'] as String?,
        riderName: data['riderName'] as String? ?? "Passenger",
        riderPhone: data['riderPhone'] as String? ?? "",
        pickupAddress: data['pickupAddress'] as String? ?? "Pickup Point",
        dropoffAddress: data['dropoffAddress'] as String? ?? "Dropoff Location",
        pickupLat: (data['pickupLat'] as num?)?.toDouble() ?? state.driverLat,
        pickupLng: (data['pickupLng'] as num?)?.toDouble() ?? state.driverLng,
        dropoffLat: (data['dropoffLat'] as num?)?.toDouble() ?? state.driverLat,
        dropoffLng: (data['dropoffLng'] as num?)?.toDouble() ?? state.driverLng,
        price: (data['price'] as num?)?.toDouble() ?? 0.0,
        otp: data['otp'] as String? ?? "",
      );
    }
  }

  void sendLocationUpdate(double lat, double lng) {
    if (_webSocket != null && state.webSocketStatus == WebSocketStatus.connected) {
      final updateMsg = jsonEncode({
        'type': 'driver_location_update',
        'latitude': lat,
        'longitude': lng,
      });
      _webSocket!.add(updateMsg);
    }
  }

  void receiveIncomingRequest({
    String? tripId,
    required String riderName,
    required String riderPhone,
    required String pickupAddress,
    required String dropoffAddress,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required double price,
    required String otp,
  }) {
    _cancelCountdown();
    state = state.copyWith(
      dutyStatus: DriverDutyStatus.incomingRequest,
      activeTripId: tripId,
      riderName: riderName,
      riderPhone: riderPhone,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
      price: price,
      otp: otp,
      requestCountdown: 15,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.requestCountdown <= 1) {
        declineRide();
      } else {
        state = state.copyWith(requestCountdown: state.requestCountdown - 1);
      }
    });
  }

  void declineRide() {
    _cancelCountdown();
    
    // Notify backend of rejection
    if (state.activeTripId != null) {
      ApiClient().post('/trips/${state.activeTripId}/reject', {}).catchError((e) {
        debugPrint("Failed to reject trip on backend: $e");
      });
    }

    state = state.copyWith(
      dutyStatus: DriverDutyStatus.online,
      clearRiderInfo: true,
      activeRoutePoints: [],
    );
  }

  Future<void> acceptRide() async {
    _cancelCountdown();
    
    if (state.activeTripId != null) {
      try {
        await ApiClient().post('/trips/${state.activeTripId}/accept', {});
      } catch (e) {
        debugPrint("Failed to accept trip on backend: $e");
      }
    }

    state = state.copyWith(
      dutyStatus: DriverDutyStatus.arrivingToPickup,
      startLat: state.driverLat,
      startLng: state.driverLng,
    );

    // Fetch navigation coordinates to pickup
    List<List<double>> polyPoints = [];
    try {
      final directionsUrl = 'https://api.olamaps.io/routing/v1/directions?origin=${state.driverLat},${state.driverLng}&destination=${state.pickupLat},${state.pickupLng}&api_key=$apiKey';
      final response = await http.post(
        Uri.parse(directionsUrl),
        headers: {
          'X-Request-Id': 'mr-rideo-driver-arrival-${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0];
          final overviewPolyline = firstRoute['overview_polyline'] as String?;
          if (overviewPolyline != null) {
            polyPoints = _decodePolyline(overviewPolyline);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching driver arrival polyline: $e");
    }

    state = state.copyWith(activeRoutePoints: polyPoints);
  }

  void arrivedAtPickup() {
    _cancelSimulation();
    
    // Notify backend
    if (state.activeTripId != null) {
      ApiClient().post('/trips/${state.activeTripId}/arrive', {}).catchError((e) {
        debugPrint("Failed to notify arrival on backend: $e");
      });
    }

    state = state.copyWith(dutyStatus: DriverDutyStatus.arrivedAtPickup);
  }

  void arriveAtPickup() {
    arrivedAtPickup();
  }

  void simulateMovementToTarget() {
    if (_simulationTimer != null) return;
    _simStep++;
    final polyPoints = state.activeRoutePoints;
    if (polyPoints.isNotEmpty) {
      final int index = (_simStep * (polyPoints.length - 1) / 5).round();
      final clampedIndex = index.clamp(0, polyPoints.length - 1);
      final newLat = polyPoints[clampedIndex][0];
      final newLng = polyPoints[clampedIndex][1];
      state = state.copyWith(driverLat: newLat, driverLng: newLng);
      sendLocationUpdate(newLat, newLng);
    } else {
      // Fallback
      final double targetLat = state.dutyStatus == DriverDutyStatus.arrivingToPickup
          ? (state.pickupLat ?? state.driverLat)
          : (state.dropoffLat ?? state.driverLat);
      final double targetLng = state.dutyStatus == DriverDutyStatus.arrivingToPickup
          ? (state.pickupLng ?? state.driverLng)
          : (state.dropoffLng ?? state.driverLng);
      final startLat = state.startLat ?? state.driverLat;
      final startLng = state.startLng ?? state.driverLng;
      final newLat = startLat + (((targetLat - startLat) / 5) * _simStep.clamp(0, 5));
      final newLng = startLng + (((targetLng - startLng) / 5) * _simStep.clamp(0, 5));
      state = state.copyWith(driverLat: newLat, driverLng: newLng);
      sendLocationUpdate(newLat, newLng);
    }
  }

  Future<bool> startTrip(String inputOtp) async {
    // Verify OTP with backend
    if (state.activeTripId != null) {
      try {
        final response = await ApiClient().post('/trips/${state.activeTripId}/start', {
          'otp': inputOtp,
        });
        if (response == null || response['status'] != 'success') {
          state = state.copyWith(otpInputError: "Wrong OTP. Please try again.");
          return false;
        }
      } catch (e) {
        final errMsg = e.toString();
        // Check if it's a 400/401 error from backend (wrong OTP)
        if (errMsg.contains('400') || errMsg.contains('401') || errMsg.contains('Invalid OTP') || errMsg.contains('wrong')) {
          state = state.copyWith(otpInputError: "Wrong OTP. Please check with the passenger.");
        } else {
          // Network or server error — fall back to local OTP check for demo resilience
          debugPrint("Backend startTrip error: $e. Falling back to local OTP check.");
          if (inputOtp != state.otp) {
            state = state.copyWith(otpInputError: "Incorrect OTP. Please try again.");
            return false;
          }
        }
        return false;
      }
    } else {
      // Fallback local OTP check for demo mode
      if (inputOtp != state.otp) {
        state = state.copyWith(otpInputError: "Incorrect OTP. Please try again.");
        return false;
      }
    }

    state = state.copyWith(
      dutyStatus: DriverDutyStatus.tripInProgress,
      clearOtpError: true,
      startLat: state.driverLat,
      startLng: state.driverLng,
    );

    // Fetch routing guidance from pickup to dropoff
    List<List<double>> polyPoints = [];
    try {
      final directionsUrl = 'https://api.olamaps.io/routing/v1/directions?origin=${state.driverLat},${state.driverLng}&destination=${state.dropoffLat},${state.dropoffLng}&api_key=$apiKey';
      final response = await http.post(
        Uri.parse(directionsUrl),
        headers: {
          'X-Request-Id': 'mr-rideo-driver-trip-${DateTime.now().millisecondsSinceEpoch}',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
          final firstRoute = data['routes'][0];
          final overviewPolyline = firstRoute['overview_polyline'] as String?;
          if (overviewPolyline != null) {
            polyPoints = _decodePolyline(overviewPolyline);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching driver trip polyline: $e");
    }

    state = state.copyWith(activeRoutePoints: polyPoints);
    return true;
  }

  void endTrip() {
    _cancelSimulation();
    
    // Notify backend
    if (state.activeTripId != null) {
      ApiClient().post('/trips/${state.activeTripId}/complete', {}).catchError((e) {
        debugPrint("Failed to complete trip on backend: $e");
      });
    }

    final double netEarnings = state.price != null ? (state.price! * 0.82) : 0.0;
    final Map<String, dynamic> tripRecord = {
      'id': state.activeTripId ?? 'TRIP-${DateTime.now().millisecondsSinceEpoch}',
      'date': DateTime.now().toIso8601String(),
      'pickup': state.pickupAddress ?? "Hazratganj",
      'dropoff': state.dropoffAddress ?? "Lucknow Airport",
      'fare': state.price ?? 0.0,
      'earnings': netEarnings,
    };

    state = state.copyWith(
      dutyStatus: DriverDutyStatus.tripCompleted,
      earnings: state.earnings + netEarnings,
      tripsCompletedCount: state.tripsCompletedCount + 1,
      earningsHistory: [tripRecord, ...state.earningsHistory],
    );
  }

  void completePaymentFlow() {
    state = state.copyWith(
      dutyStatus: DriverDutyStatus.online,
      clearRiderInfo: true,
      activeRoutePoints: [],
    );
  }

  void resetToOnline() {
    completePaymentFlow();
  }


  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _cancelSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
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

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _cancelCountdown();
    _cancelSimulation();
    _closeWebSocket();
    super.dispose();
  }
}

final driverStateProvider =
    StateNotifierProvider<DriverStateNotifier, DriverState>((ref) {
  return DriverStateNotifier();
});
