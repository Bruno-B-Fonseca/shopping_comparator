import 'dart:async';

import 'package:client/providers/consent_provider.dart';
import 'package:client/services/websocket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chat_message.dart';
import '../models/location_model.dart';
import '../models/price_update.dart';
import '../models/product.dart';
import '../providers/websocket_provider.dart';
import '../services/storage_service.dart';

class SyncService {
  final Ref ref;
  StreamSubscription? _subscription;

  SyncService(this.ref) {
    _init();
  }

  void _init() {
    debugPrint('SyncService: Iniciando escuta global...');

    // Cancela assinatura anterior se houver
    _subscription?.cancel();

    final ws = ref.read(webSocketServiceProvider);

    // Escuta o stream de mensagens diretamente
    _subscription = ws.messages.listen((data) {
      try {
        final consent = ref.read(consentProvider);
        if (!consent.privacyAcknowledged) {
          debugPrint(
            'SyncService: Ignorando mensagem (privacidade não aceita)',
          );
          return;
        }

        final String? type = data['type'];
        debugPrint('SyncService: Mensagem recebida [$type]');

        switch (type) {
          case 'product_registration':
            if (data['payload'] != null) _handleProductSync(data['payload']);
            break;
          case 'location_registration':
            if (data['payload'] != null) _handleLocationSync(data['payload']);
            break;
          case 'sync_request':
            _handleSyncRequest();
            break;
          case 'product_request':
            if (data['payload'] != null) _handleProductRequest(data['payload']);
            break;
          case 'price_update':
            if (data['payload'] != null) _handlePriceSync(data['payload']);
            break;
          case 'chat_message':
            if (data['payload'] != null) _handleChatSync(data['payload']);
            break;
          case 'relay':
            final innerPayload = data['payload'];
            if (innerPayload is Map<String, dynamic>) {
              final innerType = innerPayload['type'];
              final innerData = innerPayload['payload'];
              if (innerData == null) break;

              if (innerType == 'product_registration') {
                _handleProductSync(innerData);
              } else if (innerType == 'location_registration') {
                _handleLocationSync(innerData);
              } else if (innerType == 'chat_message') {
                _handleChatSync(innerData);
              } else if (innerType == 'product_request') {
                _handleProductRequest(innerData);
              } else if (innerType == 'price_update') {
                _handlePriceSync(innerData);
              }
            }
            break;
          default:
            if (data.containsKey('sender') && data.containsKey('text')) {
              _handleChatSync(data);
            }
        }
      } catch (e) {
        debugPrint('SyncService: Erro ao processar sincronização: $e');
      }
    }, onError: (e) => debugPrint('SyncService: Erro no stream: $e'));

    // SOLICITA SINCRONIZAÇÃO APÓS INICIAR O LISTENER
    // Fazemos um pequeno delay para garantir que o stream está "quente"
    Future.delayed(const Duration(milliseconds: 500), () {
      if (ws.currentStatus == WebSocketStatus.connected) {
        debugPrint('SyncService: Solicitando sincronização inicial...');
        ws.sendMessage({'type': 'sync_request'});
      }
    });

    // Também escuta mudanças de status para pedir sync ao reconectar
    ws.status.listen((status) {
      if (status == WebSocketStatus.connected) {
        debugPrint('SyncService: Reconexão detectada, pedindo novo sync...');
        ws.sendMessage({'type': 'sync_request'});
      }
    });
  }

  void _handleProductSync(Map<String, dynamic> payload) {
    try {
      final incoming = Product.fromJson(payload);
      
      // DESCARTA PRODUTOS INVÁLIDOS
      if (incoming.name.toLowerCase().contains('barcode scanner')) {
        debugPrint('SyncService: Descartando produto inválido -> ${incoming.barcode}');
        return;
      }

      final local = StorageService.products.get(incoming.barcode);
      if (local != null) {
        // RESOLUÇÃO DE CONFLITO
        final incomingDate = incoming.updatedAt ?? DateTime(2000);
        final localDate = local.updatedAt ?? DateTime(2000);

        // Prioridade: 1. Verificado vence não verificado. 2. Mais novo vence mais velho.
        bool incomingIsBetter = false;
        if (incoming.isVerified && !local.isVerified) {
          incomingIsBetter = true;
        } else if (incoming.isVerified == local.isVerified) {
          if (incomingDate.isAfter(localDate)) {
            incomingIsBetter = true;
          }
        }

        if (!incomingIsBetter) {
          debugPrint('SyncService: Ignorando produto antigo/não-verificado -> ${incoming.barcode}');
          return;
        }
      }

      StorageService.products.put(incoming.barcode, incoming);
      debugPrint('SyncService: Produto sincronizado (LWW) -> ${incoming.name}');
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar produto: $e');
    }
  }

  void _handleLocationSync(Map<String, dynamic> payload) {
    try {
      final incoming = LocationModel.fromJson(payload);
      
      final local = StorageService.locations.get(incoming.id);
      if (local != null) {
        final incomingDate = incoming.updatedAt ?? DateTime(2000);
        final localDate = local.updatedAt ?? DateTime(2000);

        if (incomingDate.isBefore(localDate) || incomingDate.isAtSameMomentAs(localDate)) {
          debugPrint('SyncService: Ignorando local antigo -> ${incoming.name}');
          return;
        }
      }

      StorageService.locations.put(incoming.id, incoming);
      debugPrint('SyncService: Localização sincronizada (LWW) -> ${incoming.name}');
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar localização: $e');
    }
  }

  void _handleSyncRequest() {
    debugPrint('SyncService: Recebida solicitação de sincronização global');
    final ws = ref.read(webSocketServiceProvider);

    if (ws.currentStatus != WebSocketStatus.connected) {
      debugPrint(
        'SyncService: Ignorando sync_request (WebSocket não conectado)',
      );
      return;
    }

    // 1. Enviar Locais (Apenas oficiais)
    final locations = StorageService.locations.values
        .where((loc) => !loc.id.startsWith('private_'))
        .toList();
    if (locations.isNotEmpty) {
      debugPrint(
        'SyncService: Enviando ${locations.length} locais para os pares',
      );
      for (final loc in locations) {
        ws.sendMessage({
          'type': 'location_registration',
          'payload': loc.toJson(),
        });
      }
    }

    // 2. Enviar Produtos conhecidos
    final products = StorageService.products.values.toList();
    if (products.isNotEmpty) {
      debugPrint(
        'SyncService: Enviando ${products.length} produtos para os pares',
      );
      for (final product in products) {
        ws.sendMessage({
          'type': 'product_registration',
          'payload': product.toJson(),
        });
      }
    }

    // 3. Enviar Preços conhecidos (Apenas de locais oficiais)
    final prices = StorageService.prices.values
        .where((p) => !p.locationId.startsWith('private_'))
        .toList();
    if (prices.isNotEmpty) {
      debugPrint(
        'SyncService: Enviando ${prices.length} atualizações de preço para os pares',
      );
      for (final price in prices) {
        ws.sendMessage({'type': 'price_update', 'payload': price.toJson()});
      }
    }

    // 4. Enviar Histórico do Chat/Promoções
    final messages = StorageService.messages.values.toList();
    if (messages.isNotEmpty) {
      debugPrint(
        'SyncService: Enviando ${messages.length} mensagens/promoções para os pares',
      );
      for (final msg in messages) {
        ws.sendMessage({'type': 'chat_message', 'payload': msg.toJson()});
      }
    }
  }

  void _handlePriceSync(Map<String, dynamic> payload) {
    try {
      final priceUpdate = PriceUpdate.fromJson(payload);
      StorageService.prices.put(
        '${priceUpdate.barcode}_${priceUpdate.locationId}',
        priceUpdate,
      );
      debugPrint(
        'SyncService: Preço sincronizado -> ${priceUpdate.barcode}: R\$ ${priceUpdate.price}',
      );
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar preço: $e');
    }
  }

  void _handleProductRequest(dynamic payload) {
    final String? barcode = (payload is Map)
        ? payload['barcode']
        : payload?.toString();
    if (barcode == null) return;

    debugPrint('SyncService: Recebida solicitação de produto -> $barcode');
    final product = StorageService.products.get(barcode);

    if (product != null) {
      debugPrint(
        'SyncService: Enviando dados do produto encontrado -> ${product.name}',
      );
      final ws = ref.read(webSocketServiceProvider);
      if (ws.currentStatus == WebSocketStatus.connected) {
        ws.sendMessage({
          'type': 'product_registration',
          'payload': product.toJson(),
        });

        // Busca também o último preço conhecido para esse produto
        final prices =
            StorageService.prices.values
                .where((p) => p.barcode == barcode)
                .toList()
              ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (prices.isNotEmpty) {
          final lastPrice = prices.first;
          debugPrint(
            'SyncService: Enviando último preço conhecido -> R\$ ${lastPrice.price}',
          );
          ws.sendMessage({
            'type': 'price_update',
            'payload': lastPrice.toJson(),
          });
        }
      }
    }
  }

  void _handleChatSync(Map<String, dynamic> payload) {
    try {
      final msg = ChatMessage.fromJson(payload);
      final msgId = msg.messageId ?? msg.id;

      if (!StorageService.messages.values.any(
        (m) => (m.messageId ?? m.id) == msgId,
      )) {
        StorageService.messages.add(msg);
        if (msg.priceUpdate != null) {
          final pu = msg.priceUpdate!;
          StorageService.prices.put('${pu.barcode}_${pu.locationId}', pu);
        }
      }
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar chat: $e');
    }
  }

  void dispose() {
    _subscription?.cancel();
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});
