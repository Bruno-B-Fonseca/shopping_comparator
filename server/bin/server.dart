import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:minio/minio.dart';
import 'package:server/cluster_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// List of connected clients
final List<WebSocketChannel> _clients = [];
late ClusterService _cluster;

final minio = Minio(
  endPoint: Platform.environment['MINIO_ENDPOINT'] ?? 'localhost',
  port: int.tryParse(Platform.environment['MINIO_PORT'] ?? '9000') ?? 9000,
  accessKey: Platform.environment['MINIO_ROOT_USER'] ?? 'admin',
  secretKey: Platform.environment['MINIO_ROOT_PASSWORD'] ?? 'password',
  useSSL: false,
);

const String bucketName = 'shopping-comparator';

void main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level}: ${r.message}'));

  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final hubUrl = Platform.environment['HUB_URL'];

  if (hubUrl != null) {
    _cluster = ClusterService(
      hubUrl: hubUrl,
      region: Platform.environment['REGION'] ?? 'default',
      publicWsUrl:
          Platform.environment['PUBLIC_WS_URL'] ?? 'ws://localhost:$port',
      onRelayMessage: (payload, origin) {
        // Broadcast relayed message to local clients
        _broadcast(
          jsonEncode({'type': 'relay', 'payload': payload, 'origin': origin}),
        );
      },
    );
    _cluster.connect();
  }

  // Ensure bucket exists and is public
  try {
    if (!await minio.bucketExists(bucketName)) {
      await minio.makeBucket(bucketName);
      print('Bucket $bucketName created');
    }

    // Set public policy for the bucket
    final policy = {
      'Version': '2012-10-17',
      'Statement': [
        {
          'Action': ['s3:GetBucketLocation', 's3:ListBucket'],
          'Effect': 'Allow',
          'Principal': {
            'AWS': ['*'],
          },
          'Resource': ['arn:aws:s3:::$bucketName'],
        },
        {
          'Action': ['s3:GetObject'],
          'Effect': 'Allow',
          'Principal': {
            'AWS': ['*'],
          },
          'Resource': ['arn:aws:s3:::$bucketName/*'],
        },
      ],
    };
    await minio.setBucketPolicy(bucketName, policy);
    print('Bucket $bucketName policy set to public');
  } catch (e) {
    print('Warning: Could not verify/create/config bucket: $e');
  }

  final router = Router();

  // WebSocket handler
  router.get(
    '/ws',
    webSocketHandler((webSocket, subprotocol) {
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
    }),
  );

  // Upload handler
  router.post('/products/upload-photo', (Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType == null || !contentType.contains('multipart/form-data')) {
      return Response.badRequest(body: 'Not a multipart request');
    }

    final multipart = request.multipart();
    if (multipart == null) {
      return Response.badRequest(body: 'Failed to parse multipart');
    }

    String? fileName;
    Uint8List? fileBytes;

    await for (final part in multipart.parts) {
      final contentDisposition = part.headers['content-disposition'];
      if (contentDisposition != null &&
          contentDisposition.contains('name="image"')) {
        fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.jpg';
        fileBytes = await part.readBytes();
        break;
      }
    }

    if (fileName == null || fileBytes == null) {
      return Response.badRequest(body: 'Image part not found');
    }

    try {
      await minio.putObject(
        bucketName,
        fileName,
        Stream.value(fileBytes),
        size: fileBytes.length,
      );

      // Return the public URL. Note: in production this should be the Nginx proxy URL
      final baseUrl =
          Platform.environment['PUBLIC_URL'] ?? 'http://localhost:9000';
      return Response.ok('$baseUrl/$bucketName/$fileName');
    } catch (e) {
      print('Upload error: $e');
      return Response.internalServerError(body: 'Upload failed: $e');
    }
  });

  final pipeline = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware((innerHandler) {
        return (request) async {
          if (request.method == 'OPTIONS') {
            return Response.ok('', headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
              'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
            });
          }
          final response = await innerHandler(request);
          return response.change(headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
          });
        };
      })
      .addHandler(router.call);

  final server = await ioshelf.serve(pipeline, InternetAddress.anyIPv4, port);
  print('Server listening on http://${server.address.host}:${server.port}');
}

void _broadcast(dynamic message, {dynamic exclude}) {
  for (final client in _clients) {
    if (client != exclude) {
      try {
        client.sink.add(message);
      } catch (e) {
        print('Failed to send message: $e');
      }
    }
  }
}
