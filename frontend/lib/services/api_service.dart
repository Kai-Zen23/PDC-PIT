import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://card-clash-backend-1o5q.onrender.com';

  static Future<Map<String, dynamic>> login(String username) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createMatch(String username) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/match/create/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> joinMatch(String username, String matchId) async {
    final response = await http.post(
      Uri.parse('\$baseUrl/match/join/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'match_id': matchId}),
    );
    return jsonDecode(response.body);
  }
}
