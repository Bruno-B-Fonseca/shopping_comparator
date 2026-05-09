import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('Hub');

class ServerInfo {
  final String id;
  final String region;
  final String wsUrl;
  final DateTime lastSeen;

  ServerInfo(this.id, this.region, this.wsUrl, this.lastSeen);

  Map<String, dynamic> toJson() => {
        'id': id,
        'region': region,
        'wsUrl': wsUrl,
        'lastSeen': lastSeen.toIso8601String(),
      };
}

final topics = <String, Set<WebSocketChannel>>{};
final servers = <String, ServerInfo>{};
final channelToServerId = <WebSocketChannel, String>{};

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  final port = int.parse(Platform.environment['PORT'] ?? '3001');

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

  final server = await ioshelf.serve(handler, InternetAddress.anyIPv4, port);
  _log.info('Hub listening on ws://${server.address.host}:${server.port}');
}

void _handleMessage(WebSocketChannel channel, Map<String, dynamic> msg) {
  final type = msg['type'];
  switch (type) {
    case 'register':
      final serverId = msg['serverId'] as String;
      final region = msg['region'] as String;
      final wsUrl = msg['wsUrl'] as String;
      
      servers[serverId] = ServerInfo(serverId, region, wsUrl, DateTime.now());
      channelToServerId[channel] = serverId;
      
      _log.info('Registered server $serverId in $region');
      
      // Auto-subscribe to regional topic
      _subscribeToTopic(channel, 'region/$region');
      
      // Send peers update
      final peers = servers.values
          .where((s) => s.id != serverId)
          .map((p) => p.toJson())
          .toList();
      channel.sink.add(jsonEncode({'type': 'peers_update', 'peers': peers}));
      break;

    case 'subscribe':
      final topicsToSubscribe = (msg['topics'] as List).cast<String>();
      for (final topic in topicsToSubscribe) {
        _subscribeToTopic(channel, topic);
      }
      break;

    case 'publish':
      final topic = msg['topic'] as String;
      final payload = msg['payload'];
      final originServerId = channelToServerId[channel];

      final subscribers = topics[topic] ?? {};
      for (final sub in subscribers) {
        if (sub != channel) {
          sub.sink.add(jsonEncode({
            'type': 'relay',
            'topic': topic,
            'payload': payload,
            'originServerId': originServerId,
          }));
        }
      }
      break;

    case 'unregister':
      _unregister(channel);
      break;
  }
}

void _subscribeToTopic(WebSocketChannel channel, String topic) {
  topics.putIfAbsent(topic, () => {}).add(channel);
  _log.info('Subscribed to $topic');
}

void _unregister(WebSocketChannel channel) {
  final serverId = channelToServerId.remove(channel);
  if (serverId != null) {
    servers.remove(serverId);
    _log.info('Unregistered server $serverId');
  }
  
  for (final subscribers in topics.values) {
    subscribers.remove(channel);
  }
}
