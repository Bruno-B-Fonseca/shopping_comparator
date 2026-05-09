import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../models/price_update.dart';
import '../models/location_model.dart';

class CompareScreen extends ConsumerStatefulWidget {
  const CompareScreen({super.key});

  @override
  ConsumerState<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends ConsumerState<CompareScreen> {
  LatLng _currentCenter = const LatLng(-23.5505, -46.6333); // SP Default
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.getCurrentPosition();
    if (pos != null) {
      setState(() {
        _currentCenter = LatLng(pos.latitude, pos.longitude);
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prices = StorageService.prices.values.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Price Comparison')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: _currentCenter,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.shopping_comparator',
                ),
                MarkerLayer(
                  markers: prices
                      .map((price) {
                        final loc = StorageService.locations.get(
                          price.locationId,
                        );
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
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'R\$ ${price.price.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 30,
                                ),
                              ],
                            ),
                          ),
                        );
                      })
                      .whereType<Marker>()
                      .toList(),
                ),
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
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text('Updated: ${price.timestamp.toLocal()}'),
          ],
        ),
      ),
    );
  }
}
