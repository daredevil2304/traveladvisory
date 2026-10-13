import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(
    this.message, {
    this.statusCode,
  });

  @override
  String toString() => message;
}

class ApiService {
  static const FlutterSecureStorage _secureStorage =
      FlutterSecureStorage();

  static const String _userIdKey = 'user_id';

  static const String baseUrl =
      'https://traveladvisory-b15b.onrender.com';

  static const Duration requestTimeout =
      Duration(seconds: 45);

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String mobile,
    required String password,
  }) async {
    final uri =
        Uri.parse('$baseUrl/auth/register');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'full_name': fullName.trim(),
              'email': email.trim(),
              'mobile': mobile.trim(),
              'password': password,
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  static Future<Map<String, dynamic>> verifyOtp({
    required String identifier,
    required String otp,
  }) async {
    final uri =
        Uri.parse('$baseUrl/auth/verify-otp');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
              'otp': otp.trim(),
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // RESEND VERIFICATION OTP
  // ============================================================

  static Future<Map<String, dynamic>>
      resendVerificationOtp({
    required String identifier,
  }) async {
    final uri =
        Uri.parse(
      '$baseUrl/auth/resend-verification-otp',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final uri =
        Uri.parse('$baseUrl/auth/login');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
              'password': password,
            }),
          )
          .timeout(requestTimeout);

      final data =
          _handleResponse(response);

      final userId = data['user_id'];

      if (userId != null) {
        await _secureStorage.write(
          key: _userIdKey,
          value: userId.toString(),
        );
      }

      return data;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // SEND LOGIN OTP
  // ============================================================

  static Future<Map<String, dynamic>> sendLoginOtp({
    required String mobile,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/send-login-otp');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'mobile': mobile.trim(),
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // LOGIN WITH OTP
  // ============================================================

  static Future<Map<String, dynamic>> loginWithOtp({
    required String mobile,
    required String otp,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/login-with-otp');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'mobile': mobile.trim(),
              'otp': otp.trim(),
            }),
          )
          .timeout(requestTimeout);

      final data = _handleResponse(response);

      final userId = data['user_id'];

      if (userId != null) {
        await _secureStorage.write(
          key: _userIdKey,
          value: userId.toString(),
        );
      }

      return data;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // VERIFY PHONE SESSION (FIREBASE PHONE AUTH)
  // ============================================================

  static Future<Map<String, dynamic>> verifyPhoneSession({
    required String mobile,
    bool isLogin = false,
  }) async {
    final uri = Uri.parse('$baseUrl/auth/verify-phone-session');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'mobile': mobile.trim(),
              'is_login': isLogin,
            }),
          )
          .timeout(requestTimeout);

      final data = _handleResponse(response);

      final userId = data['user_id'];
      if (userId != null) {
        await _secureStorage.write(
          key: _userIdKey,
          value: userId.toString(),
        );
      }

      return data;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // PERSISTENT LOGIN
  // ============================================================

  /// Returns the stored user ID if a previous login exists.
  static Future<int?> getStoredUserId() async {
    final value =
        await _secureStorage.read(
      key: _userIdKey,
    );

    if (value == null || value.trim().isEmpty) {
      return null;
    }

    return int.tryParse(value);
  }

  /// Returns true when a previous login has been stored.
  static Future<bool> hasStoredSession() async {
    final userId = await getStoredUserId();

    return userId != null;
  }

  /// Clears the locally stored login session.
  static Future<void> clearStoredSession() async {
    await _secureStorage.delete(
      key: _userIdKey,
    );
  }

  // ============================================================
  // FORGOT PASSWORD
  // ============================================================

  static Future<Map<String, dynamic>>
      forgotPassword({
    required String identifier,
  }) async {
    final uri =
        Uri.parse(
      '$baseUrl/auth/forgot-password',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // RESET PASSWORD
  // ============================================================

  static Future<Map<String, dynamic>>
      resetPassword({
    required String identifier,
    required String otp,
    required String newPassword,
  }) async {
    final uri =
        Uri.parse(
      '$baseUrl/auth/reset-password',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'identifier': identifier.trim(),
              'otp': otp.trim(),
              'new_password': newPassword,
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // TRIP REQUEST
  // ============================================================

  static Future<Map<String, dynamic>>
      createTripRequest({
    required String role,
    required String source,
    required double latitude,
    required double longitude,
    required String destination,
    String? travelDate,
    String? travelTime,
    Map<String, dynamic>? travelerReport,
  }) async {
    final uri =
        Uri.parse('$baseUrl/trip/request');

    final storedUserId = await getStoredUserId();
    final int resolvedUserId = storedUserId ?? 1;

    final Map<String, dynamic> requestBody = {
      'user_id': resolvedUserId,
      'role': role,
      'source': source.trim(),
      'latitude': latitude,
      'longitude': longitude,
      'destination': destination.trim(),
    };

    if (travelDate != null) {
      requestBody['travel_date'] = travelDate;
    }

    if (travelTime != null) {
      requestBody['travel_time'] = travelTime;
    }

    if (travelerReport != null) {
      requestBody['traveler_report'] = travelerReport;
    }

    try {
      var response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(requestTimeout);

      if (response.statusCode == 404 &&
          response.body.contains('User not found') &&
          resolvedUserId != 1) {
        requestBody['user_id'] = 1;
        response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(requestBody),
            )
            .timeout(requestTimeout);
      }

      final data = _handleResponse(response);
      if (data['user_id'] != null) {
        final returnedUserId = data['user_id'] is int
            ? data['user_id'] as int
            : int.tryParse(data['user_id'].toString());
        if (returnedUserId != null) {
          await _secureStorage.write(
            key: _userIdKey,
            value: returnedUserId.toString(),
          );
        }
      }
      return data;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to connect to the server. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // ANALYZE TRIP
  // ============================================================

  static Future<Map<String, dynamic>>
      analyzeTrip({
    required int tripId,
  }) async {
    final uri =
        Uri.parse(
      '$baseUrl/trip/$tripId/analyze',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Accept': 'application/json',
            },
          )
          .timeout(requestTimeout);

      final data =
          _handleResponse(response);

      return data;
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to analyze the trip. Please make sure the backend is running.',
      );
    }
  }

  // ============================================================
  // CHATBOT MESSAGE
  // ============================================================

  static Future<Map<String, dynamic>>
      sendChatbotMessage({
    required int tripId,
    required String message,
  }) async {
    final uri =
        Uri.parse(
      '$baseUrl/trip/$tripId/chatbot',
    );

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'message': message.trim(),
            }),
          )
          .timeout(requestTimeout);

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      }

      throw ApiException(
        'Unable to contact the chatbot service. Please try again.',
      );
    }
  }

  // ============================================================
  // RESPONSE HANDLER
  // ============================================================

  static Map<String, dynamic>
      _handleResponse(
    http.Response response,
  ) {
    dynamic decodedBody;

    try {
      decodedBody =
          jsonDecode(response.body);
    } catch (_) {
      decodedBody = null;
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (decodedBody
          is Map<String, dynamic>) {
        return decodedBody;
      }

      throw ApiException(
        'The server returned an unexpected response.',
      );
    }

    String message =
        'Something went wrong. Please try again.';

    if (decodedBody
        is Map<String, dynamic>) {
      final detail =
          decodedBody['detail'];

      if (detail is String) {
        message = detail;
      } else if (detail is List &&
          detail.isNotEmpty) {
        message = detail
            .map((item) {
          if (item
              is Map<String, dynamic>) {
            return item['msg']?.toString() ??
                'Invalid request.';
          }

          return item.toString();
        }).join('\n');
      } else if (detail
          is Map<String, dynamic>) {
        final detailMessage =
            detail['message'];

        if (detailMessage != null) {
          message =
              detailMessage.toString();
        }
      }
    }

    throw ApiException(
      message,
      statusCode:
          response.statusCode,
    );
  }
    // ============================================================
  // SAVED REPORTS
  // ============================================================

  static Future<Map<String, dynamic>> saveReport({
    required int userId,
    required int tripId,
    required String title,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/reports'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'trip_id': tripId,
        'title': title,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception(
      data['detail'] ?? 'Failed to save report.',
    );
  }

  static Future<List<Map<String, dynamic>>> getSavedReports({
    required int userId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/reports?user_id=$userId'),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return List<Map<String, dynamic>>.from(
        (data as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }

    throw Exception(
      data is Map
          ? data['detail'] ?? 'Failed to load saved reports.'
          : 'Failed to load saved reports.',
    );
  }

  static Future<Map<String, dynamic>> getSavedReport({
    required int userId,
    required int reportId,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/reports/$reportId?user_id=$userId',
      ),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception(
      data['detail'] ?? 'Failed to load report.',
    );
  }

  static Future<void> deleteSavedReport({
    required int userId,
    required int reportId,
  }) async {
    final response = await http.delete(
      Uri.parse(
        '$baseUrl/reports/$reportId?user_id=$userId',
      ),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    final data = jsonDecode(response.body);

    throw Exception(
      data['detail'] ?? 'Failed to delete report.',
    );
  }
}