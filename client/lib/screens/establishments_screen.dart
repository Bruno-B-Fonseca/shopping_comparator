import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/location_model.dart';
import '../services/storage_service.dart';
import '../services/location_service.dart';
import '../services/image_service.dart';
import '../providers/websocket_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/product_image_picker.dart';
import 'chat_screen.dart';
import 'package:uuid/uuid.dart';

class EstablishmentsScreen extends ConsumerStatefulWidget {
  const EstablishmentsScreen({super.key});

  @override
  ConsumerState<EstablishmentsScreen> createState() =>
      _EstablishmentsScreenState();
}

class _EstablishmentsScreenState extends ConsumerState<EstablishmentsScreen> {
  final _nameController = TextEditingController();
  final _perimeterController = TextEditingController(text: '100'); // metros
  String? _logoUrl;
  bool _initialDataLoaded = false;
  LatLng? _selectedPosition;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _checkAndLoadInitialData();
  }

  Future<void> _checkAndLoadInitialData() async {
    final auth = ref.read(authProvider);
    if (auth.isOperator && !_initialDataLoaded) {
      final loc = StorageService.locations.get(auth.locationId);
      if (loc != null) {
        _nameController.text = loc.name;
        double perimeter = 100.0;
        if (loc.minLat != null && loc.maxLat != null) {
          perimeter = (loc.maxLat! - loc.minLat!) * 111111;
        }
        _perimeterController.text = perimeter.toStringAsFixed(0);
        _logoUrl = loc.logoUrl;
        _selectedPosition = LatLng(loc.latitude, loc.longitude);
        _initialDataLoaded = true;
        setState(() {});
        // Garante que o mapa centralize no local carregado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final pos = _selectedPosition;
          if (pos != null && mounted) {
            _mapController.move(pos, 16.0);
          }
        });
      } else {
        await _moveToCurrentPosition();
      }
    }
  }

  Future<void> _moveToCurrentPosition() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        final latLng = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _selectedPosition = latLng;
        });
        _mapController.move(latLng, 16.0);
      }
    } catch (e) {
      debugPrint('EstablishmentsScreen: Erro ao mover para posição atual: $e');
    }
  }

  void _saveEstablishment() async {
    final name = _nameController.text;
    final perimeterMeters = double.tryParse(_perimeterController.text) ?? 100.0;
    final auth = ref.read(authProvider);

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira o nome do local')),
      );
      return;
    }

    LatLng? position = _selectedPosition;
    if (position == null) {
      try {
        final current = await LocationService.getCurrentPosition();
        if (current != null) {
          position = LatLng(current.latitude, current.longitude);
        }
      } catch (e) {
        debugPrint('EstablishmentsScreen: Erro ao obter posição para salvar: $e');
      }
    }

    if (position == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, selecione a localização no mapa'),
          ),
        );
      }
      return;
    }

    // Cálculo simples de perímetro (aproximado)
    // 1 grau lat ~ 111.111 metros
    final double degreeOffset = (perimeterMeters / 2) / 111111;
    final id = (auth.isOperator && auth.locationId != null)
        ? auth.locationId!
        : const Uuid().v4();
    final isUpdate = StorageService.locations.containsKey(id);

    final loc = LocationModel(
      id: id,
      name: name,
      latitude: position.latitude,
      longitude: position.longitude,
      logoUrl: _logoUrl,
      minLat: position.latitude - degreeOffset,
      maxLat: position.latitude + degreeOffset,
      minLong: position.longitude - degreeOffset,
      maxLong: position.longitude + degreeOffset,
      updatedAt: DateTime.now(),
    );

    await StorageService.locations.put(loc.id, loc);

    // Sincroniza via WebSocket
    ref.read(webSocketServiceProvider).sendMessage({
      'type': 'location_registration',
      'payload': loc.toJson(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdate
                ? 'Estabelecimento atualizado!'
                : 'Estabelecimento cadastrado!',
          ),
        ),
      );
      // Força recarregamento do título/botão
      setState(() => _initialDataLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isOperator = auth.isOperator;

    // Se os dados ainda não foram carregados (ex: chegaram via sync ou login mudou), tenta carregar
    if (isOperator && !_initialDataLoaded && _selectedPosition == null) {
      _checkAndLoadInitialData();
    } else if (!isOperator && _initialDataLoaded) {
      // Se deixou de ser operador, limpa o estado
      _initialDataLoaded = false;
      _nameController.clear();
      _logoUrl = null;
      _selectedPosition = null;
    }

    final double currentPerimeter =
        double.tryParse(_perimeterController.text) ?? 100.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Locais e Mercados')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (isOperator)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _initialDataLoaded
                              ? 'Alterar Local'
                              : 'Cadastrar Novo Local',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nome do Estabelecimento',
                            hintText: 'Ex: Supermercado Pão de Açúcar',
                          ),
                        ),
                        TextField(
                          controller: _perimeterController,
                          decoration: const InputDecoration(
                            labelText: 'Raio de Cobertura (metros)',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Selecione a localização exata no mapa:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: _selectedPosition ??
                                      const LatLng(-23.5505, -46.6333),
                                  initialZoom: 16.0,
                                  onTap: (_, point) {
                                    setState(() => _selectedPosition = point);
                                  },
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.app',
                                  ),
                                  if (_selectedPosition != null) ...[
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: _selectedPosition!,
                                          radius: currentPerimeter,
                                          useRadiusInMeter: true,
                                          color: Colors.blue.withAlpha(51),
                                          borderColor: Colors.blue,
                                          borderStrokeWidth: 2,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          point: _selectedPosition!,
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Positioned(
                              right: 8,
                              top: 8,
                              child: FloatingActionButton.small(
                                heroTag: 'my_location_btn',
                                onPressed: _moveToCurrentPosition,
                                child: const Icon(Icons.my_location),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Logotipo: '),
                            ProductImagePicker(
                              onImageUploaded: (url) {
                                setState(() => _logoUrl = url);
                              },
                            ),
                            if (_logoUrl != null)
                              const Icon(Icons.check_circle, color: Colors.green),
                          ],
                        ),
                        if (_logoUrl != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Image.network(
                              ImageService.sanitizeUrl(_logoUrl),
                              height: 60,
                              fit: BoxFit.contain,
                            ),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _saveEstablishment,
                          icon: Icon(
                            _initialDataLoaded
                                ? Icons.save
                                : Icons.add_location_alt,
                          ),
                          label: Text(
                            _initialDataLoaded
                                ? 'Salvar Alterações'
                                : 'Salvar Localização Atual',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ValueListenableBuilder(
              valueListenable: StorageService.locations.listenable(),
              builder: (context, Box<LocationModel> box, _) {
                final locations = box.values
                    .where((loc) => !loc.id.startsWith('private_'))
                    .toList();
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: locations.length,
                  itemBuilder: (context, index) {
                    final loc = locations[index];
                    final isOwnLocation = isOperator && loc.id == auth.locationId;

                    return ListTile(
                      leading: loc.logoUrl != null
                          ? Image.network(
                              ImageService.sanitizeUrl(loc.logoUrl),
                              width: 40,
                              height: 40,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.store),
                            )
                          : const Icon(Icons.store),
                      title: Text(loc.name),
                      subtitle: Text(
                        loc.minLat != null
                            ? 'Área Protegida (Geofence)'
                            : 'Ponto Genérico',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.blue),
                            tooltip: 'Chat do Local',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    locationId: loc.id,
                                    locationName: loc.name,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (isOwnLocation)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Excluir',
                              onPressed: () {
                                box.delete(loc.id);
                                setState(() {
                                  _initialDataLoaded = false;
                                  _nameController.clear();
                                  _logoUrl = null;
                                  _selectedPosition = null;
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
