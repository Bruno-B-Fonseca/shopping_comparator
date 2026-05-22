import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class ReputationService {
  static const String _contributorSecretKey = 'contributor_secret_v1';
  static const String _reputationScoreKey = 'my_reputation_score_v1';
  static const String _lastActivityKey = 'reputation_last_activity_v1';

  static String? _cachedHash;
  static int? _cachedScore;

  /// Inicializa o serviço e verifica resfriamento (Decay)
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    String? secret = prefs.getString(_contributorSecretKey);
    if (secret == null) {
      secret = const Uuid().v4();
      await prefs.setString(_contributorSecretKey, secret);
    }
    
    _cachedHash = sha256.convert(utf8.encode(secret)).toString();
    _cachedScore = prefs.getInt(_reputationScoreKey) ?? 0;

    // Lógica de Decay (Resfriamento por Inatividade)
    final lastActivityStr = prefs.getString(_lastActivityKey);
    if (lastActivityStr != null && _cachedScore! > 0) {
      final lastActivity = DateTime.parse(lastActivityStr);
      final daysInactive = DateTime.now().difference(lastActivity).inDays;
      
      if (daysInactive > 15) {
        // Reduz 5% do score por dia de inatividade além de 15 dias
        final daysToPenalize = daysInactive - 15;
        double newScore = _cachedScore!.toDouble();
        for (int i = 0; i < daysToPenalize; i++) {
          newScore *= 0.95;
        }
        _cachedScore = newScore.round();
        await prefs.setInt(_reputationScoreKey, _cachedScore!);
        debugPrint('Reputação: Resfriamento aplicado! Score atual: $_cachedScore');
      }
    }
  }

  /// Retorna o Hash SHA-256 anônimo do dispositivo
  static String get contributorHash {
    if (_cachedHash == null) {
      throw Exception('ReputationService não inicializado. Chame init() primeiro.');
    }
    return _cachedHash!;
  }

  /// Retorna o score de reputação local
  static int get myScore => _cachedScore ?? 0;

  /// Atualiza o score localmente e marca atividade
  static Future<void> updateMyScore(int bonus) async {
    final prefs = await SharedPreferences.getInstance();
    _cachedScore = ((_cachedScore ?? 0) + bonus).clamp(0, 9999);
    await prefs.setInt(_reputationScoreKey, _cachedScore!);
    
    // Marca atividade se o bônus for positivo (contribuição válida)
    if (bonus > 0) {
      await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
    }
  }

  /// Marca que o usuário realizou uma ação (mesmo sem bônus imediato)
  static Future<void> markActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastActivityKey, DateTime.now().toIso8601String());
  }

  /// Reseta a reputação (Direito ao Esquecimento)
  static Future<void> resetReputation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_contributorSecretKey);
    await prefs.remove(_reputationScoreKey);
    await prefs.remove(_lastActivityKey);
    await init();
  }
}
