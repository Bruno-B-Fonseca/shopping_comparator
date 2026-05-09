import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../services/storage_service.dart';

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super(StorageService.cart.values.toList());

  void addItem(CartItem item) {
    StorageService.cart.add(item);
    state = [...state, item];
  }

  void removeItem(int index) {
    StorageService.cart.deleteAt(index);
    state = StorageService.cart.values.toList();
  }

  void clear() {
    StorageService.cart.clear();
    state = [];
  }

  double get total => state.fold(0, (sum, item) => sum + item.total);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});
