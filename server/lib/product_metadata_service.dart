import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:minio/minio.dart';

import 'ai_service.dart';
import 'cluster_service.dart';
import 'search_service.dart';

// ignore: unused_element
class ProductMetadataService {
  final AIEngine aiEngine;
  final SearchService searchService = SearchService();
  final Minio minio;
  final String bucketName;
  final ClusterService? clusterService; // Injetado para lookup no Hub

  ProductMetadataService({
    required this.aiEngine,
    required this.minio,
    required this.bucketName,
    this.clusterService,
  });

  Future<Map<String, dynamic>?> fetchAndRegisterProduct(String barcode, {String? hintName}) async {
    print('AI: Iniciando busca para o código $barcode (Hint: ${hintName ?? 'N/A'})');

    // 0. Estratégia de Excelência: Lookup no Hub (GPI)
    if (clusterService != null) {
      print('AI: Consultando Hub (Global Product Index)...');
      final gpiData = await clusterService!.lookupGpi(barcode);
      if (gpiData != null) {
        print('AI: Metadados canônicos encontrados no GPI.');
        // Se temos um hintName e o GPI não tem categoria, poderíamos usar a IA para enriquecer, 
        // mas por enquanto confiamos no Hub.
        return gpiData;
      }
    }

    // 1. Consulta ao Open Food Facts (OFF) como fallback regional
    final offData = await _fetchFromOpenFoodFacts(barcode);
    if (offData != null) {
      print('AI: Dados obtidos via Open Food Facts.');
      _proposeToGpi(offData);
      return offData;
    }

    // 2. Search Web (Último recurso)
    // Se temos um hintName, incluímos na busca para aumentar a precisão
    final searchQuery = hintName != null ? '$barcode $hintName' : barcode;
    final searchResults = await searchService.searchProduct(searchQuery);
    
    // Se não achou nada na web mas tem o nome da nota, usamos o nome da nota como base
    final dataToProcess = searchResults.isEmpty && hintName != null 
        ? 'Nome na Nota Fiscal: $hintName' 
        : searchResults;

    if (dataToProcess.isEmpty) {
      print('AI: Nenhum resultado de busca encontrado e sem hint.');
      return null;
    }

    // 3. Extract Metadata via AI local
    final metadata = await aiEngine.extractProductMetadata(dataToProcess);
    if (metadata == null) {
      print('AI: Falha ao extrair metadados com a IA.');
      return null;
    }

    print('AI: Dados extraídos via IA local: $metadata');

    metadata['barcode'] = barcode;
    metadata['name'] ??= 'Produto Desconhecido';
    metadata['unit'] ??= 'un';
    metadata['manufacturer'] ??= 'Desconhecido';

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
    final url = 'https://world.openfoodfacts.org/api/v2/product/$barcode.json';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 1) {
        final p = data['product'];

        // Extrai info nutricional básica
        final nutriments = p['nutriments'] ?? {};
        final energy =
            nutriments['energy-kcal_100g'] ?? nutriments['energy_100g'] ?? '?';
        final proteins = nutriments['proteins_100g'] ?? '?';
        final carbs = nutriments['carbohydrates_100g'] ?? '?';

        return {
          'barcode': barcode,
          'name':
              p['product_name'] ??
              p['product_name_pt'] ??
              'Produto Desconhecido',
          'manufacturer': p['brands'] ?? 'Desconhecido',
          'unit': p['quantity'] ?? 'un',
          'photoUrl': p['image_url'] ?? p['image_front_url'],
          'nutritionalInfo':
              'Calorias: ${energy}kcal | Proteínas: ${proteins}g | Carboidratos: ${carbs}g',
        };
      }
    }
    return null;
  }
}
