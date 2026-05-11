import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';
import '../models/product.dart';
import '../models/location_model.dart';
import '../models/price_update.dart';
import '../services/storage_service.dart';
import '../providers/websocket_provider.dart';

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

    // Escuta o stream de mensagens diretamente
    _subscription = ref.read(webSocketServiceProvider).messages.listen(
      (data) {
        try {
          final String? type = data['type'];
          debugPrint('SyncService: Mensagem recebida [$type]');

          switch (type) {
            case 'product_registration':
              _handleProductSync(data['payload']);
              break;
            case 'location_registration':
              _handleLocationSync(data['payload']);
              break;
            case 'product_request':
              _handleProductRequest(data['payload']);
              break;
            case 'price_update':
              _handlePriceSync(data['payload']);
              break;
            case 'chat_message':
              _handleChatSync(data['payload']);
              break;
            case 'relay':
              final innerPayload = data['payload'];
              if (innerPayload is Map<String, dynamic>) {
                final innerType = innerPayload['type'];
                if (innerType == 'product_registration') {
                  _handleProductSync(innerPayload['payload']);
                } else if (innerType == 'location_registration') {
                  _handleLocationSync(innerPayload['payload']);
                } else if (innerType == 'chat_message') {
                  _handleChatSync(innerPayload['payload']);
                } else if (innerType == 'product_request') {
                  _handleProductRequest(innerPayload['payload']);
                } else if (innerType == 'price_update') {
                  _handlePriceSync(innerPayload['payload']);
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
      },
      onError: (e) => debugPrint('SyncService: Erro no stream: $e'),
    );
  }

  void _handleProductSync(Map<String, dynamic> payload) {
    try {
      final product = Product.fromJson(payload);
      StorageService.products.put(product.barcode, product);
      debugPrint('SyncService: Produto sincronizado -> ${product.name}');
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar produto: $e');
    }
  }

  void _handleLocationSync(Map<String, dynamic> payload) {
    try {
      final loc = LocationModel.fromJson(payload);
      StorageService.locations.put(loc.id, loc);
      debugPrint('SyncService: Localização sincronizada -> ${loc.name}');
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar localização: $e');
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
          'SyncService: Preço sincronizado -> ${priceUpdate.barcode}: R\$ ${priceUpdate.price}');
    } catch (e) {
      debugPrint('SyncService: Erro ao sincronizar preço: $e');
    }
  }

  void _handleProductRequest(dynamic payload) {
    final String? barcode =
        (payload is Map) ? payload['barcode'] : payload?.toString();
    if (barcode == null) return;

    debugPrint('SyncService: Recebida solicitação de produto -> $barcode');
    final product = StorageService.products.get(barcode);

    if (product != null) {
      debugPrint(
          'SyncService: Enviando dados do produto encontrado -> ${product.name}');
      ref.read(webSocketServiceProvider).sendMessage({
        'type': 'product_registration',
        'payload': product.toJson(),
      });

      // Busca também o último preço conhecido para esse produto
      final prices = StorageService.prices.values
          .where((p) => p.barcode == barcode)
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (prices.isNotEmpty) {
        final lastPrice = prices.first;
        debugPrint(
            'SyncService: Enviando último preço conhecido -> R\$ ${lastPrice.price}');
        ref.read(webSocketServiceProvider).sendMessage({
          'type': 'price_update',
          'payload': lastPrice.toJson(),
        });
      }
    }
  }

  void _handleChatSync(Map<String, dynamic> payload) {
    try {
      final msg = ChatMessage.fromJson(payload);
      final msgId = msg.messageId ?? msg.id;

      if (!StorageService.messages.values
          .any((m) => (m.messageId ?? m.id) == msgId)) {
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
