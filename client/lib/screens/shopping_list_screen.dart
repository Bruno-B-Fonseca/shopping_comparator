import 'package:client/services/websocket_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../models/product.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/optimization_provider.dart';
import '../providers/websocket_provider.dart';
import '../services/storage_service.dart';
import '../services/image_service.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/optimization_result_dialog.dart';

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  void _showCreateListDialog() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Lista'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nome da Lista'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref
                    .read(shoppingListProvider.notifier)
                    .createList(nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(shoppingListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Listas')),
      body: lists.isEmpty
          ? EmptyStateWidget(
              icon: Icons.list_alt,
              title: 'Nenhuma lista encontrada',
              description:
                  'Crie listas para organizar suas compras e encontrar os melhores preços.',
              buttonLabel: 'Criar primeira lista',
              onButtonPressed: _showCreateListDialog,
            )
          : ListView.builder(
              itemCount: lists.length,
              itemBuilder: (context, index) {
                final list = lists[index];
                return _ShoppingListTile(list: list);
              },
            ),
      floatingActionButton: lists.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showCreateListDialog,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _ShoppingListTile extends ConsumerWidget {
  final ShoppingList list;
  const _ShoppingListTile({required this.list});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(
          list.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${list.items.length} itens • Atualizada em ${_formatDate(list.updatedAt)}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShoppingListDetailScreen(listId: list.id),
            ),
          );
        },
        onLongPress: () => _showDeleteDialog(context, ref),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Lista'),
        content: Text('Deseja realmente excluir a lista "${list.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              ref.read(shoppingListProvider.notifier).deleteList(list.id);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class ShoppingListDetailScreen extends ConsumerStatefulWidget {
  final String listId;
  const ShoppingListDetailScreen({super.key, required this.listId});

  @override
  ConsumerState<ShoppingListDetailScreen> createState() =>
      _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState
    extends ConsumerState<ShoppingListDetailScreen> {
  final _itemController = TextEditingController();
  final _focusNode = FocusNode();

  void _addItem([Product? selectedProduct]) {
    final text = _itemController.text.trim();
    if (text.isEmpty && selectedProduct == null) return;

    final String name;
    String? barcode;
    String? category;

    if (selectedProduct != null) {
      name = selectedProduct.name;
      barcode = selectedProduct.barcode;
      category = selectedProduct.canonicalCategory;
    } else {
      // Verifica se o texto é um EAN (8-14 dígitos)
      final eanRegex = RegExp(r'^[0-9]{8,14}$');
      if (eanRegex.hasMatch(text)) {
        barcode = text;
        final localProd = StorageService.products.get(barcode);
        if (localProd != null) {
          name = localProd.name;
          category = localProd.canonicalCategory;
        } else {
          name = 'Buscando: $text...';
          _requestProductFromHub(barcode);
        }
      } else {
        name = text;
      }
    }

    final newItem = ShoppingListItem(
      id: const Uuid().v4(),
      barcode: barcode,
      category: category,
      name: name,
      createdAt: DateTime.now(),
    );
    ref
        .read(shoppingListProvider.notifier)
        .addItemToList(widget.listId, newItem);
    _itemController.clear();
    _focusNode.requestFocus();
  }

  void _requestProductFromHub(String barcode) {
    final wsService = ref.read(webSocketServiceProvider);
    if (wsService.currentStatus == WebSocketStatus.connected) {
      debugPrint('ShoppingList: Solicitando produto $barcode ao Hub...');
      wsService.sendMessage({
        'type': 'product_request',
        'payload': {'barcode': barcode},
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = ref
        .watch(shoppingListProvider)
        .firstWhere((l) => l.id == widget.listId);

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              ref.read(optimizationProvider.notifier).optimizeList(list);
              showDialog(
                context: context,
                builder: (context) => const OptimizationResultDialog(),
              );
            },
            tooltip: 'Otimizar Cesta',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: RawAutocomplete<Product>(
                    textEditingController: _itemController,
                    focusNode: _focusNode,
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<Product>.empty();
                      }
                      return StorageService.products.values
                          .where((Product option) {
                            return option.name.toLowerCase().contains(
                                  textEditingValue.text.toLowerCase(),
                                ) ||
                                option.barcode.contains(textEditingValue.text);
                          })
                          .take(5);
                    },
                    displayStringForOption: (Product option) => option.name,
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Adicionar item (ex: Arroz ou 789...)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onSubmitted: (_) => _addItem(),
                          );
                        },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width - 32,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Product option = options.elementAt(index);
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: option.photoUrl != null
                                        ? NetworkImage(
                                            ImageService.sanitizeUrl(
                                              option.photoUrl!,
                                            ),
                                          )
                                        : null,
                                    child: option.photoUrl == null
                                        ? const Icon(Icons.shopping_bag)
                                        : null,
                                  ),
                                  title: Text(option.name),
                                  subtitle: Text(option.manufacturer),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    onSelected: (Product selection) => _addItem(selection),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () => _addItem(),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: StorageService.products.listenable(),
              builder: (context, Box<Product> box, _) {
                return ListView.builder(
                  itemCount: list.items.length,
                  itemBuilder: (context, index) {
                    final item = list.items[index];
                    Product? product;
                    if (item.barcode != null) {
                      product = box.get(item.barcode);
                    }

                    return ListTile(
                      leading: Checkbox(
                        value: item.isChecked,
                        onChanged: (_) => ref
                            .read(shoppingListProvider.notifier)
                            .toggleItemCheck(list.id, item.id),
                      ),
                      title: Row(
                        children: [
                          if (product != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundImage: product.photoUrl != null
                                    ? NetworkImage(
                                        ImageService.sanitizeUrl(
                                          product.photoUrl!,
                                        ),
                                      )
                                    : null,
                                child: product.photoUrl == null
                                    ? const Icon(Icons.shopping_bag, size: 14)
                                    : null,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              product?.name ?? item.name,
                              style: TextStyle(
                                decoration: item.isChecked
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: item.isChecked ? Colors.grey : null,
                              ),
                            ),
                          ),
                          if (product?.isVerified ?? false)
                            const Icon(
                              Icons.verified,
                              color: Colors.blue,
                              size: 16,
                            ),
                        ],
                      ),
                      subtitle: product != null
                          ? Text(
                              product.manufacturer,
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => ref
                            .read(shoppingListProvider.notifier)
                            .removeItemFromList(list.id, item.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
