import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:logging/logging.dart';
import 'protocol.dart';

final Logger _log = Logger('ClusterService');

class ClusterService {
  final String hubUrl;
  final String region;
  final String serverId;
  final String locationId;
  final String locationPassword;
  final String publicWsUrl;

  late WebSocketChannel _hubChannel;
  final Function(Map<String, dynamic> payload, String originServerId)
  onRelayMessage;

  // Gerenciamento de promessas de resposta do GPI
  final Map<String, Completer<Map<String, dynamic>?>> _gpiRequests = {};

  ClusterService({
    required this.hubUrl,
    required this.region,
    required this.publicWsUrl,
    required this.locationId,
    required this.locationPassword,
    required this.onRelayMessage,
  }) : serverId = const Uuid().v4();

  void connect() {
    _log.info('Connecting to Hub: $hubUrl');
    _hubChannel = WebSocketChannel.connect(Uri.parse(hubUrl));

    // Passo 1: Iniciar registro (o Hub enviará o desafio)
    _hubChannel.sink.add(
      jsonEncode({
        fieldType: msgRegister,
        fieldServerId: serverId,
        fieldLocationId: locationId,
        fieldRegion: region,
        fieldWsUrl: publicWsUrl,
      }),
    );

    _hubChannel.stream.listen(
      (message) {
        _log.info('Received from Hub: $message');
        final msg = jsonDecode(message as String);
        _handleHubMessage(msg);
      },
      onDone: () => _log.warning('Disconnected from Hub'),
      onError: (e) => _log.severe('Hub error: $e'),
    );
  }

  void _handleHubMessage(Map<String, dynamic> msg) {
    final type = msg[fieldType];
    switch (type) {
      case msgAuthChallenge:
        final nonce = msg[fieldNonce] as String;
        final key = utf8.encode(locationPassword);
        final bytes = utf8.encode(nonce);
        final hmac = Hmac(sha256, key);
        final signature = hmac.convert(bytes).toString();

        _hubChannel.sink.add(
          jsonEncode({
            fieldType: msgAuthResponse,
            fieldLocationId: locationId,
            fieldSignature: signature,
          }),
        );
        break;
      case msgPing:
        _hubChannel.sink.add(jsonEncode({fieldType: msgPong}));
        break;
      case msgRelay:
        onRelayMessage(msg[fieldPayload], msg[fieldOriginServerId] as String);
        break;
      case msgReputationUpdate:
        // Encapsula como se fosse um relay para o broadcast local
        onRelayMessage(msg, 'hub'); 
        break;
      case msgPeersUpdate:
        _log.info('Peers updated: ${msg[fieldPeers]}');
        break;
      case msgGpiResponse:
        final barcode = msg[fieldBarcode] as String;
        final payload = msg[fieldPayload];
        if (_gpiRequests.containsKey(barcode)) {
          _gpiRequests.remove(barcode)!.complete(payload != null ? Map<String, dynamic>.from(payload) : null);
        }
        break;
    }
  }

  Future<Map<String, dynamic>?> lookupGpi(String barcode) async {
    final completer = Completer<Map<String, dynamic>?>();
    _gpiRequests[barcode] = completer;

    _hubChannel.sink.add(jsonEncode({
      fieldType: msgGpiLookup,
      fieldBarcode: barcode,
    }));

    // Timeout de 3 segundos para evitar travamento
    return completer.future.timeout(const Duration(seconds: 3), onTimeout: () {
      _gpiRequests.remove(barcode);
      _log.warning('GPI Lookup timeout for $barcode');
      return null;
    });
  }

  void updateRegistration({required String wsUrl}) {
    _hubChannel.sink.add(
      jsonEncode({
        fieldType: msgRegister,
        fieldServerId: serverId,
        fieldLocationId: locationId,
        fieldRegion: region,
        fieldWsUrl: wsUrl,
        'status': 'ok',
        'ai_version': '1.0.0',
      }),
    );
  }

  void proposeGpi(Map<String, dynamic> product) {
    _hubChannel.sink.add(jsonEncode({
      fieldType: msgGpiPropose,
      fieldPayload: product,
    }));
  }

  void publish(String topic, Map<String, dynamic> payload) {
    // Gerar um timestamp e messageId para prevenir replay attacks
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final messageId = const Uuid().v4();
    
    // Criar o payload para assinatura
    final payloadString = jsonEncode(payload);
    final key = utf8.encode(locationPassword);
    final messageToSign = '$payloadString$timestamp$messageId';
    
    final hmac = Hmac(sha256, key);
    final signature = hmac.convert(utf8.encode(messageToSign)).toString();

    _hubChannel.sink.add(
      jsonEncode({
        fieldType: msgPublish,
        fieldTopic: topic,
        fieldPayload: payload,
        fieldTimestamp: timestamp,
        fieldMessageId: messageId,
        fieldSignature: signature,
      }),
    );
  }

  void subscribe(List<String> topics) {
    _hubChannel.sink.add(
      jsonEncode({fieldType: msgSubscribe, fieldTopics: topics}),
    );
  }
}
