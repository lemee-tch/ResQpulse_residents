import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'push_notification.dart'; // navigatorKey, unregisterFcmToken()
import 'home.dart'; // for HomeScreen

class ApiService {
  // Live server: 'https://mydomain.com/api'
  static const String baseUrl = 'https://resqpulse.com/api';

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

  // ── Guest details ─────────────────────────────────────────────────
  // Guests must give their first name, last name and mobile number before
  // an SOS (the server rejects a guest SOS without them). Kept on this
  // phone so a guest only types them once — logging in or out doesn't
  // clear them.

  /// {'first_name', 'last_name', 'mobile'} as last saved ('' for any that
  /// is missing), or null if nothing was saved yet.
  static Future<Map<String, String>?> getGuestDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final first = prefs.getString('guest_first_name') ?? '';
    final last = prefs.getString('guest_last_name') ?? '';
    final mobile = prefs.getString('guest_mobile') ?? '';
    if (first.isEmpty && last.isEmpty && mobile.isEmpty) return null;
    return {'first_name': first, 'last_name': last, 'mobile': mobile};
  }

  static Future<void> saveGuestDetails({
    required String firstName,
    required String lastName,
    required String mobile,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('guest_first_name', firstName);
    await prefs.setString('guest_last_name', lastName);
    await prefs.setString('guest_mobile', mobile);
    await prefs.remove('guest_name'); // saved by an earlier version
  }

  /// Called whenever the server says a session is no longer valid
  /// (401 on an authenticated endpoint) — most commonly because an
  /// admin rejected/removed the account, revoking its tokens. Clears
  /// the local session and bounces the person straight to guest mode,
  /// no matter which screen they're currently on.
  static Future<void> _forceGuestMode() async {
    await clearSession();
    // This phone stops getting the removed account's notifications.
    unawaited(unregisterFcmToken());
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

  /// Logs in with the email OR the mobile number ([login]) — residents who
  /// signed up with a mobile number have no email.
  static Future<ApiResponse> login({
    required String login,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/login'),
            headers: _baseHeaders,
            body: jsonEncode({
              'login': login,
              // Older servers only read "email".
              if (login.contains('@')) 'email': login,
              'password': password,
            }),
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
          data['message'] ?? 'Please verify your account first.',
          data: {
            'email': data['email'],
            'mobile': data['mobile'],
            // 'sms' for an account that logs in with its mobile number.
            'verify_via': data['verify_via'] ?? 'email',
          },
        );
      }

      return ApiResponse.error(
        data['message'] ?? 'Invalid email, mobile number or password.',
      );
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
    // Null for a mobile-number account (verifyVia 'sms'): it has no email
    // and logs in with the mobile number.
    String? email,
    required String password,
    File? validId,
    // Where the 6-digit code is sent: 'email' or 'sms' (mobile number).
    String verifyVia = 'email',
    // The email / mobile number and password the last "Send Code" used.
    // Sent when the resident changes their details after the code was
    // sent, so the server replaces that unfinished sign-up instead of
    // saying the email or mobile number is already taken.
    String? previousEmail,
    String? previousMobile,
    String? previousPassword,
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
      if (email != null && email.isNotEmpty) {
        request.fields['email'] = email;
      }
      request.fields['password'] = password;
      request.fields['verify_via'] = verifyVia;
      if (previousEmail != null && previousEmail.isNotEmpty) {
        request.fields['previous_email'] = previousEmail;
      }
      if (previousMobile != null && previousMobile.isNotEmpty) {
        request.fields['previous_mobile'] = previousMobile;
      }
      if (previousPassword != null && previousPassword.isNotEmpty) {
        request.fields['previous_password'] = previousPassword;
      }

      if (validId != null) {
        request.files.add(
          await http.MultipartFile.fromPath('valid_id', validId.path),
        );
      }

      // Longer than a normal call: the ID photo is uploaded on mobile data.
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
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

  /// Sends a 6-digit password-reset code (POST /forgot-password).
  ///
  /// [via] 'email' (default) emails it to [email]. 'sms' texts it to
  /// [mobile] — for accounts that log in with their mobile number
  /// (Api\AuthController::forgotPassword); the server answers the same
  /// whether or not the number has such an account. The code is then
  /// entered with [resetPassword], with the same email or number.
  static Future<ApiResponse> forgotPassword({
    String? email,
    String? mobile,
    String via = 'email',
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/forgot-password'),
            headers: _baseHeaders,
            body: jsonEncode({
              if (via != 'sms') 'email': email ?? '',
              if (via == 'sms') 'via': 'sms',
              if (via == 'sms') 'mobile': mobile ?? '',
            }),
          )
          // Longer than a normal call: the server may be sending a text.
          .timeout(const Duration(seconds: 20));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ApiResponse.success(data);
      }
      if (data is Map &&
          data['errors'] is Map &&
          (data['errors'] as Map).isNotEmpty) {
        final first = (data['errors'] as Map).values.first;
        final msg = first is List && first.isNotEmpty ? first.first : first;
        return ApiResponse.error(msg.toString());
      }
      return ApiResponse.error(data['message'] ?? 'Something went wrong.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// Checks the sign-up code. The account is named by its [email], or by
  /// its [mobile] number for an account that has no email.
  static Future<ApiResponse> verifyEmail({
    String? email,
    String? mobile,
    required String otp,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/verify-email'),
            headers: _baseHeaders,
            body: jsonEncode({
              if (email != null && email.isNotEmpty) 'email': email,
              if ((email == null || email.isEmpty) && mobile != null)
                'mobile': mobile,
              'otp': otp,
            }),
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

  /// Sends a new sign-up code — to the [email], or by text to the [mobile]
  /// number for an account that has no email.
  static Future<ApiResponse> resendVerificationOtp({
    String? email,
    String? mobile,
    // 'email' or 'sms' — where the new code goes (email accounts).
    String? verifyVia,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/resend-verification-otp'),
            headers: _baseHeaders,
            body: jsonEncode({
              if (email != null && email.isNotEmpty) 'email': email,
              if ((email == null || email.isEmpty) && mobile != null)
                'mobile': mobile,
              if (verifyVia != null) 'verify_via': verifyVia,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) return ApiResponse.success(data);
      return ApiResponse.error(data['message'] ?? 'Could not resend code.');
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// Whether the server can send verification codes by SMS. The Create
  /// Account screen disables the "Mobile Number" choice until this is true.
  /// Never fails — any error just means "email only".
  static Future<bool> isSmsVerificationAvailable() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/verification-options'),
            headers: _baseHeaders,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      return data is Map && data['sms'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Sets the new password with the reset code. The account is named by
  /// its [email], or by its [mobile] number when the code was texted.
  static Future<ApiResponse> resetPassword({
    String? email,
    String? mobile,
    required String otp,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/reset-password'),
            headers: _baseHeaders,
            body: jsonEncode({
              if (email != null && email.isNotEmpty) 'email': email,
              if ((email == null || email.isEmpty) && mobile != null)
                'mobile': mobile,
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

  /// Checks the saved login with the server and refreshes the saved
  /// profile.
  ///
  /// Only a rejected login (401 — e.g. an admin rejected or removed the
  /// account, which revokes its tokens) logs the resident out. A server
  /// error (500, maintenance) or no internet keeps them logged in, and the
  /// reply's statusCode says which it was (null = the server couldn't be
  /// reached). Before, any failed check cleared the login, so a moment of
  /// server trouble logged every resident out.
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
      }
      if (response.statusCode == 401) {
        // The token itself was rejected server-side — bounce to guest mode.
        await _forceGuestMode();
        return ApiResponse.error(
          'Session expired. Please log in again.',
          statusCode: 401,
        );
      }
      return ApiResponse.error(
        'Could not check your account right now. Please try again later.',
        statusCode: response.statusCode,
      );
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// Edit Profile screen — updates name, mobile and address fields for
  /// the logged-in citizen. Email and password are deliberately not
  /// editable here (see AuthController::updateProfile's doc comment).
  /// Saves the fresh citizen record locally on success so every screen
  /// reading getUser() immediately reflects the change, no extra
  /// getMe() round-trip needed.
  static Future<ApiResponse> updateProfile({
    required String firstName,
    String? middleName,
    required String lastName,
    String? suffix,
    required String mobile,
    required String barangay,
    String? street,
    String? zone,
  }) async {
    try {
      final headers = await _authHeaders();
      final response = await http
          .patch(
            Uri.parse('$baseUrl/profile'),
            headers: headers,
            body: jsonEncode({
              'first_name': firstName,
              'middle_name': middleName,
              'last_name': lastName,
              'suffix': suffix,
              'mobile': mobile,
              'barangay': barangay,
              'street': street,
              'zone': zone,
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        await saveUser(data['citizen']);
        return ApiResponse.success(data);
      }
      if (response.statusCode == 401) await _forceGuestMode();
      if (data['errors'] != null) {
        final errors = data['errors'] as Map<String, dynamic>;
        final firstError = errors.values.first;
        final msg = firstError is List ? firstError.first : firstError;
        return ApiResponse.error(msg.toString());
      }
      return ApiResponse.error(data['message'] ?? 'Could not update profile.');
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
      final response = await http.post(
        Uri.parse('$baseUrl/fcm-token'),
        headers: headers,
        body: jsonEncode({'fcm_token': fcmToken}),
      );
      debugPrint(
        'FCM token update -> status: ${response.statusCode}, body: ${response.body}',
      );
    } catch (e) {
      debugPrint('FCM token update FAILED: $e');
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

      // Longer than a normal call: up to 5 photos are uploaded on mobile
      // data (they're shrunk first — see report_incident.dart).
      final streamed = await request.send().timeout(
        const Duration(seconds: 60),
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
  ///
  /// [emergencyType] is what the citizen picked on the SOS screen's new
  /// "Type of Emergency" dropdown before holding the button (Fire,
  /// Flood, Accident, etc., or their own text for "Other"). It's
  /// optional so the button still works if it's ever null (shouldn't
  /// happen from the current sos.dart, but keeps this call resilient).
  ///
  /// [guestName] / [guestMobile] are required by the server when there is
  /// no login (guest mode) — see Api\IncidentController::sos().
  static Future<ApiResponse> sendSOS({
    required double latitude,
    required double longitude,
    File? photo,
    String? emergencyType,
    String? guestName,
    String? guestMobile,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl/incidents/sos');
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      final token = await getToken();
      if (token != null) request.headers['Authorization'] = 'Bearer $token';

      request.fields['latitude'] = latitude.toString();
      request.fields['longitude'] = longitude.toString();
      if (emergencyType != null && emergencyType.trim().isNotEmpty) {
        request.fields['emergency_type'] = emergencyType.trim();
      }
      if (guestName != null && guestName.trim().isNotEmpty) {
        request.fields['guest_name'] = guestName.trim();
      }
      if (guestMobile != null && guestMobile.trim().isNotEmpty) {
        request.fields['guest_mobile'] = guestMobile.trim();
      }

      if (photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', photo.path),
        );
      }

      // A bit longer than a normal call so a slow connection doesn't cut
      // the SOS off halfway — the photo is small (medium camera preset).
      final streamed = await request.send().timeout(
        const Duration(seconds: 30),
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
    } catch (_) {
      // Logging out works offline too — the saved login is removed below.
    }
    await clearSession();
    // This phone stops getting the logged-out resident's notifications.
    await unregisterFcmToken();
    return ApiResponse.success({});
  }

  // ── Error handler ─────────────────────────────────────────────────

  static String _handleError(dynamic e) {
    final msg = e.toString();
    if (msg.contains('SocketException') ||
        msg.contains('Connection refused') ||
        msg.contains('Failed host lookup') ||
        msg.contains('ClientException')) {
      return "Can't connect right now. Check your internet connection and try again.";
    }
    if (msg.contains('TimeoutException')) {
      return 'The connection is too slow right now. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

// ── API Response wrapper ──────────────────────────────────────────────────────

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;

  /// On an error: the server's HTTP status, when it was given (so far only
  /// getMe() sets it — 401 means the login was rejected). Null when the
  /// server couldn't be reached (no internet, timeout).
  final int? statusCode;

  ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.success(dynamic data) =>
      ApiResponse._(success: true, data: data);

  factory ApiResponse.error(String message, {dynamic data, int? statusCode}) =>
      ApiResponse._(
        success: false,
        error: message,
        data: data,
        statusCode: statusCode,
      );
}
