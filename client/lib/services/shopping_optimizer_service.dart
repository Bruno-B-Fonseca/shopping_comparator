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
    
    // Cache de códigos de barra por categoria/nome para evitar buscas repetitivas
    final allProducts = StorageService.products.values.toList();

    for (var item in list.items) {
      if (item.isChecked) continue;

      List<PriceUpdate> foundPrices = [];

      // PRIORIDADE 1: Busca por Código de Barras Exato
      if (item.barcode != null) {
        foundPrices = StorageService.prices.values.where((p) {
          return p.barcode == item.barcode && nearbyLocationIds.contains(p.locationId);
        }).toList();
      }

      // PRIORIDADE 2: Busca por Categoria Canônica (se não achou por barcode)
      if (foundPrices.isEmpty && item.category != null) {
        final productsInCategory = allProducts
            .where((p) => p.canonicalCategory == item.category)
            .map((p) => p.barcode)
            .toSet();
        
        foundPrices = StorageService.prices.values.where((p) {
          return productsInCategory.contains(p.barcode) && nearbyLocationIds.contains(p.locationId);
        }).toList();
      }

      // PRIORIDADE 3: Busca por Nome (Substring) - Caso o usuário digitou apenas texto
      if (foundPrices.isEmpty) {
        final query = item.name.toLowerCase();
        final productsByName = allProducts
            .where((p) => p.name.toLowerCase().contains(query))
            .map((p) => p.barcode)
            .toSet();
        
        foundPrices = StorageService.prices.values.where((p) {
          return (productsByName.contains(p.barcode) || p.barcode.contains(query)) && 
                 nearbyLocationIds.contains(p.locationId);
        }).toList();
      }

      if (foundPrices.isEmpty) {
        missingItems.add(item);
      } else {
        itemPrices[item.id] = foundPrices..sort((a, b) => a.price.compareTo(b.price));
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
