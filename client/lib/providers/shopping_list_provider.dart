import 'package:client/models/cart_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../services/storage_service.dart';

class ShoppingListNotifier extends StateNotifier<List<ShoppingList>> {
  ShoppingListNotifier() : super([]) {
    _loadLists();
  }

  void _loadLists() {
    state = StorageService.shoppingLists.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<void> createList(String name, {String? color}) async {
    final newList = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      items: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      color: color,
    );
    await StorageService.shoppingLists.put(newList.id, newList);
    _loadLists();
  }

  Future<void> deleteList(String id) async {
    await StorageService.shoppingLists.delete(id);
    _loadLists();
  }

  Future<void> addItemToList(String listId, ShoppingListItem item) async {
    final list = StorageService.shoppingLists.get(listId);
    if (list != null) {
      final updatedItems = List<ShoppingListItem>.from(list.items)..add(item);
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      await StorageService.shoppingLists.put(listId, updatedList);
      _loadLists();
    }
  }

  Future<void> toggleItemCheck(String listId, String itemId) async {
    final list = StorageService.shoppingLists.get(listId);
    if (list != null) {
      final updatedItems = list.items.map((item) {
        if (item.id == itemId) {
          return item.copyWith(isChecked: !item.isChecked);
        }
        return item;
      }).toList();

      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      await StorageService.shoppingLists.put(listId, updatedList);
      _loadLists();
    }
  }

  Future<void> removeItemFromList(String listId, String itemId) async {
    final list = StorageService.shoppingLists.get(listId);
    if (list != null) {
      final updatedItems = list.items
          .where((item) => item.id != itemId)
          .toList();
      final updatedList = list.copyWith(
        items: updatedItems,
        updatedAt: DateTime.now(),
      );
      await StorageService.shoppingLists.put(listId, updatedList);
      _loadLists();
    }
  }

  Future<void> createListFromCart(String name, List<CartItem> cartItems) async {
    final listItems = cartItems.map((item) {
      final product = StorageService.products.get(item.barcode);
      return ShoppingListItem(
        id: const Uuid().v4(),
        barcode: item.barcode,
        name: product?.name ?? 'Produto ${item.barcode}',
        category: product?.canonicalCategory,
        quantity: item.quantity,
        createdAt: DateTime.now(),
      );
    }).toList();

    final newList = ShoppingList(
      id: const Uuid().v4(),
      name: name,
      items: listItems,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await StorageService.shoppingLists.put(newList.id, newList);
    _loadLists();
  }
}

final shoppingListProvider =
    StateNotifierProvider<ShoppingListNotifier, List<ShoppingList>>((ref) {
      return ShoppingListNotifier();
    });
