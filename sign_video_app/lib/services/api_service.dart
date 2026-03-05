import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:5000";

  static String? token;

  // ================= SAVE TOKEN =================
  static Future<void> saveToken(String jwt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("token", jwt);
    token = jwt;
  }

  static Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    token = null;
  }

  // ================= REGISTER =================
  static Future<http.Response> register(
      String schoolName,
      String district,
      String region,
      String email,
      String password) async {
    return await http.post(
      Uri.parse("$baseUrl/register"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "school_name": schoolName,
        "district": district,
        "region": region,
        "email": email,
        "password": password
      }),
    );
  }

  // ================= LOGIN =================
  static Future<bool> login(String email, String password) async {
    var response = await http.post(
      Uri.parse("$baseUrl/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password
      }),
    );

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      await saveToken(data['token']);
      return true;
    }
    return false;
  }
}