import 'dart:convert';
import 'dart:typed_data';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

abstract class AIEngine {
  Future<void> warmup();
  Future<Map<String, dynamic>?> extractProductMetadata(String searchText);
  Future<double?> extractPriceFromImage(Uint8List imageBytes);
}

class OllamaEngine implements AIEngine {
  final String baseUrl;
  final String model;

  OllamaEngine({String? baseUrl, String? model})
    : baseUrl = baseUrl ?? 'http://localhost:11434',
      model = model ?? 'llama3.2:3b';

  @override
  Future<void> warmup() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/generate'),
            body: jsonEncode({
              'model': model,
              'prompt':
                  'Bom dia! Apenas responda "Bom dia" para confirmar que você está pronto.',
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 5)); // Reduzido para fail-fast

      if (response.statusCode == 200) {
        print('AI: Ollama aquecido com sucesso em $baseUrl');
      }
    } catch (e) {
      // Log conciso para não poluir o Standalone Mode
      print('AI: IA local indisponível em $baseUrl (Modo Standalone Ativo)');
    }
  }

  @override
  Future<double?> extractPriceFromImage(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);

    // Prompt focado em extração de preço
    final prompt = '''
Extract the numeric price from this supermarket label. 
Return ONLY a JSON object with the field "price" (number). 
Example: {"price": 10.99}
If no price is found, return {"price": null}.
''';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'images': [base64Image],
          'stream': false,
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final resp = jsonDecode(data['response']);
        return double.tryParse(resp['price']?.toString() ?? '');
      }
    } catch (e) {
      print('Ollama Vision Error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> extractProductMetadata(
    String searchText,
  ) async {
    final prompt =
        '''
Extract product information from the following search results for a specific barcode.

CRITICAL RULES:
1. The product MUST match the intended barcode. If the results are clearly for a different product or barcode, return {"error": "mismatch"}.
2. If you are unsure or the results are contradictory, return {"error": "low_confidence"}.
3. name: Full descriptive name of the product (in Portuguese if possible).
4. unit: Quantity and unit combined (e.g., "12 unidades", "1kg", "500ml").
5. manufacturer: Brand or manufacturer name.

Search Results:
$searchText

JSON Output:
''';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return jsonDecode(data['response']);
      }
    } catch (e) {
      print('Ollama Error: $e');
    }
    return null;
  }
}

class GeminiEngine implements AIEngine {
  final String apiKey;
  final String modelName;

  GeminiEngine({required this.apiKey, this.modelName = 'gemini-1.5-flash'});

  @override
  Future<void> warmup() async {
    print('AI: Aquecendo Gemini Engine...');
    try {
      final model = GenerativeModel(model: modelName, apiKey: apiKey);
      await model.generateContent([Content.text('Ping')]);
      print('AI: Gemini pronto.');
    } catch (e) {
      print('AI: Erro no warmup do Gemini: $e');
    }
  }

  @override
  Future<double?> extractPriceFromImage(Uint8List imageBytes) async {
    final model = GenerativeModel(model: modelName, apiKey: apiKey);
    final prompt = '''
Extract the numeric price from this supermarket label. 
Return ONLY a JSON object with the field "price" (number). 
Example: {"price": 10.99}
If no price is found, return {"price": null}.
''';

    try {
      final content = [
        Content.multi([TextPart(prompt), DataPart('image/jpeg', imageBytes)]),
      ];
      final response = await model.generateContent(content);
      final text = response.text;
      if (text != null) {
        final jsonString = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final data = jsonDecode(jsonString);
        return double.tryParse(data['price']?.toString() ?? '');
      }
    } catch (e) {
      print('Gemini Vision Error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, dynamic>?> extractProductMetadata(
    String searchText,
  ) async {
    final model = GenerativeModel(model: modelName, apiKey: apiKey);
    final prompt =
        '''
Extract product information from the following search results for a specific barcode.

CRITICAL RULES:
1. The product MUST match the intended barcode. If the results are clearly for a different product or barcode, return {"error": "mismatch"}.
2. If you are unsure or the results are contradictory, return {"error": "low_confidence"}.
3. name: Full descriptive name of the product (in Portuguese if possible).
4. unit: Quantity and unit combined (e.g., "12 unidades", "1kg", "500ml").
5. manufacturer: Brand or manufacturer name.

Search Results:
$searchText
''';

    try {
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      final text = response.text;
      if (text != null) {
        // Clean markdown if present
        final jsonString = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        return jsonDecode(jsonString);
      }
    } catch (e) {
      print('Gemini Error: $e');
    }
    return null;
  }
}
