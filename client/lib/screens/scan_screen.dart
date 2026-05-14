import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cart_item.dart';
import '../models/location_model.dart';
import '../models/price_update.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/product_image_picker.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');

  Product? _currentProduct;
  bool _isSearchingCluster = false;

  void _updatePriceFromStorage(String barcode) {
    final prices =
        StorageService.prices.values.where((p) => p.barcode == barcode).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (prices.isNotEmpty) {
      final latestPrice = prices.first.price.toStringAsFixed(2);
      if (_priceController.text != latestPrice) {
        _priceController.text = latestPrice;
      }
    }
  }

  void _lookupProduct([String? barcode]) async {
    final code = barcode ?? _barcodeController.text;
    if (code.isEmpty) return;

    if (barcode != null) {
      _barcodeController.text = barcode;
    }

    final product = StorageService.products.get(code);
    if (product != null) {
      setState(() {
        _currentProduct = product;
        _isSearchingCluster = false;
        _updatePriceFromStorage(code);
      });
      return;
    }

    // Se não encontrou localmente, busca no cluster e web
    setState(() {
      _isSearchingCluster = true;
      _currentProduct = null;
    });

    final wsService = ref.read(webSocketServiceProvider);

    // Aguarda até 2 segundos pela conexão se estiver 'connecting'
    if (wsService.currentStatus == WebSocketStatus.connecting) {
      for (
        int i = 0;
        i < 10 && wsService.currentStatus == WebSocketStatus.connecting;
        i++
      ) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }

    if (wsService.currentStatus == WebSocketStatus.connected) {
      debugPrint('ScanScreen: Solicitando produto $code ao cluster e IA...');
      wsService.sendMessage({
        'type': 'product_request',
        'payload': {'barcode': code},
      });
    } else {
      debugPrint(
        'ScanScreen: Não foi possível enviar solicitação (Status=${wsService.currentStatus})',
      );
    }

    // Aguarda até 15 segundos por uma resposta (aumentado para dar tempo à IA)
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final foundProduct = StorageService.products.get(code);
      if (foundProduct != null) {
        // Produto localizado! Agora damos mais 1 segundo pro preço chegar (mensagens separadas)
        for (int j = 0; j < 5; j++) {
          final pList = StorageService.prices.values
              .where((p) => p.barcode == code)
              .toList();
          if (pList.isNotEmpty) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }

        setState(() {
          _currentProduct = foundProduct;
          _isSearchingCluster = false;
          _updatePriceFromStorage(code);
        });

        final pricesExist = StorageService.prices.values.any(
          (p) => p.barcode == code,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                pricesExist
                    ? 'Produto localizado via cluster/IA!'
                    : 'Produto localizado (sem preço recente).',
              ),
            ),
          );
        }
        return;
      }
    }

    // Se após 15s não encontrou, informa falha
    setState(() {
      _isSearchingCluster = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Produto não localizado. Tente novamente ou verifique a conexão.',
          ),
        ),
      );
    }
  }

  Future<void> _openScanner() async {
    final String? barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerWidget()),
    );

    if (barcode != null && mounted) {
      _lookupProduct(barcode);
    }
  }

  void _addToCart() async {
    if (_currentProduct == null) return;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = double.tryParse(_qtyController.text) ?? 1.0;

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    // Registrar atualização de preço se houver localização
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      final locationId =
          '${position.latitude.toStringAsFixed(4)}_${position.longitude.toStringAsFixed(4)}';

      // Salva localização se não existir
      if (!StorageService.locations.containsKey(locationId)) {
        final loc = LocationModel(
          id: locationId,
          name: 'Supermercado Próximo',
          latitude: position.latitude,
          longitude: position.longitude,
        );
        StorageService.locations.put(locationId, loc);

        // Sincroniza localização
        ref.read(webSocketServiceProvider).sendMessage({
          'type': 'location_registration',
          'payload': loc.toJson(),
        });
      }

      final priceUpdate = PriceUpdate(
        barcode: _currentProduct!.barcode,
        locationId: locationId,
        price: price,
        timestamp: DateTime.now(),
      );

      StorageService.prices.put(
        '${priceUpdate.barcode}_$locationId',
        priceUpdate,
      );

      // Sincroniza preço
      ref.read(webSocketServiceProvider).sendMessage({
        'type': 'price_update',
        'payload': priceUpdate.toJson(),
      });
      debugPrint('Sync: Preço sincronizado com o cluster');
    }

    final cartItem = CartItem(
      barcode: _currentProduct!.barcode,
      quantity: qty,
      unitPrice: price,
      addedAt: DateTime.now(),
    );

    ref.read(cartProvider.notifier).addItem(cartItem);

    // Reset fields
    _barcodeController.clear();
    _priceController.clear();
    _qtyController.text = '1';
    setState(() {
      _currentProduct = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Added to cart')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Product')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Barcode',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: _openScanner,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => _lookupProduct(),
                ),
              ),
              keyboardType: TextInputType.number,
              onSubmitted: (_) => _lookupProduct(),
            ),
            const SizedBox(height: 20),
            if (_isSearchingCluster)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Buscando no cluster...'),
                ],
              )
            else if (_currentProduct != null) ...[
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.shopping_bag)),
                  title: Text(_currentProduct!.name),
                  subtitle: Text(
                    '${_currentProduct!.manufacturer} (${_currentProduct!.unit})',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder(
                      valueListenable: StorageService.prices.listenable(),
                      builder: (context, box, child) {
                        // Sempre atualiza o controller se o produto atual mudar ou novo preço chegar
                        _updatePriceFromStorage(_currentProduct!.barcode);
                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                decoration: const InputDecoration(
                                  labelText: 'Price',
                                  prefixText: 'R\$ ',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            ProductImagePicker(
                              onPriceDetected: (price) {
                                setState(() {
                                  _priceController.text = price.toString();
                                });
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _addToCart,
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
              ),
            ] else
              EmptyStateWidget(
                icon: Icons.qr_code_scanner,
                title: 'Comece a escanear',
                description:
                    'Digite um código de barras ou use a câmera para procurar produtos',
                buttonLabel: 'Abrir câmera',
                onButtonPressed: _openScanner,
              ),
          ],
        ),
      ),
    );
  }
}
