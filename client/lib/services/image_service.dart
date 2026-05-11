import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ImageService {
  static String get _baseUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      final protocol = uri.scheme == 'https' ? 'https' : 'http';
      final port = uri.hasPort ? ':${uri.port}' : '';
      return '$protocol://${uri.host}$port';
    }
    return 'http://localhost:3000'; // Default for local mobile dev
  }

  /// Garante que a URL use o protocolo correto para evitar Mixed Content
  static String sanitizeUrl(String? url) {
    if (url == null) return '';
    if (kIsWeb && Uri.base.scheme == 'https' && url.startsWith('http://')) {
      return url.replaceFirst('http://', 'https://');
    }
    return url;
  }

  static Future<String?> uploadImage(Object imageSource) async {
    try {
      int? size;
      if (imageSource is Uint8List) {
        size = imageSource.length;
      } else if (imageSource is List<int>) {
        size = imageSource.length;
      } else if (imageSource.runtimeType.toString() == 'File') {
        // Fallback for non-web environments using File
        size = await (imageSource as dynamic).length();
      }

      if (size != null && size > 5 * 1024 * 1024) {
        throw Exception('A imagem é muito grande. O limite máximo é de 5MB.');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/products/upload-photo'),
      );

      if (kIsWeb) {
        if (imageSource is Uint8List || imageSource is List<int>) {
          request.files.add(
            http.MultipartFile.fromBytes(
              'image',
              imageSource as List<int>,
              filename: 'upload.jpg',
            ),
          );
        } else {
          throw ArgumentError('imageSource must be Uint8List or List<int> on web');
        }
      } else {
        // No mobile/desktop, we expect a File-like object with a path
        // Since we can't import dart:io directly in a way that works everywhere easily,
        // we assume the caller passed something with a 'path' property or we use dynamic.
        try {
          final dynamic file = imageSource;
          request.files.add(
            await http.MultipartFile.fromPath('image', file.path as String),
          );
        } catch (e) {
          throw ArgumentError('imageSource must have a valid path on mobile/desktop: $e');
        }
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return responseData;
      } else {
        debugPrint('Upload failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
}
