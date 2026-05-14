import 'dart:typed_data';
import 'dart:io';
import 'ai_service.dart';

/// Service responsible for processing images to extract price information.
class PriceProcessor {
  final AIEngine aiEngine;

  PriceProcessor({required this.aiEngine});

  /// Analyzes the image bytes and returns the detected price.
  /// Strategy: Tesseract OCR (Fast) -> AI Vision (Precise fallback)
  Future<double?> processImage(Uint8List imageBytes) async {
    // 1. Try Fast Tesseract OCR
    final ocrPrice = await _processWithTesseract(imageBytes);
    if (ocrPrice != null) {
      print('PriceProcessor: Preço detectado via Tesseract: $ocrPrice');
      return ocrPrice;
    }

    // 2. Fallback to AI Vision (Multi-modal)
    print('PriceProcessor: Tesseract falhou. Disparando fallback para IA...');
    final aiPrice = await aiEngine.extractPriceFromImage(imageBytes);
    if (aiPrice != null) {
      print('PriceProcessor: Preço detectado via IA: $aiPrice');
      return aiPrice;
    }

    return null;
  }

  Future<double?> _processWithTesseract(Uint8List imageBytes) async {
    final tempImage = File('temp_label.jpg');
    await tempImage.writeAsBytes(imageBytes);
    final tempText = File('temp_label.txt');

    try {
      final result = await Process.run('tesseract', [
        tempImage.path,
        'temp_label',
        '-l', 'por',
      ]);

      if (result.exitCode != 0) return null;

      final text = await tempText.readAsString();
      return _parsePrice(text);
    } catch (e) {
      return null;
    } finally {
      if (await tempImage.exists()) await tempImage.delete();
      if (await tempText.exists()) await tempText.delete();
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
