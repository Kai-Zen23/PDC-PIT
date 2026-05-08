import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const String baseUrl = 'https://card-clash-backend-1o5q.onrender.com/api';

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      } else {
        throw const ApiException('Unexpected server response format.');
      }
    } catch (_) {
      throw const ApiException('Unable to read server response.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['error']?.toString() ??
        body['detail']?.toString() ??
        'Request failed (${response.statusCode}).';
    throw ApiException(message);
  }

  static Future<Map<String, dynamic>> login(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    return _decodeResponse(response);
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
    return _decodeResponse(response);
  }

  /// Create a private lobby and get back a join_code.
  static Future<Map<String, dynamic>> createLobby(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lobby/create/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    return _decodeResponse(response);
  }

  /// Join a private lobby using a 6-character code.
  static Future<Map<String, dynamic>> joinLobby(String username, String joinCode) async {
    final response = await http.post(
      Uri.parse('$baseUrl/lobby/join/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'join_code': joinCode}),
    );
    return _decodeResponse(response);
  }

  /// Get the current status of a match.
  static Future<Map<String, dynamic>> getMatchStatus(String matchId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/match/$matchId/status/'),
    );
    return _decodeResponse(response);
  }
}
