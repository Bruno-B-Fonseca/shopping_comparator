import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/cart_provider.dart';
import '../providers/navigation_provider.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../widgets/empty_state_widget.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => ref.read(cartProvider.notifier).clear(),
          ),
        ],
      ),
      body: cartItems.isEmpty
          ? EmptyStateWidget(
              icon: Icons.shopping_cart_outlined,
              title: 'Carrinho vazio',
              description: 'Comece adicionando produtos para comparar preços',
              buttonLabel: 'Continuar comprando',
              onButtonPressed: () {
                ref.read(navigationProvider.notifier).state = 0;
              },
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final product = StorageService.products.get(item.barcode);

                      return Dismissible(
                        key: Key('${item.barcode}_$index'),
                        background: Container(
                          color: Colors.red.withValues(alpha: 0.8),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Remove item?'),
                              content: const Text(
                                'This item will be removed from your cart.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          ref.read(cartProvider.notifier).removeItem(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Item removed from cart'),
                            ),
                          );
                        },
                        child: ListTile(
                          leading: product?.photoUrl != null
                              ? Image.network(
                                  ImageService.sanitizeUrl(product!.photoUrl),
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image_not_supported),
                                )
                              : const Icon(Icons.image),
                          title: Text(product?.name ?? 'Unknown Product'),
                          subtitle: Text(
                            '${item.quantity} x ${currencyFormat.format(item.unitPrice)}',
                          ),
                          trailing: Text(
                            currencyFormat.format(item.total),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total:',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        currencyFormat.format(
                          ref.read(cartProvider.notifier).total,
                        ),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
