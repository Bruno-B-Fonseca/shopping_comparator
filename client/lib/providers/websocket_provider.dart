import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'consent_provider.dart';
import 'reputation_provider.dart';
import '../services/websocket_service.dart';

final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final service = WebSocketService();
  
  service.onReputationUpdate = (bonus) {
    ref.read(reputationProvider.notifier).updateScore(bonus);
  };

  final consent = ref.watch(consentProvider);

  if (consent.privacyAcknowledged) {
    String wsUrl = 'ws://localhost:3000'; // Default for local mobile dev

    if (kIsWeb) {
      final uri = Uri.base;
      final protocol = uri.scheme == 'https' ? 'wss' : 'ws';
      final port = uri.hasPort ? ':${uri.port}' : '';
      wsUrl = '$protocol://${uri.host}$port/ws';
    }

    service.connect(wsUrl);
  } else {
    debugPrint(
      'WebSocketProvider: Conexão adiada (aguardando aceite de privacidade)',
    );
  }

  ref.onDispose(() => service.dispose());
  return service;
});

final webSocketMessagesProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(webSocketServiceProvider).messages;
});
