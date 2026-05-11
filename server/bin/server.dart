import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:minio/minio.dart';
import 'package:server/cluster_service.dart';
import 'package:server/protocol.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
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
          jsonEncode({
            fieldType: msgRelay,
            fieldPayload: payload,
            'origin':
                origin, // Keep 'origin' for local client compat or update them too
          }),
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

      // Envia boas-vindas para confirmar conexão ao cliente
      webSocket.sink.add(jsonEncode({
        fieldType: 'connection_established',
        fieldTimestamp: DateTime.now().toIso8601String(),
      }));

      webSocket.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> msg = jsonDecode(message as String);
            final type = msg[fieldType] ?? 'unknown';
            print('--- SERVER: Recebido [$type] ---');

            // Ensure messageId and timestamp exist for deduplication
            msg[fieldMessageId] ??= const Uuid().v4();
            msg[fieldTimestamp] ??= DateTime.now().toIso8601String();

            final encodedMsg = jsonEncode(msg);

            // Broadcast locally
            print('SERVER: Propagando [$type] para ${_clients.length - 1} outros clientes');
            _broadcast(encodedMsg, exclude: webSocket);

            // If not a relay message from hub, publish to cluster
            if (hubUrl != null && msg['origin'] == null) {
              print('SERVER: Enviando [$type] para o Hub');
              _cluster.publish('region/${_cluster.region}', msg);
            }
          } catch (e) {
            print('SERVER ERROR: Falha ao processar mensagem: $e');
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

    // Drain all parts to ensure the request body is fully consumed
    await for (final part in multipart.parts) {
      if (fileName == null) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition != null &&
            contentDisposition.contains('name="image"')) {
          fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.jpg';
          fileBytes = await part.readBytes();
          // Don't break here, we need to drain other parts if they exist
        } else {
          await part.drain();
        }
      } else {
        await part.drain();
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

      // Construct URL dynamically.
      // Use protocol-relative URLs if possible, or force HTTPS if requested.
      final host = request.headers['host'] ?? 'localhost:8081';
      final xProto = request.headers['x-forwarded-proto']?.toLowerCase();
      final forceHttps =
          Platform.environment['FORCE_HTTPS']?.toLowerCase() == 'true';

      final proto = (xProto == 'https' || forceHttps) ? 'https' : 'http';
      final publicUrl = '$proto://$host/storage/$bucketName/$fileName';
      return Response.ok(publicUrl);
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
            return Response.ok(
              '',
              headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers':
                    'Origin, Content-Type, Authorization',
              },
            );
          }
          final response = await innerHandler(request);
          return response.change(
            headers: {
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
              'Access-Control-Allow-Headers':
                  'Origin, Content-Type, Authorization',
            },
          );
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
