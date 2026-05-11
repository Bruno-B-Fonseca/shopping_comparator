import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';
import '../lib/protocol.dart';

final Logger _log = Logger('Hub');

class ServerInfo {
  final String id;
  final String region;
  final String wsUrl;
  DateTime lastHeartbeat;

  ServerInfo(this.id, this.region, this.wsUrl, this.lastHeartbeat);

  Map<String, dynamic> toJson() => {
        fieldServerId: id,
        fieldRegion: region,
        fieldWsUrl: wsUrl,
        'lastHeartbeat': lastHeartbeat.toIso8601String(),
      };
}

final topics = <String, Set<WebSocketChannel>>{};
final servers = <String, ServerInfo>{};
final channelToServerId = <WebSocketChannel, String>{};

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
      final region = msg[fieldRegion] as String;
      final wsUrl = msg[fieldWsUrl] as String;
      
      servers[id] = ServerInfo(id, region, wsUrl, DateTime.now());
      channelToServerId[channel] = id;
      
      _log.info('Registered server $id in $region');
      
      // Auto-subscribe to regional topic
      _subscribeToTopic(channel, 'region/$region');
      
      _notifyPeersUpdate(region);
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

      final subscribers = topics[topic] ?? {};
      for (final sub in subscribers) {
        if (sub != channel) {
          sub.sink.add(jsonEncode({
            fieldType: msgRelay,
            fieldTopic: topic,
            fieldPayload: payload,
            fieldOriginServerId: serverId,
          }));
        }
      }
      break;

    case msgUnregister:
      _unregister(channel, notifyPeers: true);
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
      return _checkFields(channel, msg, [fieldServerId, fieldRegion, fieldWsUrl]);
    case msgSubscribe:
      return _checkFields(channel, msg, [fieldTopics]);
    case msgProductRequest:
      return _checkFields(channel, msg, [fieldPayload]);
    case msgPublish:
      if (!_checkFields(channel, msg, [fieldTopic, fieldPayload])) return false;
      
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
  final regionPeers = servers.values
      .where((s) => s.region == region)
      .map((p) => p.toJson())
      .toList();
  
  final updateMsg = jsonEncode({
    fieldType: msgPeersUpdate,
    fieldPeers: regionPeers,
  });

  final subscribers = topics[regionTopic] ?? {};
  for (final sub in subscribers) {
    try {
      sub.sink.add(updateMsg);
    } catch (e) {
      _log.warning('Failed to notify peer: $e');
    }
  }
}
