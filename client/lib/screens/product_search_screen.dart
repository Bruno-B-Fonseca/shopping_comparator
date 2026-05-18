import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/product.dart';
import '../models/price_update.dart';
import '../models/location_model.dart';
import '../services/storage_service.dart';
import '../widgets/empty_state_widget.dart';

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

    // Busca IDs de locais que batem com a query
    final matchingLocations = locBox.values
        .where((loc) => loc.name.toLowerCase().contains(_query))
        .map((loc) => loc.id)
        .toSet();

    return productBox.values
        .where((p) {
          // Busca direta no produto
          final matchesProduct =
              p.name.toLowerCase().contains(_query) ||
              p.manufacturer.toLowerCase().contains(_query) ||
              p.barcode.contains(_query);

          if (matchesProduct) return true;

          // Busca por local (se algum preço deste produto foi registrado num local que bate com a query)
          final hasMatchingLocation = priceBox.values.any(
            (price) =>
                price.barcode == p.barcode &&
                matchingLocations.contains(price.locationId),
          );

          return hasMatchingLocation;
        })
        .map((p) {
          // Encontra o menor preço para este produto
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

class _ProductResultTile extends StatelessWidget {
  final _SearchResult item;

  const _ProductResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${item.product.manufacturer} • ${item.product.unit}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
            const SizedBox(height: 12),
            if (item.lowestPrice != null && item.location != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(
                    76,
                  ), // 0.3 * 255
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sell, size: 16, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'R\$ ${item.lowestPrice!.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(
                              Icons.store,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              item.location!.name,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
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
