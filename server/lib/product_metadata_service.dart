import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';
import 'ai_service.dart';
import 'search_service.dart';

class ProductMetadataService {
  final AIEngine aiEngine;
  final SearchService searchService = SearchService();
  final Minio minio;
  final String bucketName;

  ProductMetadataService({
    required this.aiEngine,
    required this.minio,
    required this.bucketName,
  });

  Future<Map<String, dynamic>?> fetchAndRegisterProduct(String barcode) async {
    print('AI: Iniciando busca automática para o código $barcode');

    // 0. Consulta ao Open Food Facts (OFF)
    final offData = await _fetchFromOpenFoodFacts(barcode);
    if (offData != null) {
      print('AI: Dados obtidos via Open Food Facts.');
      return offData;
    }

    // 1. Search Web (Fallback se OFF falhar)
    final searchResults = await searchService.searchProduct(barcode);
    if (searchResults.isEmpty) {
      print('AI: Nenhum resultado de busca encontrado.');
      return null;
    }

    // 2. Extract Metadata via AI
    final metadata = await aiEngine.extractProductMetadata(searchResults);
    if (metadata == null) {
      print('AI: Falha ao extrair metadados com a IA.');
      return null;
    }

    print('AI: Dados extraídos: $metadata');

    // Add the barcode to the response
    metadata['barcode'] = barcode;

    // Ensure standard fields exist
    metadata['name'] ??= 'Produto Desconhecido';
    metadata['unit'] ??= 'un';
    metadata['manufacturer'] ??= 'Desconhecido';

    return metadata;
  }

  Future<Map<String, dynamic>?> _fetchFromOpenFoodFacts(String barcode) async {
    try {
      final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final p = data['product'];
          
          // Extrai info nutricional básica
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
          };
        }
      }
    } catch (e) {
      print('AI: Erro ao consultar Open Food Facts: $e');
    }
    return null;
  }
}
