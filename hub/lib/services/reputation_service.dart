import 'dart:convert';
import 'dart:io';
import 'package:logging/logging.dart';

class ReputationService {
  final _log = Logger('ReputationService');
  final String _dbPath = 'config/reputation_db.json';
  Map<String, int> _scores = {};

  ReputationService() {
    _loadScores();
  }

  void _loadScores() {
    try {
      final file = File(_dbPath);
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        _scores = Map<String, int>.from(jsonDecode(content));
        _log.info('Reputation DB loaded: ${_scores.length} users');
      }
    } catch (e) {
      _log.severe('Error loading reputation DB: $e');
    }
  }

  void _saveScores() {
    try {
      final file = File(_dbPath);
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode(_scores));
    } catch (e) {
      _log.severe('Error saving reputation DB: $e');
    }
  }

  int getScore(String contributorHash) {
    return _scores[contributorHash] ?? 0;
  }

  void addBonus(String contributorHash, int bonus) {
    final current = _scores[contributorHash] ?? 0;
    _scores[contributorHash] = (current + bonus).clamp(0, 9999);
    _log.info('Reputation: Bonus of $bonus given to $contributorHash (New Total: ${_scores[contributorHash]})');
    _saveScores();
  }

  /// Lógica de resfriamento (Decay) para ser chamada periodicamente via cron/timer
  void applyDecay() {
    _log.info('Reputation: Applying global time decay...');
    bool changed = false;
    _scores.forEach((hash, score) {
      if (score > 0) {
        // Reduz 1 ponto por ciclo de decay (ex: por dia)
        _scores[hash] = score - 1;
        changed = true;
      }
    });
    if (changed) _saveScores();
  }
}
