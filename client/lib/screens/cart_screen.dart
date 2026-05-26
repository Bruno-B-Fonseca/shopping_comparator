import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/cart_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/shopping_list_provider.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../widgets/empty_state_widget.dart';
import '../models/cart_item.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final budget = ref.watch(budgetProvider);
    final total = ref.watch(cartProvider.notifier).total;
    final remaining = budget - total;

    final currencyFormat = NumberFormat.currency(
      locale: 'pt_BR',
      symbol: 'R\$',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.save_as),
              onPressed: () => _showSaveAsListDialog(context, ref, cartItems),
              tooltip: 'Salvar como Lista',
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => ref.read(cartProvider.notifier).clear(),
            tooltip: 'Limpar Carrinho',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Valor Limite',
                    prefixText: 'R\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => ref.read(budgetProvider.notifier).state =
                      double.tryParse(value) ?? 0.0,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        child: ListTile(
                          title: const Text('Total'),
                          subtitle: Text(currencyFormat.format(total)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        child: ListTile(
                          title: const Text('Restante'),
                          subtitle: Text(
                            currencyFormat.format(remaining),
                            style: TextStyle(
                              color: remaining >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          cartItems.isEmpty
              ? Expanded(
                  child: EmptyStateWidget(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Carrinho vazio',
                    description:
                        'Comece adicionando produtos para comparar preços',
                    buttonLabel: 'Continuar comprando',
                    onButtonPressed: () {
                      ref.read(navigationProvider.notifier).state = 0;
                    },
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (context, index) {
                      final item = cartItems[index];
                      final product = StorageService.products.get(item.barcode);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          backgroundImage: product?.photoUrl != null
                              ? NetworkImage(
                                  ImageService.sanitizeUrl(product!.photoUrl!),
                                )
                              : null,
                          child: product?.photoUrl == null
                              ? const Icon(Icons.shopping_bag)
                              : null,
                        ),
                        title: Text(product?.name ?? 'Unknown Product'),
                        subtitle: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .updateQuantity(index, -1),
                            ),
                            Text('${item.quantity.toInt()}'),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => ref
                                  .read(cartProvider.notifier)
                                  .updateQuantity(index, 1),
                            ),
                          ],
                        ),
                        trailing: Text(
                          currencyFormat.format(item.total),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }

  void _showSaveAsListDialog(
    BuildContext context,
    WidgetRef ref,
    List<CartItem> items,
  ) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salvar como Lista'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Nome da Lista',
            hintText: 'Ex: Compras do Mês',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                await ref
                    .read(shoppingListProvider.notifier)
                    .createListFromCart(name, items);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lista "$name" criada com sucesso!')),
                  );
                }
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
