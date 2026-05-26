import 'dart:convert';
import 'package:html/dom.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

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

/// Interface base para Parsers de diferentes estados.
abstract class InvoiceParser {
  List<InvoiceItem> parseDocument(Document document);
}

/// Parser para SEFAZ-GO (Goiás)
class SefazGoParser implements InvoiceParser {
  @override
  List<InvoiceItem> parseDocument(Document document) {
    final items = <InvoiceItem>[];
    // Em Goiás os itens costumam estar em .listItens ou #tabResult
    final rows = document.querySelectorAll('.listItens tr, #tabResult tr, .table tr');
    
    for (var row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 3) {
        final name = cells[0].text.trim();
        final codeText = cells[1].text;
        final barcode = _extractEan(codeText);
        
        // Pega a última célula que geralmente é o valor total/unitário
        final priceText = cells.last.text.trim().replaceAll(',', '.');
        final price = double.tryParse(priceText) ?? 0.0;

        if (barcode != null && price > 0) {
          items.add(InvoiceItem(barcode: barcode, name: name, price: price));
        }
      }
    }
    return items;
  }

  String? _extractEan(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 8 && cleaned.length <= 14) return cleaned;
    return null;
  }
}

/// Parser Padrão (RS, PR, SP, MG, etc. que usam o template DeOlhoNaNota)
class SefazStandardParser implements InvoiceParser {
  @override
  List<InvoiceItem> parseDocument(Document document) {
    final items = <InvoiceItem>[];
    final rows = document.querySelectorAll('tr[id^="Item"]');
    
    for (var row in rows) {
      final name = row.querySelector('.txtTit')?.text.trim() ?? '';
      final codeText = row.querySelector('.RCod')?.text ?? '';
      final barcode = _extractEan(codeText);
      final priceText = row.querySelector('.valor')?.text.trim().replaceAll(',', '.') ?? '0';
      final price = double.tryParse(priceText) ?? 0.0;

      if (barcode != null && price > 0) {
        items.add(InvoiceItem(barcode: barcode, name: name, price: price));
      }
    }
    return items;
  }

  String? _extractEan(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 8 && cleaned.length <= 14) return cleaned;
    return null;
  }
}

/// Parser de Heurística (O "Coringa" para estados desconhecidos)
class HeuristicParser implements InvoiceParser {
  @override
  List<InvoiceItem> parseDocument(Document document) {
    final items = <InvoiceItem>[];
    final allRows = document.querySelectorAll('tr');
    
    for (var row in allRows) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 3) continue;

      String? foundBarcode;
      String? foundName;
      double? foundPrice;

      for (var cell in cells) {
        final text = cell.text.trim();
        if (text.isEmpty) continue;

        // Heurística EAN
        final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleaned.length >= 8 && cleaned.length <= 14 && foundBarcode == null) {
          foundBarcode = cleaned;
        }

        // Heurística Preço (RegEx para 0,00 ou 0.00 no final da string ou célula isolada)
        final priceRegex = RegExp(r'(\d+[\.,]\d{2})');
        final match = priceRegex.firstMatch(text);
        if (match != null && foundPrice == null) {
          foundPrice = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        }

        // Heurística Nome
        if (text.length > 10 && !text.contains(RegExp(r'^[0-9]+$')) && foundName == null) {
          foundName = text;
        }
      }

      if (foundBarcode != null && foundPrice != null) {
        items.add(InvoiceItem(
          barcode: foundBarcode, 
          name: foundName ?? 'Produto $foundBarcode', 
          price: foundPrice
        ));
      }
    }
    return items;
  }
}

class InvoiceService {
  final _logger = Logger('InvoiceService');
  final Set<String> _processedHashes = {};
  final _client = http.Client(); // Cliente persistente para manter cookies/sessão

  /// Maestro que seleciona o Parser correto.
  InvoiceParser _getParserForUrl(String url) {
    if (url.contains('sefaz.go.gov.br')) return SefazGoParser();
    // Fallback para o padrão DeOlhoNaNota
    return SefazStandardParser();
  }

  Future<List<InvoiceItem>> processInvoiceUrl(String url) async {
    final urlHash = sha256.convert(utf8.encode(url)).toString();
    if (_processedHashes.contains(urlHash)) {
      _logger.info('Nota fiscal já processada: $urlHash');
      return [];
    }

    try {
      _logger.info('Processando nota fiscal: $url');
      
      // Cabeçalhos padrão e éticos
      final headers = {
        'User-Agent': 'ShopComp-Federated-Node/1.6.0 (+https://shopcomp.org)',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9',
        'Connection': 'keep-alive',
      };

      final response = await _client.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 403) {
        _logger.warning('Acesso restrito pelo portal SEFAZ (403 Forbidden).');
        throw Exception('Este portal SEFAZ requer consulta manual ou via arquivo oficial.');
      }

      if (response.statusCode != 200) {
        throw Exception('Falha ao acessar portal SEFAZ (Erro ${response.statusCode})');
      }

      final document = parse(response.body);
      
      // 1. Tenta o Parser específico do estado
      final parser = _getParserForUrl(url);
      var items = parser.parseDocument(document);

      // 2. Se falhar, tenta o Coringa (Heurística)
      if (items.isEmpty) {
        _logger.info('Parser específico falhou. Tentando Heurística...');
        items = HeuristicParser().parseDocument(document);
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

  /// Processa o conteúdo XML oficial de uma NF-e ou NFC-e.
  List<InvoiceItem> processInvoiceXml(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      final items = <InvoiceItem>[];
      
      // Busca as tags <det> (detalhe do item na NF-e/NFC-e)
      final detTags = document.findAllElements('det');
      
      for (var det in detTags) {
        final prod = det.findElements('prod').firstOrNull;
        if (prod == null) continue;

        final name = prod.findElements('xProd').firstOrNull?.innerText.trim() ?? '';
        
        // Prioridade: cEAN -> cProd (se parecer um EAN)
        String? barcode = prod.findElements('cEAN').firstOrNull?.innerText.trim();
        if (barcode == null || barcode.isEmpty || barcode == 'SEM GTIN') {
          barcode = prod.findElements('cProd').firstOrNull?.innerText.trim();
        }

        final cleanedBarcode = _cleanBarcode(barcode ?? '');
        
        // Preço: vUnCom (valor unitário) ou vProd (valor total)
        final vUnComText = prod.findElements('vUnCom').firstOrNull?.innerText.trim() ?? '0';
        var price = double.tryParse(vUnComText) ?? 0.0;

        if (price == 0) {
          final vProdText = prod.findElements('vProd').firstOrNull?.innerText.trim() ?? '0';
          price = double.tryParse(vProdText) ?? 0.0;
        }

        if (cleanedBarcode != null && price > 0) {
          items.add(InvoiceItem(
            barcode: cleanedBarcode,
            name: name,
            price: price,
          ));
        }
      }
      
      _logger.info('Extraídos ${items.length} itens do XML da nota fiscal.');
      return items;
    } catch (e) {
      _logger.severe('Erro ao fazer parse do XML da nota fiscal: $e');
      return [];
    }
  }

  String? _cleanBarcode(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.length >= 8 && cleaned.length <= 14) return cleaned;
    return null;
  }
}
