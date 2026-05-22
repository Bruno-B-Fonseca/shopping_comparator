import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'reputation_service.dart';

const String msgAuthVerifyRequest = 'auth_verify_request';
const String msgAuthVerifyResponse = 'auth_verify_response';
const String msgReputationUpdate = 'reputation_update';
const String fieldType = 'type';
const String fieldPayload = 'payload';
const String fieldSignature = 'signature';
const String fieldNonce = 'nonce';
const String fieldContributorHash = 'contributorHash';
const String fieldBonus = 'bonus';

enum WebSocketStatus { connected, disconnected, connecting }

class WebSocketService {
  WebSocketChannel? _channel;
  Function(int bonus)? onReputationUpdate;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<WebSocketStatus> _statusController =
      StreamController<WebSocketStatus>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  Stream<WebSocketStatus> get status => _statusController.stream;

  WebSocketStatus _currentStatus = WebSocketStatus.disconnected;
  WebSocketStatus get currentStatus => _currentStatus;
  String? get currentUrl => _lastUrl;

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
    debugPrint('WebSocket: Iniciando conexão com $url');

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;

      // Usa .ready para saber quando a conexão foi de fato estabelecida
      channel.ready.then((_) {
        debugPrint('WebSocket: Conexão estabelecida com sucesso!');
        _reconnectAttempts = 0;
        _updateStatus(WebSocketStatus.connected);

        // Solicita sincronização inicial de dados
        sendMessage({'type': 'sync_request'});
      }).catchError((e) {
        debugPrint('WebSocket: Erro na prontidão da conexão: $e');
        _updateStatus(WebSocketStatus.disconnected);
        _reconnect();
      });

      channel.stream.listen(
        (data) {
          // Garante status conectado ao receber qualquer dado
          if (_currentStatus != WebSocketStatus.connected) {
            _updateStatus(WebSocketStatus.connected);
          }

          try {
            if (data == null) {
              debugPrint('WebSocket: Dados nulos recebidos no stream.');
              return;
            }
            final Map<String, dynamic> message = jsonDecode(data.toString());
            
            // Tratamento especial para atualização de reputação pessoal
            if (message[fieldType] == msgReputationUpdate) {
              final targetHash = message[fieldContributorHash];
              final bonus = message[fieldBonus] as int?;
              if (targetHash == ReputationService.contributorHash && bonus != null) {
                if (onReputationUpdate != null) {
                  onReputationUpdate!(bonus);
                } else {
                  // Fallback para atualização direta se o callback não estiver setado
                  ReputationService.updateMyScore(bonus);
                }
                debugPrint('Reputação: Bônus de $bonus recebido!');
              }
            }

            _messageController.add(message);
          } catch (e) {
            debugPrint('WebSocket: Erro ao decodificar mensagem: $e | Data: $data');
          }
        },
        onDone: () {
          debugPrint('WebSocket: Conexão encerrada pelo servidor (onDone)');
          _updateStatus(WebSocketStatus.disconnected);
          _reconnect();
        },
        onError: (error) {
          debugPrint('WebSocket: Erro no stream: $error');
          _updateStatus(WebSocketStatus.disconnected);
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('WebSocket: Falha crítica na tentativa de conexão: $e');
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
    final channel = _channel;
    if (channel != null && _currentStatus == WebSocketStatus.connected) {
      try {
        // Injeta o Hash de contribuidor anônimo para Web of Trust
        message[fieldContributorHash] = ReputationService.contributorHash;
        
        channel.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('WebSocket: Erro ao enviar mensagem: $e');
      }
    } else {
      debugPrint(
        'WebSocket: Não foi possível enviar (Status=$_currentStatus, Channel=${channel != null})',
      );
    }
  }

  void dispose() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    if (!_messageController.isClosed) _messageController.close();
    if (!_statusController.isClosed) _statusController.close();
  }
}
