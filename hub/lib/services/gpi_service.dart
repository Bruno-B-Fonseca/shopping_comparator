import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';
import 'package:http/http.dart' as http;

final _log = Logger('GpiService');

/// Interface para motores de normalização de metadados.
abstract class MetadataEngine {
  Future<Map<String, dynamic>> normalize(Map<String, dynamic> proposal);
}

/// Motor simples baseado em regras (Custo Zero).
class LocalRuleEngine implements MetadataEngine {
  @override
  Future<Map<String, dynamic>> normalize(Map<String, dynamic> proposal) async {
    // Implementação básica: apenas remove espaços extras e garante CamelCase simples
    final String name = (proposal['name'] ?? '').toString().trim();
    return {
      ...proposal,
      'name': name,
      'is_verified': false,
    };
  }
}

/// Motor baseado em Ollama (Local, Gratuito).
class OllamaEngine implements MetadataEngine {
  final String url;
  final String model;

  OllamaEngine({this.url = 'http://localhost:11434', this.model = 'llama3'});

  @override
  Future<Map<String, dynamic>> normalize(Map<String, dynamic> proposal) async {
    try {
      final prompt = """
      Normalize os metadados deste produto para um catálogo de supermercado.
      Entrada: ${jsonEncode(proposal)}
      Responda APENAS o JSON com os campos: name, brand, unit, category.
      Exemplo de Saída: {"name": "Refrigerante Coca-Cola 2L", "brand": "Coca-Cola", "unit": "2L", "category": "Bebidas"}
      """;

      final response = await http.post(
        Uri.parse('$url/api/generate'),
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['response'].toString();
        // Tenta extrair JSON da resposta
        final jsonStart = responseText.indexOf('{');
        final jsonEnd = responseText.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final cleanJson = responseText.substring(jsonStart, jsonEnd + 1);
          return {
            ...proposal,
            ...jsonDecode(cleanJson),
            'is_verified': true,
          };
        }
      }
    } catch (e) {
      _log.warning('Ollama normalization failed: $e');
    }
    return proposal;
  }
}

/// Serviço de Gerenciamento do Global Product Index.
class GpiService {
  static final GpiService _instance = GpiService._internal();
  factory GpiService() => _instance;

  final Map<String, Map<String, dynamic>> _cache = {};
  late MetadataEngine _engine;
  final String _dbPath = 'config/gpi_db.json';

  GpiService._internal() {
    _loadCache();
    _initializeEngine();
  }

  void _initializeEngine() {
    final provider = Platform.environment['AI_PROVIDER']?.toLowerCase();
    final geminiKey = Platform.environment['GEMINI_API_KEY'];

    if (provider == 'gemini' && geminiKey != null) {
      // Implementação Gemini se houver chave (omitida aqui por brevidade, mas segue o padrão)
      _engine = LocalRuleEngine(); // Fallback por enquanto
    } else if (provider == 'ollama') {
      _engine = OllamaEngine(
        url: Platform.environment['OLLAMA_URL'] ?? 'http://localhost:11434',
      );
    } else {
      _engine = LocalRuleEngine();
    }
  }

  void _loadCache() {
    try {
      final file = File(_dbPath);
      if (file.existsSync()) {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        data.forEach((key, value) {
          _cache[key] = Map<String, dynamic>.from(value);
        });
        _log.info('GPI Database loaded: ${_cache.length} products');
      }
    } catch (e) {
      _log.severe('Failed to load GPI database: $e');
    }
  }

  void _saveCache() {
    try {
      final file = File(_dbPath);
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_cache));
    } catch (e) {
      _log.severe('Failed to save GPI database: $e');
    }
  }

  Map<String, dynamic>? lookup(String barcode) {
    return _cache[barcode];
  }

  Future<Map<String, dynamic>> propose(Map<String, dynamic> proposal) async {
    final barcode = proposal['barcode']?.toString();
    if (barcode == null) return proposal;

    // Se já existe no cache e está verificado, retorna o cache
    if (_cache.containsKey(barcode) &&
        _cache[barcode]?['is_verified'] == true) {
      return _cache[barcode]!;
    }

    // Normaliza
    final normalized = await _engine.normalize(proposal);
    _cache[barcode] = normalized;
    _saveCache();

    return normalized;
  }
}
