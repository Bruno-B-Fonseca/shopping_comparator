import 'dart:io';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_web_socket/shelf_web_socket.dart';

// List of connected clients
final List<dynamic> _clients = [];

void main() async {
  final port = int.parse(Platform.environment['PORT'] ?? '3000');

  final handler = webSocketHandler((webSocket, subprotocol) {
    print('New client connected');
    _clients.add(webSocket);

    webSocket.stream.listen(
      (message) {
        print('Received message: $message');
        _broadcast(message, exclude: webSocket);
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
