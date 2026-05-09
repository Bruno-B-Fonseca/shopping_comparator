import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/websocket_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();

  String wsUrl = 'ws://localhost:3000'; // Default for local mobile dev

  if (kIsWeb) {
    final uri = Uri.base;
    final protocol = uri.scheme == 'https' ? 'wss' : 'ws';
    wsUrl = '$protocol://${uri.host}:${uri.port}/ws';
  }

  service.connect(wsUrl);
  ref.onDispose(() => service.dispose());
  return service;
});

final webSocketMessagesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(webSocketServiceProvider).messages;
});
