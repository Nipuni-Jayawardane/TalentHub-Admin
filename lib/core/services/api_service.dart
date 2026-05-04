import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slt_internship_attendance_portal/config/config.dart';

class AuthService {
  static const String baseUrl = Config.backendBaseUrl;
  static const String adminLoginEndpoint = "/auth/login";

  // Talent hub admin login
  Future<Map<String, dynamic>> adminLogin(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl$adminLoginEndpoint'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'userType': 'admin',
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorResponse = jsonDecode(response.body);
      throw Exception(errorResponse['message'] ?? 'Login failed');
    }
  }

  static Future<void> saveAdminInfo(Map<String, String> info) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_token', info['token']!);
    await prefs.setString('login_time', info['loginTime']!);
  }

  static Future<Map<String, String>?> getAdminInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('admin_token');
    final loginTime = prefs.getString('login_time');
    if (token != null && loginTime != null) {
      return {'token': token, 'loginTime': loginTime};
    }
    return null;
  }
}

class TalentTrailApiServices {
  static const String baseUrl = Config.talentTrailBaseUrl;

  // Reads the TalentTrail JWT stored after federated login and returns
  // the correct Authorization header for every API request.
  static Future<Map<String, String>> _headers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('talentTrailToken') ?? '';
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    return http.get(Uri.parse('$baseUrl$endpoint'), headers: await _headers());
  }

  static Future<http.Response> post(
    String endpoint, {
    required String body,
  }) async {
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: body,
    );
  }

  static Future<http.Response> put(
    String endpoint, {
    required String body,
  }) async {
    return http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
      body: body,
    );
  }

  static Future<http.Response> delete(String endpoint) async {
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: await _headers(),
    );
  }

  static Future<http.Response> getWithHeaders(
    String endpoint, {
    required Map<String, String> extraHeaders,
  }) async {
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {...await _headers(), ...extraHeaders},
    );
  }
}

//  TALENT TRAIL FEDERATED AUTH
//  Gate check only — verifies the TalentHub admin also has TalentTrail access.

class TalentTrailUnregisteredException implements Exception {
  final String message;
  TalentTrailUnregisteredException([
    this.message = 'You do not have access to TalentTrail.',
  ]);
  @override
  String toString() => message;
}

class TalentTrailAuthService {
  static const String _serviceToken =
      'TH_SK_f8e7d6c5b4a39281z0y9x8w7v6u5t4s3r2q1p0';

  static Future<void> federatedLogin() async {
    final prefs = await SharedPreferences.getInstance();

    // Get the TalentHub admin token saved during TalentHub login
    final adminToken = prefs.getString('admin_token');
    if (adminToken == null || adminToken.isEmpty) {
      throw Exception('Not logged in to TalentHub. Please log in again.');
    }

    // Decode the JWT to extract the email (without verifying signature)
    final email = _extractEmailFromToken(adminToken);
    if (email == null || email.isEmpty) {
      throw Exception('Could not retrieve admin email from TalentHub session.');
    }

    final url = Uri.parse('${Config.talentTrailBaseUrl}/auth/federated-login');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Service-Token': _serviceToken,
      },
      body: jsonEncode({
        'email': email,
        'source': 'talenthub',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }),
    );

    if (response.statusCode == 403 || response.statusCode == 404) {
      throw TalentTrailUnregisteredException();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'TalentTrail access check failed: ${response.statusCode} ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('No token returned from TalentTrail.');
    }

    // Store TalentTrail session separately
    await prefs.setString('talentTrailToken', token);
    if (data['user'] != null) {
      await prefs.setString('talentTrailUser', jsonEncode(data['user']));
    }
  }

  /// Decodes the JWT payload to extract the email claim.
  static String? _extractEmailFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];

      final padded = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      return decoded['email']?.toString() ?? decoded['sub']?.toString();
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isAuthenticated() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('talentTrailToken');
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('talentTrailToken');
    await prefs.remove('talentTrailUser');
  }
}
