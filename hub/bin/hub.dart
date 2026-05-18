import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import '../lib/protocol.dart';

final Logger _log = Logger('Hub');

class ServerInfo {
  final String id;
  final String locationId;
  final String region;
  final String wsUrl;
  DateTime lastHeartbeat;
  bool isAuthenticated;

  ServerInfo(this.id, this.locationId, this.region, this.wsUrl, this.lastHeartbeat, {this.isAuthenticated = false});

  Map<String, dynamic> toJson() => {
        fieldServerId: id,
        fieldLocationId: locationId,
        fieldRegion: region,
        fieldWsUrl: wsUrl,
        'lastHeartbeat': lastHeartbeat.toIso8601String(),
      };
}

final topics = <String, Set<WebSocketChannel>>{};
final servers = <String, ServerInfo>{};
final channelToServerId = <WebSocketChannel, String>{};
final pendingChallenges = <String, String>{};
_UpstreamHubLink? _upstreamLink;

String _generateNonce() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  return base64UrlEncode(values);
}

void resetHubState() {
  topics.clear();
  servers.clear();
  channelToServerId.clear();
}

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final port = int.parse(Platform.environment['PORT'] ?? '3001');
  
  // Inicia conexão com Hub superior, se configurado
  final upstreamUrl = Platform.environment['UPSTREAM_HUB_URL'];
  if (upstreamUrl != null && upstreamUrl.isNotEmpty) {
    _upstreamLink = _UpstreamHubLink(
      url: upstreamUrl,
      id: Platform.environment['FEDERATION_ID'] ?? 'regional-hub',
      password: Platform.environment['FEDERATION_PASSWORD'] ?? '',
      region: Platform.environment['REGION'] ?? 'default',
    );
    _upstreamLink!.connect();
  }

  await serveHub(InternetAddress.anyIPv4, port);
}

Future<HttpServer> serveHub(InternetAddress address, int port) async {
  final handler = webSocketHandler((webSocket, subprotocol) {
    _log.info('New connection to Hub');

    webSocket.stream.listen(
      (message) {
        try {
          final msg = jsonDecode(message as String);
          _handleMessage(webSocket, msg);
        } catch (e) {
          _log.severe('Error handling message: $e');
        }
      },
      onDone: () {
        _log.info('Connection closed');
        _unregister(webSocket);
      },
      onError: (e) {
        _log.severe('Error: $e');
        _unregister(webSocket);
      },
    );
  });

  // Start heartbeat timers
  Timer.periodic(const Duration(seconds: 10), (_) => _sendPings());
  Timer.periodic(const Duration(seconds: 5), (_) => _checkTimeouts());

  final server = await ioshelf.serve(handler, address, port);
  _log.info('Hub listening on ws://${server.address.host}:${server.port}');
  return server;
}

void _sendPings() {
  final pingMsg = jsonEncode({fieldType: msgPing});
  for (final channel in channelToServerId.keys) {
    try {
      channel.sink.add(pingMsg);
    } catch (e) {
      _log.warning('Failed to send ping: $e');
    }
  }
}

void _checkTimeouts() {
  final now = DateTime.now();
  final toRemove = <WebSocketChannel>[];

  channelToServerId.forEach((channel, serverId) {
    final info = servers[serverId];
    if (info != null && now.difference(info.lastHeartbeat).inSeconds > 15) {
      _log.warning('Server $serverId timed out');
      toRemove.add(channel);
    }
  });

  for (final channel in toRemove) {
    _unregister(channel, notifyPeers: true);
    channel.sink.close();
  }
}

Map<String, String>? _secrets;

Map<String, String> _loadSecrets() {
  if (_secrets != null) return _secrets!;
  try {
    final file = File('config/secrets.json');
    if (file.existsSync()) {
      _secrets = Map<String, String>.from(jsonDecode(file.readAsStringSync()));
      return _secrets!;
    }
  } catch (e) {
    _log.severe('Failed to load secrets: $e');
  }
  return {};
}

void _handleMessage(WebSocketChannel channel, Map<String, dynamic> msg) {
  final type = msg[fieldType];

  if (!_validateMessage(channel, msg)) {
    return;
  }

  // Update heartbeat for any message from a registered server
  final serverId = channelToServerId[channel];
  if (serverId != null && servers.containsKey(serverId)) {
    servers[serverId]!.lastHeartbeat = DateTime.now();
  }

  switch (type) {
    case msgRegister:
      final id = msg[fieldServerId] as String;
      final locationId = msg[fieldLocationId] as String;
      final region = msg[fieldRegion] as String;
      final wsUrl = msg[fieldWsUrl] as String;

      final nonce = _generateNonce();
      pendingChallenges[locationId] = nonce;

      servers[id] = ServerInfo(id, locationId, region, wsUrl, DateTime.now());
      channelToServerId[channel] = id;

      channel.sink.add(jsonEncode({fieldType: msgAuthChallenge, fieldNonce: nonce}));
      _log.info('Auth challenge sent to server $id for location $locationId');
      break;

    case msgAuthResponse:
      if (serverId == null) {
        _sendError(channel, 'Not registered');
        break;
      }
      final serverInfo = servers[serverId];
      if (serverInfo == null) {
        _sendError(channel, 'Server info not found');
        break;
      }

      final locationId = serverInfo.locationId;
      final nonce = pendingChallenges[locationId];
      if (nonce == null) {
        _sendError(channel, 'Challenge not found');
        break;
      }

      final signature = msg[fieldSignature] as String;
      final secrets = _loadSecrets();
      final expectedPassword = secrets[locationId];
      if (expectedPassword == null) {
        _sendError(channel, 'Location not authorized');
        return;
      }

      final key = utf8.encode(expectedPassword);
      final hmac = Hmac(sha256, key);
      final expectedSignature = hmac.convert(utf8.encode(nonce)).toString();

      if (signature != expectedSignature) {
        _sendError(channel, 'Invalid signature');
        _unregister(channel);
        return;
      }

      serverInfo.isAuthenticated = true;
      pendingChallenges.remove(locationId);

      _log.info('Server $serverId authenticated for $locationId');

      // Prossegue com o registro completo após autenticação
      _subscribeToTopic(channel, 'region/${serverInfo.region}');
      _notifyPeersUpdate(serverInfo.region);
      break;

    case msgPong:
      _log.fine('Received pong from $serverId');
      break;

    case msgSubscribe:
      final topicsToSubscribe = (msg[fieldTopics] as List).cast<String>();
      for (final topic in topicsToSubscribe) {
        _subscribeToTopic(channel, topic);
      }
      break;

    case msgPublish:
      final topic = msg[fieldTopic] as String;
      final payload = msg[fieldPayload];
      final timestamp = msg[fieldTimestamp] as String;
      final messageId = msg[fieldMessageId] as String;
      final signature = msg[fieldSignature] as String;

      final serverInfo = servers[channelToServerId[channel]];
      if (serverInfo == null || !serverInfo.isAuthenticated) {
        _sendError(channel, 'Not authenticated');
        break;
      }

      final secrets = _loadSecrets();
      final password = secrets[serverInfo.locationId];
      if (password == null) {
        _sendError(channel, 'Secret not found');
        break;
      }

      // Validar assinatura
      final payloadString = jsonEncode(payload);
      final key = utf8.encode(password);
      final messageToSign = '$payloadString$timestamp$messageId';
      final hmac = Hmac(sha256, key);
      final expectedSignature = hmac.convert(utf8.encode(messageToSign)).toString();

      if (signature != expectedSignature) {
        _sendError(channel, 'Invalid message signature');
        break;
      }

      // 1. Propagar localmente
      final relayMsg = {
        fieldType: msgRelay,
        fieldTopic: topic,
        fieldPayload: payload,
        fieldOriginServerId: serverInfo.id,
        fieldTimestamp: timestamp,
        fieldMessageId: messageId,
        fieldSignature: signature,
      };
      _broadcastToTopic(topic, jsonEncode(relayMsg), exclude: channel);

      // 2. Propagar para Hub superior (Subir na hierarquia)
      if (_upstreamLink != null && _upstreamLink!.isConnected) {
        _upstreamLink!.publish(topic, payload, timestamp, messageId, signature);
      }
      break;

    case msgSyncRequest:
      // Propaga pedido de sync localmente e para cima
      _broadcast(jsonEncode(msg), exclude: channel);
      if (_upstreamLink != null && _upstreamLink!.isConnected) {
        _upstreamLink!.send(msg);
      }
      break;
    
    case msgSyncResponse:
    case 'product_registration':
    case 'location_registration':
    case 'price_update':
    case 'chat_message':
      // Se receber estas mensagens diretamente de um nó, trata como se fosse um publish implícito para relay
      _broadcast(jsonEncode(msg), exclude: channel);
      if (_upstreamLink != null && _upstreamLink!.isConnected) {
        _upstreamLink!.send(msg);
      }
      break;
  }
}

bool _validateMessage(WebSocketChannel channel, Map<String, dynamic> msg) {
  final type = msg[fieldType];
  if (type == null || type is! String) {
    _sendError(channel, 'Missing or invalid "$fieldType"');
    return false;
  }

  switch (type) {
    case msgRegister:
      return _checkFields(channel, msg, [fieldServerId, fieldLocationId, fieldRegion, fieldWsUrl]);
    case msgAuthResponse:
      return _checkFields(channel, msg, [fieldSignature]);
    case msgSubscribe:
      return _checkFields(channel, msg, [fieldTopics]);
    case msgProductRequest:
      return _checkFields(channel, msg, [fieldPayload]);
    case msgSyncRequest:
    case msgSyncResponse:
      return true;
    case msgPublish:
      if (!_checkFields(channel, msg, [fieldTopic, fieldPayload, fieldTimestamp, fieldMessageId, fieldSignature])) return false;

      // Validate topic format
      final topic = msg[fieldTopic] as String;
      final topicRegex = RegExp(r'^(region/[a-z0-9-]+|barcode/[0-9]+)$');
      if (!topicRegex.hasMatch(topic)) {
        _sendError(channel, 'Invalid topic format: $topic');
        return false;
      }

      // Validate payload size (< 2KB)
      final payloadJson = jsonEncode(msg[fieldPayload]);
      if (payloadJson.length > 2048) {
        _sendError(channel, 'Payload too large (> 2KB)');
        return false;
      }
      return true;
    case msgUnregister:
    case msgPong:
    case 'product_registration':
    case 'location_registration':
    case 'price_update':
    case 'chat_message':
      return true;
    default:
      _sendError(channel, 'Unknown message type: $type');
      return false;
  }
}

bool _checkFields(WebSocketChannel channel, Map<String, dynamic> msg, List<String> fields) {
  for (final field in fields) {
    if (msg[field] == null) {
      _sendError(channel, 'Missing required field: $field');
      return false;
    }
  }
  return true;
}

void _sendError(WebSocketChannel channel, String message) {
  _log.warning('Validation error: $message');
  try {
    channel.sink.add(jsonEncode({
      fieldType: msgError,
      fieldMessage: message,
    }));
  } catch (e) {
    _log.severe('Failed to send error message: $e');
  }
}

void _subscribeToTopic(WebSocketChannel channel, String topic) {
  topics.putIfAbsent(topic, () => {}).add(channel);
  _log.info('Subscribed to $topic');
}

void _broadcastToTopic(String topic, String message, {WebSocketChannel? exclude}) {
  final subscribers = topics[topic] ?? {};
  for (final sub in subscribers) {
    if (sub != exclude) {
      try {
        sub.sink.add(message);
      } catch (e) {
        _log.warning('Failed to send to subscriber: $e');
      }
    }
  }
}

void _broadcast(String message, {WebSocketChannel? exclude}) {
  for (final channel in channelToServerId.keys) {
    if (channel != exclude) {
      try {
        channel.sink.add(message);
      } catch (e) {
        _log.warning('Failed to broadcast: $e');
      }
    }
  }
}

void _unregister(WebSocketChannel channel, {bool notifyPeers = false}) {
  final serverId = channelToServerId.remove(channel);
  String? region;
  if (serverId != null) {
    region = servers[serverId]?.region;
    servers.remove(serverId);
    _log.info('Unregistered server $serverId');
  }

  for (final subscribers in topics.values) {
    subscribers.remove(channel);
  }

  if (notifyPeers && region != null) {
    _notifyPeersUpdate(region);
  }
}

void _notifyPeersUpdate(String region) {
  final regionTopic = 'region/$region';
  final regionPeers = servers.values.where((s) => s.region == region).map((p) => p.toJson()).toList();

  final updateMsg = jsonEncode({
    fieldType: msgPeersUpdate,
    fieldPeers: regionPeers,
  });

  _broadcastToTopic(regionTopic, updateMsg);
}

/// Gerencia a conexão com um Hub superior (Nacional/Upstream)
class _UpstreamHubLink {
  final String url;
  final String id;
  final String password;
  final String region;
  final String internalId;
  WebSocketChannel? _channel;
  bool isConnected = false;

  _UpstreamHubLink({
    required this.url,
    required this.id,
    required this.password,
    required this.region,
  }) : internalId = const Uuid().v4();

  void connect() {
    _log.info('Connecting to UPSTREAM Hub: $url');
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      
      // Registro inicial
      _channel!.sink.add(jsonEncode({
        fieldType: msgRegister,
        fieldServerId: internalId,
        fieldLocationId: id,
        fieldRegion: region,
        fieldWsUrl: 'internal://hub', // Hubs não tem WS pública direta para clientes do pai
      }));

      _channel!.stream.listen(
        (message) {
          final msg = jsonDecode(message as String);
          _handleUpstreamMessage(msg);
        },
        onDone: () {
          isConnected = false;
          _log.warning('Disconnected from UPSTREAM Hub. Retrying in 5s...');
          Future.delayed(const Duration(seconds: 5), connect);
        },
        onError: (e) {
          isConnected = false;
          _log.severe('UPSTREAM Hub error: $e');
        },
      );
    } catch (e) {
      _log.severe('Failed to connect to upstream: $e');
      Future.delayed(const Duration(seconds: 5), connect);
    }
  }

  void _handleUpstreamMessage(Map<String, dynamic> msg) {
    final type = msg[fieldType];
    switch (type) {
      case msgAuthChallenge:
        final nonce = msg[fieldNonce] as String;
        final key = utf8.encode(password);
        final hmac = Hmac(sha256, key);
        final signature = hmac.convert(utf8.encode(nonce)).toString();

        _channel!.sink.add(jsonEncode({
          fieldType: msgAuthResponse,
          fieldLocationId: id,
          fieldSignature: signature,
        }));
        break;

      case msgRelay:
        isConnected = true;
        // Recebeu do Nacional -> Distribui para os locais
        final topic = msg[fieldTopic] as String;
        _broadcastToTopic(topic, jsonEncode(msg));
        break;
      
      case msgPing:
        _channel!.sink.add(jsonEncode({fieldType: msgPong}));
        break;
      
      case msgError:
        _log.severe('Upstream Hub Error: ${msg[fieldMessage]}');
        break;
    }
  }

  void publish(String topic, dynamic payload, String timestamp, String messageId, String signature) {
    if (!isConnected) return;
    _channel!.sink.add(jsonEncode({
      fieldType: msgPublish,
      fieldTopic: topic,
      fieldPayload: payload,
      fieldTimestamp: timestamp,
      fieldMessageId: messageId,
      fieldSignature: signature,
    }));
  }

  void send(Map<String, dynamic> msg) {
    if (!isConnected) return;
    _channel!.sink.add(jsonEncode(msg));
  }
}
