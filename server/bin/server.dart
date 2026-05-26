import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
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
import 'package:server/invoice_service.dart';
import 'package:server/product_metadata_service.dart';

// List of connected clients
final List<WebSocketChannel> _clients = [];
late ClusterService _cluster;
late ProductMetadataService _metadataService;
final _invoiceService = InvoiceService();
String? _announcedUrl;
late DateTime _startTime;

Minio? _minio;
const String bucketName = 'shopping-comparator';

void main() async {
  _startTime = DateTime.now();
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) => print('${r.level}: ${r.message}'));

  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final hubUrl = Platform.environment['HUB_URL'];

  // Setup AI Metadata Service (Opcional no Nó Leve)
  final aiProvider = Platform.environment['AI_PROVIDER']?.toLowerCase();
  AIEngine? aiEngine;

  if (aiProvider == 'gemini') {
    aiEngine = GeminiEngine(
      apiKey: Platform.environment['GEMINI_API_KEY'] ?? '',
    );
  } else if (aiProvider == 'ollama') {
    final ollamaUrl = Platform.environment['OLLAMA_URL'];
    aiEngine = OllamaEngine(baseUrl: ollamaUrl);
  }

  // Warmup AI Engine se disponível
  if (aiEngine != null) {
    unawaited(aiEngine.warmup());
  }

  // Setup MinIO (Opcional no Nó Leve)
  if (Platform.environment['MINIO_ENDPOINT'] != null) {
    _minio = Minio(
      endPoint: Platform.environment['MINIO_ENDPOINT']!,
      port: int.tryParse(Platform.environment['MINIO_PORT'] ?? '9000') ?? 9000,
      accessKey: Platform.environment['MINIO_ROOT_USER'] ?? 'admin',
      secretKey: Platform.environment['MINIO_ROOT_PASSWORD'] ?? 'password',
      useSSL: false,
    );

    // Ensure bucket exists
    try {
      if (!await _minio!.bucketExists(bucketName)) {
        await _minio!.makeBucket(bucketName);
        print('Bucket $bucketName created');
      }
    } catch (e) {
      print('MinIO: Error checking/creating bucket: $e');
    }
  }

  if (hubUrl != null) {
    _cluster = ClusterService(
      hubUrl: hubUrl,
      region: Platform.environment['REGION'] ?? 'default',
      publicWsUrl:
          Platform.environment['PUBLIC_WS_URL'] ?? 'ws://localhost:$port',
      locationId: Platform.environment['LOCATION_ID'] ?? '',
      locationPassword: Platform.environment['LOCATION_PASSWORD'] ?? '',
      lat: double.tryParse(Platform.environment['LAT'] ?? ''),
      lng: double.tryParse(Platform.environment['LNG'] ?? ''),
      onRelayMessage: (payload, origin) {
        // Preserva campos de reputação se presentes no payload original (que foi relayado)
        // Nota: O ClusterService já passa o payload extraído da msg de Relay do Hub.

        _broadcast(
          jsonEncode({
            fieldType: msgRelay,
            fieldPayload: payload,
            'origin': origin,
          }),
        );
      },
    );
    _cluster.connect();
  }

  _metadataService = ProductMetadataService(
    aiEngine: aiEngine,
    minio: _minio,
    bucketName: bucketName,
    clusterService: hubUrl != null ? _cluster : null, // Integração GPI
  );

  // Ensure bucket is public if minio is available
  if (_minio != null) {
    try {
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
      await _minio!.setBucketPolicy(bucketName, policy);
      print('Bucket $bucketName policy set to public');
    } catch (e) {
      print('Warning: Could not set bucket policy: $e');
    }
  }

  final router = Router();
  final priceProcessor = PriceProcessor(aiEngine: aiEngine);


  // Proxy for external images (fixes CORS on Web)
  router.get('/proxy', (Request request) async {
    final url = request.url.queryParameters['url'];
    if (url == null) return Response.badRequest(body: 'Missing url parameter');

    try {
      print('SERVER: Proxying request for: $url');
      final response = await http.get(Uri.parse(url));
      return Response.ok(
        response.bodyBytes,
        headers: {
          'Content-Type':
              response.headers['content-type'] ?? 'application/octet-stream',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      print('SERVER PROXY ERROR: $e');
      return Response.internalServerError(body: 'Proxy error: $e');
    }
  });

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

            // --- SEGURANÇA: Sanitização Global ---
            // NUNCA permite que o cliente envie sua própria flag isOfficial no payload
            if (msg[fieldPayload] is Map) {
              msg[fieldPayload].remove('isOfficial');
            }
            msg.remove('isOfficial');

            final String locationPassword =
                Platform.environment['LOCATION_PASSWORD'] ?? '';

            // Handle Authentication Verification
            if (type == msgAuthVerifyRequest) {
              final signature = msg[fieldSignature] as String?;
              final nonce = msg[fieldNonce] as String?;

              if (signature != null && nonce != null) {
                final key = utf8.encode(locationPassword);
                final hmac = Hmac(sha256, key);
                final expectedSignature = hmac
                    .convert(utf8.encode(nonce))
                    .toString();

                final success =
                    signature == expectedSignature &&
                    locationPassword.isNotEmpty;
                webSocket.sink.add(
                  jsonEncode({
                    fieldType: msgAuthVerifyResponse,
                    fieldPayload: {'success': success},
                  }),
                );
                print(
                  'SERVER: Verificação de credenciais: ${success ? 'SUCESSO' : 'FALHA'}',
                );
              }
              return;
            }

            // Handle Product Request with AI Fallback
            if (type == 'product_request') {
              final payload = msg[fieldPayload];
              final barcode = payload['barcode'] as String?;
              final force = payload['force'] == true;
              if (barcode != null) {
                _triggerAISearchIfMissing(barcode, request, force: force);
              }
            }

            // Handle Sync Request
            if (type == msgSyncRequest) {
              print(
                'SERVER: Propagando sync_request para todos os clientes...',
              );
              _broadcast(message, exclude: webSocket);
              if (hubUrl != null) {
                _cluster.publish('region/${_cluster.region}', msg);
              }
              return;
            }

            // Lógica de autenticação para tipos críticos
            final criticalTypes = [
              'chat_message',
              'promotion',
              'product_registration',
              'location_registration',
              'price_update',
            ];

            if (criticalTypes.contains(type)) {
              final signature = msg[fieldSignature] as String?;
              final timestamp = msg[fieldTimestamp] as String?;
              final messageId = msg[fieldMessageId] as String?;

              if (signature != null &&
                  timestamp != null &&
                  messageId != null &&
                  locationPassword.isNotEmpty) {
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
                  if (msg[fieldPayload] is Map) {
                    msg[fieldPayload]['isOfficial'] = true;
                  }
                } else {
                  print(
                    'SERVER: Assinatura inválida para $type (SPOOFING ATTEMPTED)',
                  );
                  msg['isOfficial'] = false;
                  // Se for promoção, descarta
                  if (type == 'promotion') return;
                }
              } else {
                msg['isOfficial'] = false;
                // Se for promoção ou registro obrigatório oficial, descarta sem assinatura
                if (type == 'promotion') return;
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
    if (_minio == null) {
      return Response.badRequest(body: 'Storage local (MinIO) não disponível neste nó leve.');
    }

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

      await _minio!.putObject(
        bucketName,
        fileName!,
        Stream.value(fileBytes),
        size: fileBytes.length,
      );

      final host = request.headers['host'];
      final xProto = request.headers['x-forwarded-proto']?.toLowerCase();
      final forceHttps = Platform.environment['FORCE_HTTPS']?.toLowerCase() == 'true';

      // Se estamos atrás de um proxy (Cloudflare/Nginx), usamos o host do request.
      // Se não, fallback para localhost (dev).
      final proto = (xProto == 'https' || forceHttps) ? 'https' : 'http';
      final baseUrl = host != null ? '$proto://$host' : '';
      
      final publicUrl = '$baseUrl/storage/$bucketName/$fileName';
      print('SERVER: Upload concluído: $publicUrl');
      return Response.ok(publicUrl);
    } catch (e) {
      print('SERVER ERROR in upload-photo: $e');
      return Response.internalServerError(body: 'Upload failed: $e');
    }
  });

  router.post('/api/announce-url', (Request request) async {
    final body = await request.readAsString();
    try {
      final Map<String, dynamic> data = jsonDecode(body);
      final url = data['url'] as String?;
      if (url != null) {
        _announcedUrl = url;
        print('SERVER: URL anunciada com sucesso: $url');

        // IMPORTANTE: Avisar o Hub sobre a nova URL de túnel
        if (Platform.environment['HUB_URL'] != null) {
          _cluster.updateRegistration(wsUrl: url);
          print('SERVER: Hub notificado sobre a nova URL pública.');
        }

        return Response.ok(jsonEncode({'status': 'success', 'url': url}));
      }
      return Response.badRequest(body: 'Missing "url" in JSON body');
    } catch (e) {
      return Response.badRequest(body: 'Invalid JSON');
    }
  });

  router.get('/api/health', (Request request) async {
    final health = {
      'status': 'ok',
      'uptime': DateTime.now().difference(_startTime).toString(),
      'region': Platform.environment['REGION'] ?? 'default',
      'ai_version': '1.0.0', // Pode ser dinâmico no futuro
      'last_announce': _announcedUrl,
      'memory_usage': ProcessInfo.currentRss,
    };
    return Response.ok(jsonEncode(health));
  });

  // Bulk Import via Invoice handler
  router.post('/bulk-import/invoice', (Request request) async {
    try {
      final body = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(body);
      final url = data['url'] as String?;
      final locationId = data[fieldLocationId] as String?;
      final signature = data[fieldSignature] as String?;
      final timestamp = data[fieldTimestamp] as String?;
      final messageId = data[fieldMessageId] as String?;

      if (url == null ||
          locationId == null ||
          signature == null ||
          timestamp == null ||
          messageId == null) {
        return Response.badRequest(body: 'Missing required fields');
      }

      final serverLocationId = Platform.environment['LOCATION_ID'] ?? '';
      final locationPassword = Platform.environment['LOCATION_PASSWORD'] ?? '';

      // Verify operator identity
      if (locationId != serverLocationId || locationPassword.isEmpty) {
        return Response.forbidden('Unauthorized: invalid locationId');
      }

      final messageToSign = '$url$timestamp$messageId';
      final key = utf8.encode(locationPassword);
      final hmac = Hmac(sha256, key);
      final expectedSignature = hmac
          .convert(utf8.encode(messageToSign))
          .toString();

      if (signature != expectedSignature) {
        return Response.forbidden('Unauthorized: invalid signature');
      }

      final items = await _invoiceService.processInvoiceUrl(url);
      if (items.isEmpty) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'count': 0,
            'message': 'Nenhum item novo encontrado ou nota já processada.',
          }),
        );
      }

      for (var item in items) {
        final update = {
          'barcode': item.barcode,
          'locationId': locationId,
          'price': item.price,
          'timestamp': DateTime.now().toIso8601String(),
          'messageId': const Uuid().v4(),
          'verificationLevel': 2, // Oficial (Operator)
        };

        // Broadcast locally with official badge
        final broadcastMsg = {
          fieldType: 'price_update',
          fieldPayload: update,
          fieldTimestamp: update['timestamp'],
          fieldMessageId: update['messageId'],
          'isOfficial': true,
        };

        // Assinar o broadcast para outros servidores confiarem
        final broadcastPayloadString = jsonEncode(update);
        final broadcastMessageToSign =
            '$broadcastPayloadString${update['timestamp']}${update['messageId']}';
        final broadcastSignature = hmac
            .convert(utf8.encode(broadcastMessageToSign))
            .toString();
        broadcastMsg[fieldSignature] = broadcastSignature;

        _broadcast(jsonEncode(broadcastMsg));

        // Publish to Hub
        if (Platform.environment['HUB_URL'] != null) {
          _cluster.publish('region/${_cluster.region}', broadcastMsg);
        }

        // Trigger AI registration if unknown (proactive)
        // Passamos item.name como hintName para acelerar o cadastro
        unawaited(
          _triggerAISearchIfMissing(item.barcode, request, hintName: item.name),
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'count': items.length,
          'message': 'Carga de preços concluída com sucesso.',
        }),
      );
    } catch (e) {
      print('SERVER ERROR in bulk-import/invoice: $e');
      return Response.internalServerError(body: 'Erro ao processar nota: $e');
    }
  });

  // Bulk Import via XML (NF-e/NFC-e)
  router.post('/bulk-import/xml', (Request request) async {
    try {
      final body = await request.readAsString();
      final Map<String, dynamic> data = jsonDecode(body);
      final xml = data['xml'] as String?;
      final locationId = data[fieldLocationId] as String?;
      final signature = data[fieldSignature] as String?;
      final timestamp = data[fieldTimestamp] as String?;
      final messageId = data[fieldMessageId] as String?;

      if (xml == null ||
          locationId == null ||
          signature == null ||
          timestamp == null ||
          messageId == null) {
        return Response.badRequest(body: 'Missing required fields');
      }

      final serverLocationId = Platform.environment['LOCATION_ID'] ?? '';
      final locationPassword = Platform.environment['LOCATION_PASSWORD'] ?? '';

      // Verify operator identity
      if (locationId != serverLocationId || locationPassword.isEmpty) {
        return Response.forbidden('Unauthorized: invalid locationId');
      }

      // Validar assinatura: xml + timestamp + messageId
      final messageToSign = '$xml$timestamp$messageId';
      final key = utf8.encode(locationPassword);
      final hmac = Hmac(sha256, key);
      final expectedSignature = hmac
          .convert(utf8.encode(messageToSign))
          .toString();

      if (signature != expectedSignature) {
        return Response.forbidden('Unauthorized: invalid signature');
      }

      final items = _invoiceService.processInvoiceXml(xml);
      if (items.isEmpty) {
        return Response.ok(
          jsonEncode({
            'success': true,
            'count': 0,
            'message': 'Nenhum item válido encontrado no XML.',
          }),
        );
      }

      for (var item in items) {
        final update = {
          'barcode': item.barcode,
          'locationId': locationId,
          'price': item.price,
          'timestamp': DateTime.now().toIso8601String(),
          'messageId': const Uuid().v4(),
          'verificationLevel': 2, // Oficial (Operator)
        };

        // Broadcast locally with official badge
        final broadcastMsg = {
          fieldType: 'price_update',
          fieldPayload: update,
          fieldTimestamp: update['timestamp'],
          fieldMessageId: update['messageId'],
          'isOfficial': true,
        };

        // Assinar o broadcast para outros servidores confiarem
        final broadcastPayloadString = jsonEncode(update);
        final broadcastMessageToSign =
            '$broadcastPayloadString${update['timestamp']}${update['messageId']}';
        final broadcastSignature = hmac
            .convert(utf8.encode(broadcastMessageToSign))
            .toString();
        broadcastMsg[fieldSignature] = broadcastSignature;

        _broadcast(jsonEncode(broadcastMsg));

        // Publish to Hub
        if (Platform.environment['HUB_URL'] != null) {
          _cluster.publish('region/${_cluster.region}', broadcastMsg);
        }

        // Trigger AI registration if unknown (proactive)
        unawaited(
          _triggerAISearchIfMissing(item.barcode, request, hintName: item.name),
        );
      }

      return Response.ok(
        jsonEncode({
          'success': true,
          'count': items.length,
          'message': 'Carga de preços via XML concluída com sucesso (${items.length} itens).',
        }),
      );
    } catch (e) {
      print('SERVER ERROR in bulk-import/xml: $e');
      return Response.internalServerError(body: 'Erro ao processar arquivo XML: $e');
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
Future<void> _triggerAISearchIfMissing(
  String barcode,
  Request request, {
  String? hintName,
  bool force = false,
}) async {
  // Se não for forçado, espera um pouco para ver se outro servidor responde
  if (!force) {
    await Future.delayed(const Duration(seconds: 3));
  } else {
    print('AI: Forçando re-cadastro para o barcode $barcode');
  }

  final metadata = await _metadataService.fetchAndRegisterProduct(
    barcode,
    hintName: hintName,
    force: force,
  );
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
