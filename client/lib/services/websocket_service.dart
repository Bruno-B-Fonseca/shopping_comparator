import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WebSocketStatus { connected, disconnected, connecting }

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WebSocketStatus> _statusController =
      StreamController<WebSocketStatus>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<WebSocketStatus> get status => _statusController.stream;

  WebSocketStatus _currentStatus = WebSocketStatus.disconnected;
  WebSocketStatus get currentStatus => _currentStatus;

  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  String? _lastUrl;

  void connect(String url) {
    _lastUrl = url;
    if (_currentStatus == WebSocketStatus.connecting) return;

    _updateStatus(WebSocketStatus.connecting);
    debugPrint('Connecting to WebSocket: $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // Usa .ready para saber quando a conexão foi de fato estabelecida
      _channel!.ready.then((_) {
        debugPrint('WebSocket: Conexão estabelecida com sucesso!');
        _reconnectAttempts = 0;
        _updateStatus(WebSocketStatus.connected);
      }).catchError((e) {
        debugPrint('WebSocket: Erro ao validar prontidão: $e');
      });

      _channel!.stream.listen(
        (data) {
          // Garante status conectado ao receber qualquer dado
          if (_currentStatus != WebSocketStatus.connected) {
            _updateStatus(WebSocketStatus.connected);
          }
          
          try {
            final Map<String, dynamic> message = jsonDecode(data);
            _messageController.add(message);
          } catch (e) {
            debugPrint('Error decoding message: $e');
          }
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _updateStatus(WebSocketStatus.disconnected);
          _reconnect();
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _updateStatus(WebSocketStatus.disconnected);
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _updateStatus(WebSocketStatus.disconnected);
      _reconnect();
    }
  }

  void _updateStatus(WebSocketStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void _reconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectAttempts++;
    // Exponential backoff: 1s, 2s, 4s, 8s, up to 30s
    final delaySeconds = (1 << (_reconnectAttempts - 1)).clamp(1, 30);
    debugPrint('Reconnecting in $delaySeconds seconds (attempt $_reconnectAttempts)...');

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_lastUrl != null) {
        connect(_lastUrl!);
      }
    });
  }

  /// Força uma verificação de conexão e tenta reconectar imediatamente se estiver desconectado.
  void reconnectIfNeeded() {
    if (_currentStatus == WebSocketStatus.disconnected && _lastUrl != null) {
      debugPrint('WebSocket: Reconexão forçada solicitada.');
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0; // Reseta o backoff para conectar rápido
      connect(_lastUrl!);
    }
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_channel != null && _currentStatus == WebSocketStatus.connected) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('Error sending message: $e');
      }
    } else {
      debugPrint('Cannot send message: Status=$_currentStatus, Channel=${_channel != null}');
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}
