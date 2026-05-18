import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

const String msgAuthVerifyRequest = 'auth_verify_request';
const String msgAuthVerifyResponse = 'auth_verify_response';
const String fieldType = 'type';
const String fieldPayload = 'payload';
const String fieldSignature = 'signature';
const String fieldNonce = 'nonce';

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

  Future<bool> verifyCredentials(String id, String password) async {
    if (_currentStatus != WebSocketStatus.connected) return false;

    final completer = Completer<bool>();
    final nonce = const Uuid().v4();

    // Calcular assinatura para o nonce
    final key = utf8.encode(password);
    final hmac = Hmac(sha256, key);
    final signature = hmac.convert(utf8.encode(nonce)).toString();

    // Escuta temporária pela resposta
    StreamSubscription? sub;
    sub = messages.listen((data) {
      if (data[fieldType] == msgAuthVerifyResponse) {
        final success = data[fieldPayload]['success'] == true;
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(success);
      }
    });

    // Timeout após 5 segundos
    Future.delayed(const Duration(seconds: 5), () {
      sub?.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });

    sendMessage({
      fieldType: msgAuthVerifyRequest,
      fieldNonce: nonce,
      fieldSignature: signature,
    });

    return completer.future;
  }

  Future<void> sendAuthenticatedMessage(Map<String, dynamic> message) async {
    final type = message['type'] as String?;
    
    // Se for mensagem oficial, assina usando credenciais salvas
    if (type == 'chat_message' || type == 'promotion') {
      final prefs = await SharedPreferences.getInstance();
      final password = prefs.getString('location_password');
      
      if (password != null && password.isNotEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final messageId = const Uuid().v4();
        
        final payloadString = jsonEncode(message['payload']);
        final key = utf8.encode(password);
        final messageToSign = '$payloadString$timestamp$messageId';
        
        final hmac = Hmac(sha256, key);
        final signature = hmac.convert(utf8.encode(messageToSign)).toString();
        
        message['signature'] = signature;
        message['timestamp'] = timestamp;
        message['messageId'] = messageId;
      } else {
        debugPrint('Erro: Tentativa de postagem oficial sem credenciais.');
        return; // Ou lançar exceção
      }
    }
    
    sendMessage(message);
  }

  void connect(String url) {
    _lastUrl = url;
    if (_currentStatus == WebSocketStatus.connecting) return;

    _updateStatus(WebSocketStatus.connecting);
    debugPrint('Connecting to WebSocket: $url');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Usa .ready para saber quando a conexão foi de fato estabelecida
      _channel!.ready
          .then((_) {
            debugPrint('WebSocket: Conexão estabelecida com sucesso!');
            _reconnectAttempts = 0;
            _updateStatus(WebSocketStatus.connected);

            // Solicita sincronização inicial de dados
            sendMessage({'type': 'sync_request'});
          })
          .catchError((e) {
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
    debugPrint(
      'Reconnecting in $delaySeconds seconds (attempt $_reconnectAttempts)...',
    );

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
      debugPrint(
        'Cannot send message: Status=$_currentStatus, Channel=${_channel != null}',
      );
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _statusController.close();
  }
}
