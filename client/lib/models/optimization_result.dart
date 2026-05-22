import '../models/location_model.dart';
import '../models/price_update.dart';
import '../models/shopping_list_item.dart';

class OptimizedStore {
  final LocationModel location;
  final List<OptimizedItem> items;
  final double subtotal;

  OptimizedStore({
    required this.location,
    required this.items,
    required this.subtotal,
  });
}

class OptimizedItem {
  final ShoppingListItem listItem;
  final PriceUpdate priceUpdate;
  final double totalPrice;

  OptimizedItem({
    required this.listItem,
    required this.priceUpdate,
    required this.totalPrice,
  });
}

class OptimizationResult {
  final List<OptimizedStore> stores;
  final double totalValue;
  final double estimatedSavings; // Comparado com a média ou maior preço
  final List<ShoppingListItem> missingItems;

  OptimizationResult({
    required this.stores,
    required this.totalValue,
    required this.estimatedSavings,
    required this.missingItems,
  });
}
