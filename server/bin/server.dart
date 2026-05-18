import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:minio/minio.dart';
import 'package:server/cluster_service.dart';
import 'package:server/price_processor.dart';
import 'package:server/protocol.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as ioshelf;
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:server/ai_service.dart';
import 'package:server/product_metadata_service.dart';

// List of connected clients
final List<WebSocketChannel> _clients = [];
late ClusterService _cluster;
late ProductMetadataService _metadataService;

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

  // Setup AI Metadata Service
  final aiProvider =
      Platform.environment['AI_PROVIDER']?.toLowerCase() ?? 'ollama';
  AIEngine aiEngine;
  if (aiProvider == 'gemini') {
    aiEngine = GeminiEngine(
      apiKey: Platform.environment['GEMINI_API_KEY'] ?? '',
    );
  } else {
    // Default to internal docker service name
    final ollamaUrl =
        Platform.environment['OLLAMA_URL'] ?? 'http://ollama:11434';
    aiEngine = OllamaEngine(baseUrl: ollamaUrl);
  }

  // Warmup AI Engine
  unawaited(aiEngine.warmup());

  _metadataService = ProductMetadataService(
    aiEngine: aiEngine,
    minio: minio,
    bucketName: bucketName,
  );

  if (hubUrl != null) {
    _cluster = ClusterService(
      hubUrl: hubUrl,
      region: Platform.environment['REGION'] ?? 'default',
      publicWsUrl:
          Platform.environment['PUBLIC_WS_URL'] ?? 'ws://localhost:$port',
      locationId: Platform.environment['LOCATION_ID'] ?? '',
      locationPassword: Platform.environment['LOCATION_PASSWORD'] ?? '',
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
  final priceProcessor = PriceProcessor(aiEngine: aiEngine);

  // WebSocket handler
  router.get(
    '/ws',
    (Request request) => webSocketHandler((webSocket, subprotocol) {
      print('New client connected');
      _clients.add(webSocket);

      // Envia boas-vindas para confirmar conexão ao cliente
      webSocket.sink.add(
        jsonEncode({
          fieldType: 'connection_established',
          fieldTimestamp: DateTime.now().toIso8601String(),
        }),
      );

      webSocket.stream.listen(
        (message) async {
          try {
            final Map<String, dynamic> msg = jsonDecode(message as String);
            final type = msg[fieldType] ?? 'unknown';
            print('--- SERVER: Recebido [$type] ---');

            // Handle Product Request with AI Fallback
            if (type == 'product_request') {
              final payload = msg[fieldPayload];
              final barcode = payload['barcode'] as String?;
              if (barcode != null) {
                // Dispara busca na IA de forma assíncrona
                _triggerAISearchIfMissing(barcode, request);
              }
            }

            // ... (variáveis globais)
            final String locationPassword =
                Platform.environment['LOCATION_PASSWORD'] ?? '';

            // ... (dentro do listen do webSocket)
            // Lógica de autenticação para postagens no chat/promoções
            if (type == 'chat_message' || type == 'promotion') {
              final signature = msg[fieldSignature] as String?;
              final timestamp = msg[fieldTimestamp] as String?;
              final messageId = msg[fieldMessageId] as String?;

              // Se a mensagem for assinada, validamos se é oficial.
              // Se não for assinada, tratamos como mensagem de usuário comum (isOfficial = false).
              if (signature != null && timestamp != null && messageId != null) {
                // Validar assinatura HMAC
                final payloadString = jsonEncode(msg[fieldPayload]);
                final key = utf8.encode(locationPassword);
                final messageToSign = '$payloadString$timestamp$messageId';
                final hmac = Hmac(sha256, key);
                final expectedSignature = hmac
                    .convert(utf8.encode(messageToSign))
                    .toString();

                if (signature == expectedSignature) {
                  msg['isOfficial'] = true;
                } else {
                  print('SERVER: Assinatura inválida para $type');
                  webSocket.sink.add(
                    jsonEncode({
                      fieldType: msgError,
                      fieldMessage: 'Assinatura inválida',
                    }),
                  );
                  return; // Descarta a mensagem com assinatura inválida
                }
              } else {
                // Mensagem não assinada, considerada usuário comum
                msg['isOfficial'] = false;
              }
            } else {
              msg['isOfficial'] = false;
            }

            final encodedMsg = jsonEncode(msg);

            // Broadcast locally
            print(
              'SERVER: Propagando [$type] para ${_clients.length - 1} outros clientes',
            );
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
    })(request),
  );
  // ... rest of the code

  // Process Price handler
  router.post('/products/process-price', (Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType == null ||
        !contentType.toLowerCase().contains('multipart/form-data')) {
      print('SERVER: Rejecting non-multipart request: $contentType');
      return Response.badRequest(body: 'Not a multipart request');
    }

    try {
      final multipart = request.multipart();
      if (multipart == null) {
        return Response.badRequest(body: 'Failed to parse multipart');
      }

      Uint8List? fileBytes;
      await for (final part in multipart.parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (contentDisposition != null &&
            contentDisposition.contains('name="image"')) {
          fileBytes = Uint8List.fromList(await part.readBytes());
        } else {
          await part.drain();
        }
      }

      if (fileBytes == null) {
        print('SERVER: Multipart "image" part not found');
        return Response.badRequest(body: 'Image part not found');
      }

      final price = await priceProcessor.processImage(fileBytes);
      if (price != null) {
        return Response.ok(
          jsonEncode({'price': price}),
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return Response.ok(
          jsonEncode({'price': null, 'error': 'Could not detect price'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      print('SERVER ERROR in process-price: $e');
      return Response.internalServerError(
        body: 'Multipart processing failed: $e',
      );
    }
  });

  // Upload handler
  router.post('/products/upload-photo', (Request request) async {
    final contentType = request.headers['content-type'];
    if (contentType == null ||
        !contentType.toLowerCase().contains('multipart/form-data')) {
      print('SERVER: Rejecting non-multipart request: $contentType');
      return Response.badRequest(body: 'Not a multipart request');
    }

    try {
      final multipart = request.multipart();
      if (multipart == null) {
        return Response.badRequest(body: 'Failed to parse multipart');
      }

      String? fileName;
      Uint8List? fileBytes;

      await for (final part in multipart.parts) {
        final contentDisposition = part.headers['content-disposition'];
        if (fileBytes == null &&
            contentDisposition != null &&
            contentDisposition.contains('name="image"')) {
          fileName = 'products/${DateTime.now().millisecondsSinceEpoch}.jpg';
          fileBytes = Uint8List.fromList(await part.readBytes());
        } else {
          await part.drain();
        }
      }

      if (fileBytes == null) {
        print('SERVER: Multipart "image" part not found');
        return Response.badRequest(body: 'Image part not found');
      }

      await minio.putObject(
        bucketName,
        fileName!,
        Stream.value(fileBytes),
        size: fileBytes.length,
      );

      final host = request.headers['host'] ?? 'localhost:8081';
      final xProto = request.headers['x-forwarded-proto']?.toLowerCase();
      final forceHttps =
          Platform.environment['FORCE_HTTPS']?.toLowerCase() == 'true';

      final proto = (xProto == 'https' || forceHttps) ? 'https' : 'http';
      final publicUrl = '$proto://$host/storage/$bucketName/$fileName';
      print('SERVER: Upload concluído: $publicUrl');
      return Response.ok(publicUrl);
    } catch (e) {
      print('SERVER ERROR in upload-photo: $e');
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

/// Helper to trigger AI search if a product is not found after a short delay.
void _triggerAISearchIfMissing(String barcode, Request request) async {
  // Wait a bit to see if another server in the cluster responds
  await Future.delayed(const Duration(seconds: 3));

  // In a real scenario, we'd check a local cache/DB here.
  // For this MVP, the "source of truth" is the broadcast,
  // so we'll just proceed with AI search if we want to be proactive.

  final metadata = await _metadataService.fetchAndRegisterProduct(barcode);
  if (metadata != null) {
    final registrationMsg = {
      fieldType: 'product_registration',
      fieldPayload: metadata,
      fieldMessageId: const Uuid().v4(),
      fieldTimestamp: DateTime.now().toIso8601String(),
    };

    print('AI: Cadastro automático concluído para $barcode. Transmitindo...');
    final encoded = jsonEncode(registrationMsg);
    _broadcast(encoded);

    if (Platform.environment['HUB_URL'] != null) {
      _cluster.publish('region/${_cluster.region}', registrationMsg);
    }
  }
}
