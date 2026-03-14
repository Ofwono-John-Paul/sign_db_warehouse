import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    // defaultValue: 'http://localhost:5000',
    defaultValue: 'http://10.0.2.2:5000'

  );

  // static const String baseUrl = "http://localhost:5000";

  static String? token;
  static int? schoolId;
  static String? schoolName;

  // Token Management
  static Future<void> saveToken(String jwt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", jwt);
    token = jwt;
  }

  static Future<void> saveSchoolInfo(int id, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("school_id", id);
    await prefs.setString("school_name", name);
    schoolId = id;
    schoolName = name;
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");
    schoolId = prefs.getInt("school_id");
    schoolName = prefs.getString("school_name");
  }

  // Ensures protected requests do not send an empty/invalid bearer token.
  static Future<String?> _getValidToken() async {
    if (token == null || token!.isEmpty) {
      await loadToken();
    }
    if (token == null || token!.isEmpty) {
      return null;
    }
    return token;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("school_id");
    await prefs.remove("school_name");
    token = null;
    schoolId = null;
    schoolName = null;
  }

  static Map<String, String> get authHeaders => {
    "Content-Type": "application/json",
    if (token != null) "Authorization": "Bearer $token",
  };

  // ========================
  // AUTHENTICATION
  // ========================

  static Future<http.Response> register(
    String schoolName,
    String district,
    String region,
    String email,
    String password,
    String confirmPassword,
  ) async {
    return await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "school_name": schoolName,
        "district": district,
        "region": region,
        "email": email,
        "password": password,
        "confirm_password": confirmPassword,
      }),
    );
  }

  static Future<bool> login(String email, String password) async {
    var response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      final jwt = (data['token'] ?? data['access_token'])?.toString();
      if (jwt == null || jwt.isEmpty) {
        return false;
      }
      await saveToken(jwt);
      await saveSchoolInfo(data['school_id'], data['school_name']);
      return true;
    }
    return false;
  }

  static Future<Map<String, dynamic>?> getCurrentSchool() async {
    if (token == null) return null;

    var response = await http.get(
      Uri.parse("$baseUrl/me"),
      headers: authHeaders,
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return null;
  }

  // ========================
  // VIDEO UPLOAD
  // ========================

  static Future<bool> uploadVideo(
    String title,
    String signCategory,
    String signName,
    List<int> fileBytes,
    String fileName,
    String captureDevice,
  ) async {
    try {
      final activeToken = await _getValidToken();
      if (activeToken == null) {
        print("Upload blocked: missing JWT token.");
        return false;
      }

      var uri = Uri.parse("$baseUrl/upload");
      var request = http.MultipartRequest('POST', uri);

      request.headers.addAll({"Authorization": "Bearer $activeToken"});

      request.fields['title'] = title;
      request.fields['sign_category'] = signCategory;
      request.fields['sign_name'] = signName;
      request.fields['capture_device'] = captureDevice;

      request.files.add(
        http.MultipartFile.fromBytes('file', fileBytes, filename: fileName),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Upload response: ${response.statusCode} - ${response.body}");

      return response.statusCode == 200;
    } catch (e) {
      print("Upload error: $e");
      return false;
    }
  }

  // ========================
  // ANALYTICS
  // ========================

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/dashboard-summary"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  static Future<List<dynamic>> getVideosPerRegion() async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/videos-per-region"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getVideosPerSchool() async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/videos-per-school"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> getSignDistribution() async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/sign-distribution"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return {};
  }

  static Future<List<dynamic>> getDatasetGrowth({
    String period = 'daily',
  }) async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/dataset-growth?period=$period"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getModelPerformance() async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/model-performance"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getSchoolMap() async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/school-map"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<List<dynamic>> getInferenceLogs({int limit = 50}) async {
    var response = await http.get(
      Uri.parse("$baseUrl/analytics/inference-logs?limit=$limit"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // VIDEO LIST

  static Future<List<dynamic>> getVideos() async {
    var response = await http.get(
      Uri.parse("$baseUrl/videos"),
      headers: {"Content-Type": "application/json"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }
}
