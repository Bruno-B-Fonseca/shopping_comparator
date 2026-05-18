import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Service responsible for extracting text and price information from images.
class PriceExtractionService {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extracts text from the provided image file.
  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(
      inputImage,
    );
    return recognizedText.text;
  }

  /// Extracts potential price from text.
  double? parsePrice(String text) {
    // Basic regex for price identification (e.g., "10,00", "10.00")
    final RegExp priceRegex = RegExp(r'(\d+[\.,]\d{2})');
    final match = priceRegex.firstMatch(text);
    if (match != null) {
      final String priceString = match.group(0)!.replaceAll(',', '.');
      return double.tryParse(priceString);
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
