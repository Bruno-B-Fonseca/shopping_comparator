import 'package:client/providers/active_optimization_provider.dart';
import 'package:client/providers/cart_provider.dart';
import 'package:client/services/map_tile_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../models/price_update.dart';
import '../models/location_model.dart';
import '../widgets/empty_state_widget.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  LatLng? _userLocation;
  LatLng _currentCenter = const LatLng(-23.5505, -46.6333); // SP Default
  bool _loading = true;
  final MapController _mapController = MapController();
  String? _selectedBarcode;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Color _getPriceColor(BuildContext context, PriceUpdate price) {
    final allPrices = StorageService.prices.values.map((p) => p.price).toList();
    if (allPrices.isEmpty) return Theme.of(context).colorScheme.primary;

    final avgPrice = allPrices.reduce((a, b) => a + b) / allPrices.length;
    final diff = ((price.price - avgPrice) / avgPrice) * 100;

    if (diff <= -5) return Colors.green; // Cheapest
    if (diff >= 5) return Colors.red; // Most expensive
    return Colors.orange; // Average
  }

  Future<void> _initLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final newPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userLocation = newPos;
          _currentCenter = newPos;
          _loading = false;
        });
        _mapController.move(newPos, 15.0);
      } else {
        if (mounted) {
          setState(() {
            _loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('CompareScreen: Erro ao inicializar localização: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final cartBarcodes = cartItems.map((item) => item.barcode).toSet();
    final activeOpt = ref.watch(activeOptimizationProvider);

    // Filtra preços: se houver uma otimização ativa, mostra apenas as lojas sugeridas.
    // Caso contrário, mostra produtos do carrinho ou filtro manual.
    List<Marker> markers = [];
    List<Polyline> polylines = [];

    if (activeOpt != null) {
      // MODO ROTA: Mostra estabelecimentos otimizados e traça linha
      final List<LatLng> routePoints = [];
      if (_userLocation != null) routePoints.add(_userLocation!);

      for (var store in activeOpt.stores) {
        final point = LatLng(store.location.latitude, store.location.longitude);
        routePoints.add(point);

        markers.add(Marker(
          point: point,
          width: 100,
          height: 100,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blueAccent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                ),
                child: Text(
                  'R\$ ${store.subtotal.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.shopping_basket, color: Colors.blue, size: 36),
            ],
          ),
        ));
      }

      if (routePoints.length > 1) {
        polylines.add(Polyline(
          points: routePoints,
          color: Colors.blue.withAlpha(150),
          strokeWidth: 4,
        ));
      }
    } else {
      // MODO COMPARATIVO (Padrão)
      final filteredPrices = StorageService.prices.values.where((p) {
        if (_selectedBarcode != null) {
          return p.barcode == _selectedBarcode;
        }
        return cartBarcodes.contains(p.barcode);
      }).toList();

      markers = filteredPrices.map((price) {
        final loc = StorageService.locations.get(price.locationId);
        if (loc == null) return null;
        return Marker(
          point: LatLng(loc.latitude, loc.longitude),
          width: 80,
          height: 80,
          child: GestureDetector(
            onTap: () => _showPriceDetails(price, loc),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _getPriceColor(context, price),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'R\$ ${price.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.location_on, color: Colors.amber, size: 30),
              ],
            ),
          ),
        );
      }).whereType<Marker>().toList();
    }

    // Marcador da posição do usuário
    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(activeOpt != null ? 'Rota de Economia' : 'Comparação de Preços'),
        actions: [
          if (activeOpt != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => ref.read(activeOptimizationProvider.notifier).state = null,
              tooltip: 'Limpar Rota',
            )
          else if (cartItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<String>(
                value: _selectedBarcode,
                hint: const Text('Filtrar Produto'),
                icon: const Icon(Icons.filter_list),
                underline: const SizedBox(),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('Todos do Carrinho')),
                  ...cartItems.map((item) {
                    final product = StorageService.products.get(item.barcode);
                    return DropdownMenuItem<String>(
                      value: item.barcode,
                      child: Text(product?.name ?? item.barcode, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (value) => setState(() => _selectedBarcode = value),
              ),
            ),
        ],
      ),
      body: _loading
          ? const EmptyStateWidget(
              icon: Icons.location_searching,
              title: 'Obtendo sua localização',
              description: 'Aguarde enquanto localizamos os preços mais próximos de você',
            )
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: _currentCenter, initialZoom: 15.0),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.shopping_comparator',
                  tileProvider: HiveTileProvider(StorageService.mapTiles),
                ),
                if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _initLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  void _showPriceDetails(PriceUpdate price, LocationModel loc) {
    final product = StorageService.products.get(price.barcode);
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product?.name ?? 'Unknown Product',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('At: ${loc.name}'),
            const SizedBox(height: 10),
            Text(
              'Price: R\$ ${price.price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getPriceColor(context, price),
              ),
            ),
            Text('Updated: ${price.timestamp.toLocal()}'),
          ],
        ),
      ),
    );
  }
}
