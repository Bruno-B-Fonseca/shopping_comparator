import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shopping_comparator_server/cluster_service.dart';
import 'package:logging/logging.dart';

// List of connected clients
final List<dynamic> _clients = [];
late ClusterService _cluster;

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level}: ${r.message}'));

  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final hubUrl = Platform.environment['HUB_URL'];
  
  if (hubUrl != null) {
    _cluster = ClusterService(
      hubUrl: hubUrl,
      region: Platform.environment['REGION'] ?? 'default',
      publicWsUrl: Platform.environment['PUBLIC_WS_URL'] ?? 'ws://localhost:$port',
      onRelayMessage: (payload, origin) {
        // Broadcast relayed message to local clients
        _broadcast(jsonEncode({'type': 'relay', 'payload': payload, 'origin': origin}));
      },
    );
    _cluster.connect();
  }

  final handler = webSocketHandler((webSocket, subprotocol) {
    print('New client connected');
    _clients.add(webSocket);

    webSocket.stream.listen(
      (message) {
        final msg = jsonDecode(message as String);
        print('Received message: $message');
        
        // Broadcast locally
        _broadcast(message, exclude: webSocket);
        
        // If not a relay message from hub, publish to cluster
        if (hubUrl != null && msg['origin'] == null) {
          _cluster.publish('region/${_cluster.region}', msg);
        }
      },
      onDone: () {
        print('Client disconnected');
        _clients.remove(webSocket);
      },
      onError: (error) {
        print('Error: $error');
        _clients.remove(webSocket);
      },
    );
  });

  final server = await ioshelf.serve(handler, InternetAddress.anyIPv4, port);
  print(
    'WebSocket server listening on ws://${server.address.host}:${server.port}',
  );
}

void _broadcast(dynamic message, {dynamic exclude}) {
  for (final client in _clients) {
    if (client != exclude) {
      try {
        client.sink.add(message);
      } catch (e) {
        print('Failed to send message to client: $e');
      }
    }
  }
}
