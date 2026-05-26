import 'dart:typed_data';
import 'dart:io';
import 'ai_service.dart';

/// Service responsible for processing images to extract price information.
class PriceProcessor {
  final AIEngine? aiEngine;

  PriceProcessor({this.aiEngine});

  /// Analyzes the image bytes and returns the detected price.
  /// Strategy: Tesseract OCR (Fast) -> AI Vision (Precise fallback)
  Future<double?> processImage(Uint8List imageBytes) async {
    // 1. Try Fast Tesseract OCR
    final ocrPrice = await _processWithTesseract(imageBytes);
    if (ocrPrice != null) {
      print('PriceProcessor: Preço detectado via Tesseract: $ocrPrice');
      return ocrPrice;
    }

    // 2. Fallback to AI Vision (Multi-modal) se disponível
    if (aiEngine != null) {
      print('PriceProcessor: Tesseract falhou. Disparando fallback para IA...');
      final aiPrice = await aiEngine!.extractPriceFromImage(imageBytes);
      if (aiPrice != null) {
        print('PriceProcessor: Preço detectado via IA: $aiPrice');
        return aiPrice;
      }
    } else {
      print('PriceProcessor: Tesseract falhou e IA local não disponível.');
    }

    return null;
  }

  Future<double?> _processWithTesseract(Uint8List imageBytes) async {
    final tempDir = await Directory.systemTemp.createTemp('tesseract_');
    final tempImage = File('${tempDir.path}/label.jpg');
    final tempText = File('${tempDir.path}/label');

    try {
      await tempImage.writeAsBytes(imageBytes);

      final result = await Process.run('tesseract', [
        tempImage.path,
        tempText.path,
        '-l', 'por',
      ]);

      if (result.exitCode != 0) return null;

      final text = await File('${tempText.path}.txt').readAsString();
      return _parsePrice(text);
    } catch (e) {
      return null;
    } finally {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    }
  }

  double? _parsePrice(String text) {
    // Looks for patterns like "10,00", "10.00", "R$ 10,00"
    final RegExp priceRegex = RegExp(r'(?:R\$\s?)?(\d+[\.,]\d{2})');
    final match = priceRegex.firstMatch(text);
    if (match != null) {
      final String priceString = match.group(1)!.replaceAll(',', '.');
      return double.tryParse(priceString);
    }
    return null;
  }
}
