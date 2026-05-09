import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(String url) {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (data) {
          final Map<String, dynamic> message = jsonDecode(data);
          _messageController.add(message);
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _reconnect(url);
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _reconnect(url);
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _reconnect(url);
    }
  }

  void _reconnect(String url) {
    Future.delayed(const Duration(seconds: 5), () => connect(url));
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(message));
    }
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
  }
}
