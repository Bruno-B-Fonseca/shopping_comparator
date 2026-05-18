import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static const String _encryptionKeyStorageKey = '_hive_encryption_key_v1';

  /// Obtém ou cria a chave de criptografia para Hive
  /// A chave é derivada do device ID e armazenada em SharedPreferences
  static Future<List<int>> getOrCreateEncryptionKey() async {
    final prefs = await SharedPreferences.getInstance();

    // Tenta recuperar a chave existente
    final keyString = prefs.getString(_encryptionKeyStorageKey);
    if (keyString != null) {
      try {
        final keyList = jsonDecode(keyString) as List;
        return keyList.cast<int>();
      } catch (e) {
        debugPrint('Erro ao decodificar chave de criptografia: $e');
      }
    }

    // Se não existe, cria uma nova chave
    final newKey = _generateEncryptionKey();

    try {
      await prefs.setString(
        _encryptionKeyStorageKey,
        jsonEncode(newKey),
      );
      debugPrint('Chave de criptografia Hive gerada e armazenada com sucesso');
    } catch (e) {
      debugPrint('Erro ao armazenar chave de criptografia: $e');
    }

    return newKey;
  }

  /// Gera uma chave de criptografia aleatória de 32 bytes
  static List<int> _generateEncryptionKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final random = DateTime.now().microsecond;
    final combined = '$timestamp-$random';

    // Usa SHA256 para gerar uma chave determinística baseada em dados do dispositivo
    final bytes = sha256.convert(utf8.encode(combined)).bytes;

    // Pega os primeiros 32 bytes para AES256
    return bytes.take(32).toList();
  }

  /// Limpa a chave de criptografia armazenada (útil para resetar)
  static Future<void> clearEncryptionKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_encryptionKeyStorageKey);
    debugPrint('Chave de criptografia Hive foi limpa');
  }
}
