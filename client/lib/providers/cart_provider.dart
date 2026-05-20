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

  void updateQuantity(int index, double delta) {
    final item = state[index];
    final newQuantity = (item.quantity + delta).clamp(0.1, 999.0);
    
    final newItem = CartItem(
      barcode: item.barcode,
      quantity: newQuantity,
      unitPrice: item.unitPrice,
      addedAt: item.addedAt,
    );

    StorageService.cart.putAt(index, newItem);
    state = List.from(state)..[index] = newItem;
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

final budgetProvider = StateProvider<double>((ref) => 0.0);
