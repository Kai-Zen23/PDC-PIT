import 'dart:convert';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onStateUpdated;
  VoidCallback? onMatchCancelled;
  VoidCallback? onPlayerJoined;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  Function(dynamic)? onError;
  bool _hasConfirmedConnection = false;

  void connect(String matchId, String username) {
    // Pass username in query string to help backend identify the connection
    final uri = Uri.parse('wss://card-clash-backend-1o5q.onrender.com/ws/match/$matchId/?username=$username');
    _channel = WebSocketChannel.connect(uri);
    _hasConfirmedConnection = false;

    _channel!.stream.listen(
      (message) {
        if (!_hasConfirmedConnection) {
          _hasConfirmedConnection = true;
          onConnected?.call();
        }

        final data = jsonDecode(message);
        final event = data['event'] as String?;

        if (event == 'match_cancelled') {
          onMatchCancelled?.call();
        } else if (event == 'player_joined') {
          onPlayerJoined?.call();
        } else if (data['state'] != null && onStateUpdated != null) {
          onStateUpdated!(data['state'] as Map<String, dynamic>);
        }
      },
      onError: (err) {
        onError?.call(err);
      },
      onDone: () {
        onDisconnected?.call();
        _hasConfirmedConnection = false;
      },
    );
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
    _channel = null;
    _hasConfirmedConnection = false;
  }
}
