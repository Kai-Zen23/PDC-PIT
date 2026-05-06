import 'dart:convert';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onStateUpdated;
  VoidCallback? onMatchCancelled;

  void connect(String matchId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://card-clash-backend-1o5q.onrender.com/ws/match/$matchId/'),
    );

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      final event = data['event'] as String?;

      if (event == 'match_cancelled') {
        onMatchCancelled?.call();
      } else if (data['state'] != null && onStateUpdated != null) {
        onStateUpdated!(data['state'] as Map<String, dynamic>);
      }
    });
  }

  void sendAction(String action, String username, [int? powerup]) {
    if (_channel != null) {
      final data = <String, dynamic>{
        'action': action,
        'username': username,
      };
      if (powerup != null) {
        data['powerup'] = powerup;
      }
      _channel!.sink.add(jsonEncode(data));
    }
  }

  /// Used specifically for the Target Override powerup (powerup 5).
  void sendActionWithTarget(String action, String username, int powerup, int targetChoice) {
    if (_channel != null) {
      final data = <String, dynamic>{
        'action': action,
        'username': username,
        'powerup': powerup,
        'target_choice': targetChoice,
      };
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
