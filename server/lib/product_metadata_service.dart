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

    // 1. Search Web
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
}
