import 'dart:io';
import 'package:http/http.dart' as http;

class ImageService {
  static const String _baseUrl =
      'http://localhost:3000'; // Ajustar conforme necessário

  static Future<String?> uploadImage(File imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/products/upload-photo'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        // Assume backend retorna a URL no corpo da resposta
        final responseData = await response.stream.bytesToString();
        return responseData; // Retorna a URL da imagem
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
