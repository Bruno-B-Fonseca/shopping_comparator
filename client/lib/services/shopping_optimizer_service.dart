import 'dart:math';
import '../models/optimization_result.dart';
import '../models/price_update.dart';
import '../models/shopping_list.dart';
import '../models/shopping_list_item.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';

class ShoppingOptimizerService {
  static const double maxDistanceKm = 7.0;

  /// Otimiza a lista de compras baseada nos preços locais.
  static Future<OptimizationResult> optimize(ShoppingList list) async {
    final currentPosition = await LocationService.getCurrentPosition();
    if (currentPosition == null) {
      return OptimizationResult(
        stores: [],
        totalValue: 0,
        estimatedSavings: 0,
        missingItems: list.items,
      );
    }

    final userLat = currentPosition.latitude;
    final userLng = currentPosition.longitude;

    // 1. Filtrar locais num raio de 7km
    final nearbyLocations = StorageService.locations.values.where((loc) {
      final dist = _calculateDistance(userLat, userLng, loc.latitude, loc.longitude);
      return dist <= maxDistanceKm;
    }).toList();

    if (nearbyLocations.isEmpty) {
      return OptimizationResult(
        stores: [],
        totalValue: 0,
        estimatedSavings: 0,
        missingItems: list.items,
      );
    }

    final nearbyLocationIds = nearbyLocations.map((l) => l.id).toSet();

    // 2. Mapear itens da lista para os melhores preços nos locais próximos
    final Map<String, List<PriceUpdate>> itemPrices = {};
    final List<ShoppingListItem> missingItems = [];
    
    for (var item in list.items) {
      if (item.isChecked) continue;

      // Busca preços para este item (por barcode ou nome/categoria futuramente)
      // Por enquanto, focamos em barcode para precisão
      final prices = StorageService.prices.values.where((p) {
        final matchesItem = (item.barcode != null && p.barcode == item.barcode) || 
                           (p.barcode == item.barcode); // TODO: Melhorar matching semântico
        return matchesItem && nearbyLocationIds.contains(p.locationId);
      }).toList();

      if (prices.isEmpty) {
        missingItems.add(item);
      } else {
        itemPrices[item.id] = prices..sort((a, b) => a.price.compareTo(b.price));
      }
    }

    // 3. Estratégia Simples: Gananciosa (Menor preço por item)
    // Agrupa os itens pelo local que oferece o menor preço
    final Map<String, List<OptimizedItem>> storeAssignments = {};
    double totalValue = 0;
    double potentialSavings = 0;

    for (var entry in itemPrices.entries) {
      final itemId = entry.key;
      final prices = entry.value;
      final listItem = list.items.firstWhere((it) => it.id == itemId);
      
      final bestPrice = prices.first;
      final worstPrice = prices.last;
      
      final optimizedItem = OptimizedItem(
        listItem: listItem,
        priceUpdate: bestPrice,
        totalPrice: bestPrice.price * listItem.quantity,
      );

      storeAssignments.putIfAbsent(bestPrice.locationId, () => []).add(optimizedItem);
      totalValue += optimizedItem.totalPrice;
      
      // Economia estimada em relação ao maior preço encontrado na região
      potentialSavings += (worstPrice.price - bestPrice.price) * listItem.quantity;
    }

    // 4. Formatar resultado
    final List<OptimizedStore> optimizedStores = [];
    for (var entry in storeAssignments.entries) {
      final locationId = entry.key;
      final items = entry.value;
      final location = nearbyLocations.firstWhere((l) => l.id == locationId);
      
      optimizedStores.add(OptimizedStore(
        location: location,
        items: items,
        subtotal: items.fold(0, (sum, it) => sum + it.totalPrice),
      ));
    }

    // Ordena lojas pelo subtotal (maiores compras primeiro)
    optimizedStores.sort((a, b) => b.subtotal.compareTo(a.subtotal));

    return OptimizationResult(
      stores: optimizedStores,
      totalValue: totalValue,
      estimatedSavings: potentialSavings,
      missingItems: missingItems,
    );
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}
