import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  String get baseUrl {
    const envApiUrl = String.fromEnvironment('API_URL');
    if (envApiUrl.isNotEmpty) {
      return envApiUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080/api';
    }
    // Android emulator uses 10.0.2.2 to access host localhost
    return Platform.isAndroid ? 'http://10.0.2.2:8080/api' : 'http://localhost:8080/api';
  }


  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String endpoint) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      final response = await http.get(uri, headers: headers);
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        uri,
        headers: headers,
        body: jsonEncode(body),
      );
      return _processResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      // Token expired or invalid
      clearToken();
      throw Exception('Unauthorized');
    }
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null;
    } else {
      dynamic errorBody;
      try {
        errorBody = jsonDecode(response.body);
      } catch (_) {
        errorBody = response.body;
      }
      throw Exception('Request failed (${response.statusCode}): $errorBody');
    }
  }
}
