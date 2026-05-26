/// Utilitários para validação e manipulação de códigos de barras.
class BarcodeUtils {
  /// Valida se um código de barras EAN-8 ou EAN-13 é válido usando o dígito verificador.
  static bool isValidEan(String barcode) {
    // EAN-8, EAN-13 e UPC-A (12 dígitos) são suportados por este algoritmo
    if (barcode.length != 8 && barcode.length != 13 && barcode.length != 12) {
      return false;
    }
    
    if (!RegExp(r'^\d+$').hasMatch(barcode)) {
      return false;
    }

    int sum = 0;
    // O peso alterna entre 3 e 1, começando por 3 para a posição imediatamente 
    // à esquerda do dígito verificador (da direita para a esquerda).
    for (int i = 0; i < barcode.length - 1; i++) {
      int digit = int.parse(barcode[i]);
      // Distância do dígito verificador: (barcode.length - 1 - i)
      // Se a distância for ímpar (1, 3, 5...), o peso é 3.
      // Se a distância for par (2, 4, 6...), o peso é 1.
      int weight = ((barcode.length - 1 - i) % 2 == 1) ? 3 : 1;
      sum += digit * weight;
    }

    int checkDigit = int.parse(barcode[barcode.length - 1]);
    int calculatedCheckDigit = (10 - (sum % 10)) % 10;

    return checkDigit == calculatedCheckDigit;
  }

  /// Limpa o código de barras removendo caracteres não numéricos.
  static String clean(String barcode) {
    return barcode.replaceAll(RegExp(r'\D'), '');
  }
}
