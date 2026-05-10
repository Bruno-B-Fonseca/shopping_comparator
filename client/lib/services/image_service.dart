import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ImageService {
  static String get _baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '${uri.scheme}://${uri.host}$port';
    }
    return 'http://localhost:3000'; // Default for local mobile dev
  }

  static Future<String?> uploadImage(dynamic imageFile) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/products/upload-photo'),
      );

      if (kIsWeb) {
        // No ambiente web, imageFile deve ser Uint8List
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageFile as List<int>,
            filename: 'upload.jpg',
          ),
        );
      } else {
        // No mobile/desktop, imageFile é um File (dart:io)
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return responseData;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
