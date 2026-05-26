import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/cart_item.dart';
import '../models/location_model.dart';
import '../models/price_update.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/consent_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';
import '../services/image_service.dart';
import '../services/reputation_service.dart';
import '../utils/barcode_utils.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/location_consent_dialog.dart';
import '../widgets/product_image_picker.dart';
import '../widgets/confidence_thermometer.dart';
import '../widgets/category_tag_input.dart';
import '../widgets/nutritional_info_input.dart';

class ScanScreen extends ConsumerStatefulWidget {
  final String? initialBarcode;
  const ScanScreen({super.key, this.initialBarcode});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _barcodeController = TextEditingController();
  final _priceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');

  Product? _currentProduct;
  bool _isSearchingCluster = false;

  void _resetScan() {
    _barcodeController.clear();
    _priceController.clear();
    _qtyController.text = '1';
    setState(() {
      _currentProduct = null;
      _isSearchingCluster = false;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialBarcode != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lookupProduct(widget.initialBarcode);
      });
    }
  }

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
    String code = barcode ?? _barcodeController.text;
    if (code.isEmpty) return;

    code = BarcodeUtils.clean(code);

    if (!BarcodeUtils.isValidEan(code)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código de barras inválido (EAN-8/13 esperado).'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (barcode != null || _barcodeController.text != code) {
      _barcodeController.text = code;
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

    // Aguarda até 15 segundos por uma resposta
    for (int i = 0; i < 30; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final foundProduct = StorageService.products.get(code);
      if (foundProduct != null) {
        // Produto localizado! 
        // Forçamos a atualização imediata do estado
        setState(() {
          _currentProduct = foundProduct;
          _isSearchingCluster = false;
          _updatePriceFromStorage(code);
        });

        // Verificamos preço
        final pList = StorageService.prices.values
            .where((p) => p.barcode == code)
            .toList();
        
        final pricesExist = pList.isNotEmpty;

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

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
    }

    // Registrar atualização de preço se houver localização
    await _getPositionWithConsent();
  }

  void _forceReRegistration(BuildContext context, String barcode) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Purga'),
        content: const Text(
          'Isso apagará os dados atuais do seu celular e do Hub, '
          'solicitando uma nova pesquisa à IA. Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Não'),
          ),
          ElevatedButton(
            onPressed: () {
              // 1. Apaga localmente
              StorageService.products.delete(barcode);
              
              // 2. Solicita novo cadastro e purga no hub
              final ws = ref.read(webSocketServiceProvider);
              
              // Avisa o hub para purgar globalmente
              ws.sendMessage({
                'type': 'gpi_delete',
                'barcode': barcode,
              });

              // Solicita nova pesquisa
              ws.sendMessage({
                'type': 'product_request',
                'payload': {'barcode': barcode, 'force': true},
              });

              Navigator.pop(ctx); // Fecha confirmação
              Navigator.pop(context); // Fecha diálogo de edição
              
              _resetScan(); // Limpa a tela de scan

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Solicitada nova pesquisa para este EAN...')),
              );
            },
            child: const Text('Sim, Resetar'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    final nameController = TextEditingController(text: product.name);
    final manufacturerController = TextEditingController(
      text: product.manufacturer,
    );
    final unitController = TextEditingController(text: product.unit);
    final categoryController = TextEditingController(
      text: product.canonicalCategory ?? '',
    );
    final nutritionController = TextEditingController(
      text: product.nutritionalInfo ?? '',
    );
    String? currentPhotoUrl = product.photoUrl;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Expanded(child: Text('Editar Produto')),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.orange),
                tooltip: 'Forçar Re-cadastro (Purga local e Hub)',
                onPressed: () => _forceReRegistration(context, product.barcode),
              ),
            ],
          ),
          content: SingleChildScrollView(

            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: currentPhotoUrl != null
                            ? NetworkImage(
                                ImageService.sanitizeUrl(currentPhotoUrl!),
                              )
                            : null,
                        child: currentPhotoUrl == null
                            ? const Icon(Icons.shopping_bag, size: 40)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: ProductImagePicker(
                          onImageUploaded: (url) {
                            setState(() {
                              currentPhotoUrl = url;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: manufacturerController,
                  decoration: const InputDecoration(labelText: 'Fabricante'),
                ),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unidade (ex: 1kg, 500ml)',
                  ),
                ),
                const SizedBox(height: 16),
                CategoryTagInput(
                  initialValue: product.canonicalCategory,
                  onChanged: (value) {
                    categoryController.text = value;
                  },
                ),
                const SizedBox(height: 16),
                NutritionalInfoInput(
                  initialValue: product.nutritionalInfo,
                  onChanged: (value) {
                    nutritionController.text = value;
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                
                if (name.toLowerCase().contains('barcode scanner')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nome de produto inválido.')),
                  );
                  return;
                }

                final updatedProduct = Product(
                  barcode: product.barcode,
                  name: name,
                  manufacturer: manufacturerController.text.trim(),
                  unit: unitController.text.trim(),
                  nutritionalInfo: nutritionController.text.trim(),
                  photoUrl: currentPhotoUrl,
                  isVerified: product.isVerified,
                  canonicalCategory: categoryController.text.trim().isEmpty
                      ? null
                      : categoryController.text.trim(),
                  updatedAt: DateTime.now(),
                );

                StorageService.products.put(product.barcode, updatedProduct);

                Navigator.pop(context);
                this.setState(() {
                  _currentProduct = updatedProduct;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Produto atualizado com sucesso!'),
                  ),
                );
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getPositionWithConsent() async {
    final consent = ref.read(consentProvider);

    if (!consent.locationConsent) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => LocationConsentDialog(
          onAllow: () async {
            Navigator.pop(context);
            await ref.read(consentProvider.notifier).setLocationConsent(true);
            if (mounted) {
              await _processWithLocation();
            }
          },
          onDeny: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Localização não autorizada. Dados não serão compartilhados com a rede.',
                ),
              ),
            );
            _processWithoutLocation();
          },
        ),
      );
    } else {
      await _processWithLocation();
    }
  }

  Future<void> _processWithLocation() async {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      final double lat = position.latitude;
      final double lng = position.longitude;

      // 1. Tenta encontrar um estabelecimento já cadastrado com perímetro (geofence)
      LocationModel? matchedLocation;
      try {
        matchedLocation = StorageService.locations.values.firstWhere(
          (loc) => loc.contains(lat, lng),
        );
      } catch (_) {
        // Nenhum local cadastrado contém esta coordenada
      }

      String locationId;
      bool shouldShare = false;

      if (matchedLocation != null) {
        locationId = matchedLocation.id;
        shouldShare = true; // Só compartilha se for local oficial
        debugPrint(
          'Geofence: Localizado estabelecimento oficial "${matchedLocation.name}"',
        );
      } else {
        // 2. Fallback: Localização privada (não compartilhada)
        locationId =
            'private_${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}';

        if (!StorageService.locations.containsKey(locationId)) {
          final loc = LocationModel(
            id: locationId,
            name: 'Local Não Registrado',
            latitude: lat,
            longitude: lng,
          );
          StorageService.locations.put(locationId, loc);
          // NÃO sincroniza localização privada
        }
        debugPrint('Geofence: Local fora de área oficial. Preço será privado.');
      }

      final isOperator = ref.read(authProvider).isOperator;

      final priceUpdate = PriceUpdate(
        barcode: _currentProduct!.barcode,
        locationId: locationId,
        price: price,
        timestamp: DateTime.now(),
        verificationLevel: isOperator ? 2 : 0,
      );

      StorageService.prices.put(
        '${priceUpdate.barcode}_$locationId',
        priceUpdate,
      );

      // Sincroniza preço APENAS se for local oficial
      if (shouldShare) {
        ref.read(webSocketServiceProvider).sendMessage({
          'type': 'price_update',
          'payload': priceUpdate.toJson(),
        });
        debugPrint('Sync: Preço oficial sincronizado com o cluster');
        ReputationService.markActivity();
      }

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

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Added to cart')));
    }
  }

  void _processWithoutLocation() {
    if (_currentProduct == null) return;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = double.tryParse(_qtyController.text) ?? 1.0;

    final cartItem = CartItem(
      barcode: _currentProduct!.barcode,
      quantity: qty,
      unitPrice: price,
      addedAt: DateTime.now(),
    );

    ref.read(cartProvider.notifier).addItem(cartItem);

    _barcodeController.clear();
    _priceController.clear();
    _qtyController.text = '1';
    setState(() {
      _currentProduct = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart (without sharing)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetScan,
            tooltip: 'Reiniciar Scan',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const ConfidenceThermometer(),
              const SizedBox(height: 20),
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
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    backgroundImage: _currentProduct!.photoUrl != null
                        ? NetworkImage(
                            ImageService.sanitizeUrl(
                              _currentProduct!.photoUrl!,
                            ),
                          )
                        : null,
                    child: _currentProduct!.photoUrl == null
                        ? const Icon(Icons.shopping_bag)
                        : null,
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(_currentProduct!.name)),
                      if (_currentProduct!.isVerified)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.verified, color: Colors.blue, size: 16),
                        ),
                      if (_currentProduct!.isLocal)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.home_work, color: Colors.orange, size: 16),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${_currentProduct!.manufacturer}${_currentProduct!.canonicalCategory != null ? ' • ${_currentProduct!.canonicalCategory}' : ''}',
                  ),
                  trailing: ref.watch(authProvider).isOperator
                      ? IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () =>
                              _showEditProductDialog(_currentProduct!),
                          tooltip: 'Editar Produto',
                        )
                      : null,
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
                        
                        // Busca se o preço mais recente é oficial
                        final latestPrice = box.values
                            .where((p) => p.barcode == _currentProduct!.barcode)
                            .toList()
                          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
                        final isOfficial = latestPrice.isNotEmpty && latestPrice.first.verificationLevel == 2;

                        return Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _priceController,
                                decoration: InputDecoration(
                                  labelText: 'Price',
                                  prefixText: 'R\$ ',
                                  suffixIcon: isOfficial 
                                    ? const Tooltip(
                                        message: 'Preço Oficial Validado',
                                        child: Icon(Icons.verified_user, color: Colors.blue, size: 20),
                                      )
                                    : null,
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
      ),
    );
  }
}
