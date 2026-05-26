import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';
import 'ai_service.dart';
import 'cluster_service.dart';
import 'search_service.dart';

class ProductMetadataService {
  final AIEngine? aiEngine; // Agora opcional
  final SearchService searchService = SearchService();
  final Minio? minio; // Agora opcional
  final String? bucketName;
  final ClusterService? clusterService;

  ProductMetadataService({
    this.aiEngine,
    this.minio,
    this.bucketName,
    this.clusterService,
  });

  Future<Map<String, dynamic>?> fetchAndRegisterProduct(
    String barcode, {
    String? hintName,
    bool force = false,
  }) async {
    if (!_isValidEan(barcode)) {
      print('AI: Ignorando código de barras inválido -> $barcode');
      return null;
    }

    print('AI: Iniciando busca para o código $barcode (Hint: ${hintName ?? 'N/A'}, Force: $force)');

    // 0. Estratégia de Excelência: Lookup no Hub (GPI) - SEMPRE PRIORITÁRIO (a menos que seja force)
    if (clusterService != null && !force) {
      print('AI: Consultando Hub (Global Product Index)...');
      final gpiData = await clusterService!.lookupGpi(barcode);
      if (gpiData != null) {
        print('AI: Metadados canônicos encontrados no GPI.');
        return gpiData;
      }
    }

    // 1. Consulta ao Open Food Facts (OFF) como fallback regional
    final offData = await _fetchFromOpenFoodFacts(barcode);
    if (offData != null) {
      final name = offData['name']?.toString().toLowerCase() ?? '';
      if (name.contains('barcode scanner')) {
        print('AI: Dados do OFF descartados (Barcode Scanner detectado).');
      } else {
        print('AI: Dados obtidos via Open Food Facts.');
        _proposeToGpi(offData);
        return offData;
      }
    }

    // Se o nó é leve e não tem IA local, paramos se não estiver no Hub/OFF.
    if (aiEngine == null) {
      print('AI: Nó leve sem IA local. Propondo cadastro ao Hub...');
      if (clusterService != null && hintName != null) {
        _proposeToGpi({'barcode': barcode, 'name': hintName});
      }
      return null;
    }

    // 2. Search Web (Último recurso para nós com IA)
    final searchQuery = hintName != null ? '$barcode $hintName' : barcode;
    final searchResults = await searchService.searchProduct(searchQuery);
    
    final dataToProcess = searchResults.isEmpty && hintName != null 
        ? 'Nome na Nota Fiscal: $hintName' 
        : searchResults;

    if (dataToProcess.isEmpty) {
      print('AI: Nenhum resultado de busca encontrado e sem hint.');
      return null;
    }

    // 3. Extract Metadata via IA local
    final metadata = await aiEngine!.extractProductMetadata(dataToProcess);
    if (metadata == null || metadata.containsKey('error')) {
      print('AI: Falha ou erro na extração de metadados: ${metadata?['error'] ?? 'null'}');
      return null;
    }

    // DESCARTA PRODUTOS INVÁLIDOS
    final name = metadata['name']?.toString().toLowerCase() ?? '';
    if (name.contains('barcode scanner')) {
      print('AI: Descartando metadados inválidos (Barcode Scanner detectado)');
      return null;
    }

    print('AI: Dados extraídos via IA local: $metadata');

    metadata['barcode'] = barcode;
    metadata['name'] ??= 'Produto Desconhecido';
    metadata['unit'] ??= 'un';
    metadata['manufacturer'] ??= 'Desconhecido';
    metadata['updatedAt'] ??= DateTime.now().toIso8601String();

    _proposeToGpi(metadata); // Sugere ao GPI para indexação
    return metadata;
  }

  void _proposeToGpi(Map<String, dynamic> metadata) {
    if (clusterService != null) {
      print('AI: Propondo novos metadados ao Global Product Index...');
      clusterService!.proposeGpi(metadata);
    }
  }

  Future<Map<String, dynamic>?> _fetchFromOpenFoodFacts(String barcode) async {
    try {
      final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final p = data['product'];

          final nutriments = p['nutriments'] ?? {};
          final energy = nutriments['energy-kcal_100g'] ?? nutriments['energy_100g'] ?? '?';
          final proteins = nutriments['proteins_100g'] ?? '?';
          final carbs = nutriments['carbohydrates_100g'] ?? '?';

          return {
            'barcode': barcode,
            'name': p['product_name'] ?? p['product_name_pt'] ?? 'Produto Desconhecido',
            'manufacturer': p['brands'] ?? 'Desconhecido',
            'unit': p['quantity'] ?? 'un',
            'photoUrl': p['image_url'] ?? p['image_front_url'],
            'nutritionalInfo': 'Calorias: ${energy}kcal | Proteínas: ${proteins}g | Carboidratos: ${carbs}g',
            'updatedAt': DateTime.now().toIso8601String(),
          };
        }
      }
    } catch (e) {
      print('OFF Error: $e');
    }
    return null;
  }

  bool _isValidEan(String barcode) {
    final cleanCode = barcode.replaceAll(RegExp(r'\D'), '');
    if (cleanCode.length != 8 && cleanCode.length != 13 && cleanCode.length != 12) {
      return false;
    }

    int sum = 0;
    for (int i = 0; i < cleanCode.length - 1; i++) {
      int digit = int.parse(cleanCode[i]);
      int weight = ((cleanCode.length - 1 - i) % 2 == 1) ? 3 : 1;
      sum += digit * weight;
    }

    int checkDigit = int.parse(cleanCode[cleanCode.length - 1]);
    int calculatedCheckDigit = (10 - (sum % 10)) % 10;

    return checkDigit == calculatedCheckDigit;
  }
}
