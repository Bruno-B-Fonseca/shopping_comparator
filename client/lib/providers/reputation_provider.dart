import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/reputation_service.dart';

class ReputationNotifier extends StateNotifier<int> {
  ReputationNotifier() : super(ReputationService.myScore);

  Future<void> updateScore(int bonus) async {
    await ReputationService.updateMyScore(bonus);
    state = ReputationService.myScore;
  }

  Future<void> reset() async {
    await ReputationService.resetReputation();
    state = ReputationService.myScore;
  }

  void refresh() {
    state = ReputationService.myScore;
  }
}

final reputationProvider = StateNotifierProvider<ReputationNotifier, int>((ref) {
  return ReputationNotifier();
});
