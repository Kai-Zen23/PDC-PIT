import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  Function(Map<String, dynamic>)? onStateUpdated;

  void connect(String matchId) {
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://card-clash-backend-1o5q.onrender.com/ws/match/$matchId/'),
    );

    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (onStateUpdated != null) {
        onStateUpdated!(data['state']);
      }
    });
  }

  void sendAction(String action, String username, [int? powerup]) {
    if (_channel != null) {
      final data = {
        'action': action,
        'username': username,
      };
      if (powerup != null) {
        data['powerup'] = powerup;
      }
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void disconnect() {
    _channel?.sink.close();
  }
}
