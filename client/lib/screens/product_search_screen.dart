import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/price_update.dart';
import '../models/location_model.dart';
import '../providers/auth_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/product_image_picker.dart';
import '../widgets/category_tag_input.dart';
import '../widgets/nutritional_info_input.dart';
import 'scan_screen.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() =>
      _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pesquisa de Produtos'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Nome, fabricante, local ou código...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
              ),
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
            ),
          ),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: StorageService.products.listenable(),
        builder: (context, Box<Product> productBox, _) {
          return ValueListenableBuilder(
            valueListenable: StorageService.prices.listenable(),
            builder: (context, Box<PriceUpdate> priceBox, _) {
              return ValueListenableBuilder(
                valueListenable: StorageService.locations.listenable(),
                builder: (context, Box<LocationModel> locBox, _) {
                  final results = _getFilteredResults(
                    productBox,
                    priceBox,
                    locBox,
                  );

                  if (results.isEmpty) {
                    return EmptyStateWidget(
                      icon: _query.isEmpty ? Icons.search : Icons.search_off,
                      title: _query.isEmpty
                          ? 'Pesquisar Produtos'
                          : 'Nenhum produto encontrado',
                      description: _query.isEmpty
                          ? 'Digite o nome, fabricante ou código de barras'
                          : 'Tente outros termos para sua busca',
                    );
                  }

                  return ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return _ProductResultTile(item: item);
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  List<_SearchResult> _getFilteredResults(
    Box<Product> productBox,
    Box<PriceUpdate> priceBox,
    Box<LocationModel> locBox,
  ) {
    if (_query.isEmpty) return [];

    final matchingLocations = locBox.values
        .where((loc) => loc.name.toLowerCase().contains(_query))
        .map((loc) => loc.id)
        .toSet();

    return productBox.values
        .where((p) {
          final matchesProduct =
              p.name.toLowerCase().contains(_query) ||
              p.manufacturer.toLowerCase().contains(_query) ||
              p.barcode.contains(_query) ||
              (p.canonicalCategory?.toLowerCase().contains(_query) ?? false);

          if (matchesProduct) return true;

          final hasMatchingLocation = priceBox.values.any(
            (price) =>
                price.barcode == p.barcode &&
                matchingLocations.contains(price.locationId),
          );

          return hasMatchingLocation;
        })
        .map((p) {
          final productPrices = priceBox.values
              .where((price) => price.barcode == p.barcode)
              .toList();

          PriceUpdate? lowestPrice;
          LocationModel? location;

          if (productPrices.isNotEmpty) {
            productPrices.sort((a, b) => a.price.compareTo(b.price));
            lowestPrice = productPrices.first;
            location = locBox.get(lowestPrice.locationId);
          }

          return _SearchResult(
            product: p,
            lowestPrice: lowestPrice,
            location: location,
          );
        })
        .toList();
  }
}

class _SearchResult {
  final Product product;
  final PriceUpdate? lowestPrice;
  final LocationModel? location;

  _SearchResult({required this.product, this.lowestPrice, this.location});
}

class _ProductResultTile extends ConsumerWidget {
  final _SearchResult item;

  const _ProductResultTile({required this.item});

  void _forceReRegistration(BuildContext context, WidgetRef ref, String barcode) {
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
              StorageService.products.delete(barcode);
              final ws = ref.read(webSocketServiceProvider);
              ws.sendMessage({'type': 'gpi_delete', 'barcode': barcode});
              ws.sendMessage({
                'type': 'product_request',
                'payload': {'barcode': barcode, 'force': true},
              });
              Navigator.pop(ctx);
              Navigator.pop(context);
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

  void _showEditProductDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: item.product.name);
    final manufacturerController = TextEditingController(
      text: item.product.manufacturer,
    );
    final unitController = TextEditingController(text: item.product.unit);
    final categoryController = TextEditingController(
      text: item.product.canonicalCategory ?? '',
    );
    final nutritionController = TextEditingController(
      text: item.product.nutritionalInfo ?? '',
    );
    String? currentPhotoUrl = item.product.photoUrl;

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
                onPressed: () => _forceReRegistration(context, ref, item.product.barcode),
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
                  initialValue: item.product.canonicalCategory,
                  onChanged: (value) {
                    categoryController.text = value;
                  },
                ),
                const SizedBox(height: 16),
                NutritionalInfoInput(
                  initialValue: item.product.nutritionalInfo,
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
                final updatedProduct = Product(
                  barcode: item.product.barcode,
                  name: nameController.text.trim(),
                  manufacturer: manufacturerController.text.trim(),
                  unit: unitController.text.trim(),
                  nutritionalInfo: nutritionController.text.trim(),
                  photoUrl: currentPhotoUrl,
                  isVerified: item.product.isVerified,
                  canonicalCategory: categoryController.text.trim().isEmpty
                      ? null
                      : categoryController.text.trim(),
                  updatedAt: DateTime.now(),
                );

                StorageService.products.put(
                  item.product.barcode,
                  updatedProduct,
                );

                Navigator.pop(context);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOperator = ref.watch(authProvider).isOperator;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  backgroundImage: item.product.photoUrl != null
                      ? NetworkImage(
                          ImageService.sanitizeUrl(item.product.photoUrl!),
                        )
                      : null,
                  child: item.product.photoUrl == null
                      ? const Icon(Icons.shopping_bag)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.product.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (item.product.isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.verified, color: Colors.blue, size: 16),
                            ),
                          if (item.product.isLocal)
                            Padding(
                              padding: EdgeInsets.only(left: 4.0),
                              child: Tooltip(
                                message: 'Produção Local / Artesanal',
                                child: Icon(Icons.home_work, color: Colors.orange.shade700, size: 16),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${item.product.manufacturer}${item.product.canonicalCategory != null ? ' • ${item.product.canonicalCategory}' : ''} • ${item.product.unit}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (item.product.nutritionalInfo != null &&
                          item.product.nutritionalInfo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            item.product.nutritionalInfo!,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.product.barcode,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isOperator)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _showEditProductDialog(context, ref),
                            tooltip: 'Editar Produto',
                            color: colorScheme.primary,
                          ),
                        IconButton.filledTonal(
                          icon: const Icon(Icons.add_shopping_cart, size: 20),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ScanScreen(
                                  initialBarcode: item.product.barcode,
                                ),
                              ),
                            );
                          },
                          tooltip: 'Informar Preço / Adicionar',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (item.lowestPrice != null && item.location != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(76),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sell, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'R\$ ${item.lowestPrice!.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            if (item.lowestPrice!.verificationLevel == 2)
                              const Padding(
                                padding: EdgeInsets.only(left: 6.0),
                                child: Tooltip(
                                  message: 'Preço Oficial (Validado pelo Estabelecimento)',
                                  child: Icon(Icons.verified_user, color: Colors.blue, size: 16),
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.location!.name,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(item.lowestPrice!.timestamp),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Nenhum preço registrado ainda',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day &&
        now.month == date.month &&
        now.year == date.year) {
      return 'Hoje';
    }
    return '${date.day}/${date.month}';
  }
}
