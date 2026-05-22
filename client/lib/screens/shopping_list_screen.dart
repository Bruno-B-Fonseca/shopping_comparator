import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../providers/shopping_list_provider.dart';
import '../providers/optimization_provider.dart';
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
                ref.read(shoppingListProvider.notifier).createList(nameController.text);
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
      appBar: AppBar(
        title: const Text('Minhas Listas'),
      ),
      body: lists.isEmpty
          ? EmptyStateWidget(
              icon: Icons.list_alt,
              title: 'Nenhuma lista encontrada',
              description: 'Crie listas para organizar suas compras e encontrar os melhores preços.',
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
        title: Text(list.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${list.items.length} itens • Atualizada em ${_formatDate(list.updatedAt)}'),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
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
  ConsumerState<ShoppingListDetailScreen> createState() => _ShoppingListDetailScreenState();
}

class _ShoppingListDetailScreenState extends ConsumerState<ShoppingListDetailScreen> {
  final _itemController = TextEditingController();

  void _addItem() {
    if (_itemController.text.isEmpty) return;
    
    final newItem = ShoppingListItem(
      id: const Uuid().v4(),
      name: _itemController.text.trim(),
      createdAt: DateTime.now(),
    );
    
    ref.read(shoppingListProvider.notifier).addItemToList(widget.listId, newItem);
    _itemController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(shoppingListProvider).firstWhere((l) => l.id == widget.listId);

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
                  child: TextField(
                    controller: _itemController,
                    decoration: const InputDecoration(
                      hintText: 'Adicionar item (ex: Leite ou 789...)',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addItem(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: list.items.length,
              itemBuilder: (context, index) {
                final item = list.items[index];
                return ListTile(
                  leading: Checkbox(
                    value: item.isChecked,
                    onChanged: (_) => ref.read(shoppingListProvider.notifier).toggleItemCheck(list.id, item.id),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      decoration: item.isChecked ? TextDecoration.lineThrough : null,
                      color: item.isChecked ? Colors.grey : null,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => ref.read(shoppingListProvider.notifier).removeItemFromList(list.id, item.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
