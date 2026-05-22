import 'dart:convert';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';

class InvoiceItem {
  final String barcode;
  final String name;
  final double price;
  final String? unit;

  InvoiceItem({
    required this.barcode,
    required this.name,
    required this.price,
    this.unit,
  });

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'name': name,
        'price': price,
        'unit': unit,
      };
}

class InvoiceService {
  final _logger = Logger('InvoiceService');
  final Set<String> _processedHashes = {};

  /// Processa uma URL de NFC-e e extrai os itens.
  /// Retorna uma lista de [InvoiceItem].
  Future<List<InvoiceItem>> processInvoiceUrl(String url) async {
    // 1. Deduplicação anônima
    final urlHash = sha256.convert(utf8.encode(url)).toString();
    if (_processedHashes.contains(urlHash)) {
      _logger.info('Nota fiscal já processada: $urlHash');
      return [];
    }

    try {
      _logger.info('Processando nota fiscal: $url');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Falha ao acessar portal SEFAZ: ${response.statusCode}');
      }

      final document = parse(response.body);
      final List<InvoiceItem> items = [];

      // Este é um parser genérico e experimental. 
      // Portais SEFAZ mudam por estado (RS, SP, PR, etc.)
      // Geralmente os itens estão em uma tabela ou lista de divs.
      
      // Exemplo padrão para alguns estados (como RS/PR que usam padrões parecidos):
      // Procura por linhas que contenham códigos EAN (geralmente 13 dígitos)
      
      // TODO: Implementar adaptadores específicos por estado baseados no domínio da URL.
      
      // Tentativa 1: Seletores comuns em portais de NFC-e
      final tableRows = document.querySelectorAll('tr[id^="Item"]');
      if (tableRows.isNotEmpty) {
        for (var row in tableRows) {
          final name = row.querySelector('.txtTit')?.text.trim() ?? '';
          final codeText = row.querySelector('.RCod')?.text ?? '';
          final barcode = _extractEan(codeText);
          final priceText = row.querySelector('.valor')?.text.trim().replaceAll(',', '.') ?? '0';
          final price = double.tryParse(priceText) ?? 0.0;

          if (barcode != null && price > 0) {
            items.add(InvoiceItem(barcode: barcode, name: name, price: price));
          }
        }
      }

      // Tentativa 2: Busca genérica por padrões (fallback)
      if (items.isEmpty) {
        _logger.info('Parser específico falhou. Tentando extração genérica...');
        // Esta parte seria mais complexa, procurando por padrões de EAN e valores monetários próximos.
      }

      if (items.isNotEmpty) {
        _processedHashes.add(urlHash);
      }

      _logger.info('Extraídos ${items.length} itens da nota fiscal.');
      return items;
    } catch (e) {
      _logger.severe('Erro ao processar nota fiscal: $e');
      rethrow;
    }
  }

  String? _extractEan(String text) {
    // Remove labels comuns
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 8 && cleaned.length <= 14) {
      return cleaned;
    }
    return null;
  }
}
