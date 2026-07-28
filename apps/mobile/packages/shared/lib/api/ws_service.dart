import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_client.dart';

class WsService {
  static final WsService _instance = WsService._internal();
  factory WsService() => _instance;
  WsService._internal();

  WebSocketChannel? _channel;
  StreamController<Map<String, dynamic>>? _eventController;
  Timer? _pingTimer;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  Stream<Map<String, dynamic>> get eventStream {
    _eventController ??= StreamController<Map<String, dynamic>>.broadcast();
    return _eventController!.stream;
  }

  String get wsUrl {
    const envWsUrl = String.fromEnvironment('WS_URL');
    if (envWsUrl.isNotEmpty) {
      return envWsUrl;
    }
    final baseApi = ApiClient().baseUrl;
    try {
      final uri = Uri.parse(baseApi);
      if (uri.host.isNotEmpty) {
        final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
        final portStr = uri.hasPort ? ':${uri.port}' : '';
        return '$scheme://${uri.host}$portStr/ws';
      }
    } catch (_) {}
    return 'ws://127.0.0.1:8080/ws';
  }

  Future<void> connect() async {
    if (_isConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    try {
      final uri = Uri.parse('$wsUrl${token != null ? '?token=$token' : ''}');
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _eventController?.add(message);
          } catch (e) {
            debugPrint('Failed to decode WS message: $e');
          }
        },
        onError: (error) {
          debugPrint('WS error: $error');
          disconnect();
        },
        onDone: () {
          debugPrint('WS connection closed');
          disconnect();
        },
      );

      _startPingTimer();
    } catch (e) {
      debugPrint('WS Connection failed: $e');
      _isConnected = false;
    }
  }

  void send(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void updateDriverLocation(double lat, double lng, {double? heading}) {
    send({
      'type': 'LOCATION_UPDATE',
      'lat': lat,
      'lng': lng,
      if (heading != null) 'heading': heading,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected) {
        send({'type': 'PING'});
      }
    });
  }

  void disconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
