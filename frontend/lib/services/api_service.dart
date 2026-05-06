import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://card-clash-backend-1o5q.onrender.com/api';

  static Future<Map<String, dynamic>> login(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    return jsonDecode(response.body);
  }

  /// Find a match in the given mode ('casual' or 'ranked').
  /// Returns the match_id and status. If no opponent is ready yet,
  /// the match will be in 'waiting' state; the caller should poll or
  /// rely on the WebSocket start_game event.
  static Future<Map<String, dynamic>> findMatch(String username, String mode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/match/find/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'mode': mode}),
    );
    return jsonDecode(response.body);
  }

  /// Create a private lobby and get back a join_code.
  static Future<Map<String, dynamic>> createLobby(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lobby/create/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    return jsonDecode(response.body);
  }

  /// Join a private lobby using a 6-character code.
  static Future<Map<String, dynamic>> joinLobby(String username, String joinCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lobby/join/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'join_code': joinCode}),
    );
    return jsonDecode(response.body);
  }

  /// Get the current status of a match.
  static Future<Map<String, dynamic>> getMatchStatus(String matchId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/match/$matchId/status/'),
    );
    return jsonDecode(response.body);
  }
}
