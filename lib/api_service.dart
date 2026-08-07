import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification.dart'; // for navigatorKey
import 'home.dart'; // for HomeScreen

class ApiService {
  // Live server: 'https://mydomain.com/api'
  static const String baseUrl = 'http://192.168.1.2:8000/api';

  // ── Token helpers ─────────────────────────────────────────────────

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('user');
    if (userStr == null) return null;
    return jsonDecode(userStr);
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user');
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Called whenever the server says a session is no longer valid
  /// (401 on an authenticated endpoint) — most commonly because an
  /// admin rejected/removed the account, revoking its tokens. Clears
  /// the local session and bounces the person straight to guest mode,
  /// no matter which screen they're currently on.
  static Future<void> _forceGuestMode() async {
    await clearSession();
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    Navigator.of(ctx).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen(isGuest: true)),
      (route) => false,
    );
  }

  // ── Headers ───────────────────────────────────────────────────────

  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static const Map<String, String> _baseHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── AUTH ──────────────────────────────────────────────────────────

  static Future<ApiResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: _baseHeaders,
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveToken(data['token']);
        await saveUser(data['citizen']);
        return ApiResponse.success(data);
      }

      if (response.statusCode == 403 && data['needs_verification'] == true) {
        return ApiResponse.error(
          data['message'] ?? 'Please verify your email first.',
          data: {'email': data['email']},
        );
      }

      return ApiResponse.error(data['message'] ?? 'Invalid email or password.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> register({
    required String firstName,
    String? middleName,
    required String lastName,
    String? suffix,
    required String mobile,
    required String municipality,
    required String barangay,
    required String street,
    required String zone,
    required String email,
    required String password,
    File? validId,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/register');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.fields['first_name'] = firstName;
      if (middleName != null && middleName.isNotEmpty) {
        request.fields['middle_name'] = middleName;
      }
      request.fields['last_name'] = lastName;
      if (suffix != null && suffix.isNotEmpty) {
        request.fields['suffix'] = suffix;
      }
      request.fields['mobile'] = mobile;
      request.fields['municipality'] = municipality;
      request.fields['barangay'] = barangay;
      request.fields['street'] = street;
      request.fields['zone'] = zone;
      request.fields['email'] = email;
      request.fields['password'] = password;

      if (validId != null) {
        request.files.add(
          await http.MultipartFile.fromPath('valid_id', validId.path),
        );
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // No token yet — citizen must verify their email first.
        return ApiResponse.success(data);
      } else {
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          final firstError = errors.values.first;
          final msg = firstError is List ? firstError.first : firstError;
          return ApiResponse.error(msg.toString());
        }
        return ApiResponse.error(data['message'] ?? 'Registration failed.');
      }
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> forgotPassword({required String email}) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: _baseHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['message'] ?? 'Something went wrong.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> verifyEmail({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-email'),
            headers: _baseHeaders,
            body: jsonEncode({'email': email, 'otp': otp}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveToken(data['token']);
        await saveUser(data['citizen']);
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['message'] ?? 'Invalid or expired code.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> resendVerificationOtp({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/resend-verification-otp'),
            headers: _baseHeaders,
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) return ApiResponse.success(data);
      return ApiResponse.error(data['message'] ?? 'Could not resend code.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> resetPassword({
    required String email,
    required String otp,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-password'),
            headers: _baseHeaders,
            body: jsonEncode({
              'email': email,
              'otp': otp,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      return ApiResponse.error(data['message'] ?? 'Invalid or expired code.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// Validates the locally-stored token against the server.
  static Future<ApiResponse> getMe() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/me'), headers: headers)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveUser(data);
        return ApiResponse.success(data);
      } else {
        // 401 specifically means the token itself was rejected server-side
        // (e.g. the account was rejected/removed by an admin, revoking all
        // its tokens) — not just a generic failure. Bounce to guest mode.
        if (response.statusCode == 401) {
          await _forceGuestMode();
        } else {
          await clearSession();
        }
        return ApiResponse.error('Session expired. Please log in again.');
      }
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> getAlerts() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/alerts'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return ApiResponse.success(jsonDecode(response.body));
      }
      if (response.statusCode == 401) await _forceGuestMode();
      return ApiResponse.error('Could not load alerts.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<void> updateFcmToken(String fcmToken) async {
    try {
      final headers = await _authHeaders();
      await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      );
    } catch (_) {
      // Non-critical — fail silently
    }
  }

  // ── EVACUATION CENTERS ────────────────────────────────────────────
  // Public endpoint — no auth headers needed, guests can browse these too.

  static Future<ApiResponse> getEvacuationCenters() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/evacuation-centers'), headers: _baseHeaders)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return ApiResponse.success(jsonDecode(response.body));
      }
      return ApiResponse.error('Could not load evacuation centers.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  // ── INCIDENTS ─────────────────────────────────────────────────────

  static Future<ApiResponse> submitIncident({
    required String emergencyType,
    required String location,
    required String description,
    required List<File> photos,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/incidents');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['emergency_type'] = emergencyType;
      request.fields['location'] = location;
      request.fields['description'] = description;
      if (latitude != null) request.fields['latitude'] = latitude.toString();
      if (longitude != null) {
        request.fields['longitude'] = longitude.toString();
      }

      for (final photo in photos) {
        request.files.add(
          await http.MultipartFile.fromPath('photos[]', photo.path),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return ApiResponse.success(data);
      }
      if (response.statusCode == 401) await _forceGuestMode();
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        final first = errors.values.first;
        final msg = first is List ? first.first : first;
        return ApiResponse.error(msg.toString());
      }
      return ApiResponse.error(data['message'] ?? 'Failed to submit report.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  static Future<ApiResponse> getMyIncidents() async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .get(Uri.parse('$baseUrl/incidents/mine'), headers: headers)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return ApiResponse.success(jsonDecode(response.body));
      }
      if (response.statusCode == 401) await _forceGuestMode();
      return ApiResponse.error('Could not load reports.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// SOS panic button — sends GPS coordinates and an optional photo.
  /// Deliberately lightweight (single photo, no min-count) since this
  /// needs to fire within the 3-second hold window.
  static Future<ApiResponse> sendSOS({
    required double latitude,
    required double longitude,
    File? photo,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/incidents/sos');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      final streamed = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamed);
      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return ApiResponse.success(data);
      }
      if (response.statusCode == 401) await _forceGuestMode();
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        final first = errors.values.first;
        final msg = first is List ? first.first : first;
        return ApiResponse.error(msg.toString());
      }
      return ApiResponse.error(data['message'] ?? 'Failed to send SOS.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  // ── LOGOUT ────────────────────────────────────────────────────────

  static Future<ApiResponse> logout() async {
    try {
      final headers = await _authHeaders();
      await http
          .post(Uri.parse('$baseUrl/logout'), headers: headers)
          .timeout(const Duration(seconds: 10));
      await clearSession();
      return ApiResponse.success({});
    } catch (e) {
      await clearSession();
      return ApiResponse.success({});
    }
  }

  // ── Error handler ─────────────────────────────────────────────────

  static String _handleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('Connection refused')) {
      return 'Cannot connect to server. Check your internet or server URL.';
    }
    if (msg.contains('TimeoutException')) {
      return 'Connection timed out. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ── API Response wrapper ──────────────────────────────────────────────────────

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;

  ApiResponse._({required this.success, this.data, this.error});

  factory ApiResponse.success(dynamic data) =>
      ApiResponse._(success: true, data: data);

  factory ApiResponse.error(String message, {dynamic data}) =>
      ApiResponse._(success: false, error: message, data: data);
}
