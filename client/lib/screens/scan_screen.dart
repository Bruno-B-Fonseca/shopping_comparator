import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product.dart';
import '../models/cart_item.dart';
import '../services/storage_service.dart';
import '../providers/cart_provider.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/barcode_scanner_widget.dart';
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

  void _lookupProduct([String? barcode]) {
    final code = barcode ?? _barcodeController.text;
    if (code.isEmpty) return;

    if (barcode != null) {
      _barcodeController.text = barcode;
    }

    final product = StorageService.products.get(code);
    setState(() {
      _currentProduct = product;
    });

    if (product == null) {
      _showRegisterDialog(code);
    }
  }

  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerWidget(
          onDetect: (barcode) {
            _lookupProduct(barcode);
          },
        ),
      ),
    );
  }

  void _showRegisterDialog(String barcode) {
    final nameController = TextEditingController();
    final unitController = TextEditingController(text: 'un');
    final manufacturerController = TextEditingController();

    String? photoUrl; // Variável local para armazenar a URL

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('New Product'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(labelText: 'Unit'),
              ),
              TextField(
                controller: manufacturerController,
                decoration: const InputDecoration(labelText: 'Manufacturer'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Photo: '),
                  ProductImagePicker(
                    onImageUploaded: (url) {
                      setDialogState(() => photoUrl = url);
                    },
                  ),
                  if (photoUrl != null) 
                    const Icon(Icons.check, color: Colors.green),
                ],
              ),
              if (photoUrl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Image.network(
                    photoUrl!,
                    height: 100,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('Failed to load preview'),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final product = Product(
                  barcode: barcode,
                  name: nameController.text,
                  unit: unitController.text,
                  manufacturer: manufacturerController.text,
                  photoUrl: photoUrl,
                );
                StorageService.products.put(barcode, product);
                setState(() {
                  _currentProduct = product;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart() {
    if (_currentProduct == null) return;
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final qty = double.tryParse(_qtyController.text) ?? 1.0;

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid price')),
      );
      return;
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
            if (_currentProduct != null) ...[
              Card(
                child: ListTile(
                  leading: _currentProduct!.photoUrl != null
                      ? Image.network(
                          _currentProduct!.photoUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.image_not_supported),
                        )
                      : const Icon(Icons.image),
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
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Price',
                        prefixText: 'R\$ ',
                      ),
                      keyboardType: TextInputType.number,
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
                description: 'Digite um código de barras ou use a câmera para procurar produtos',
                buttonLabel: 'Abrir câmera',
                onButtonPressed: _lookupProduct,
              ),
          ],
        ),
      ),
    );
  }
}
