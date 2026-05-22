import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/optimization_result.dart';
import '../models/shopping_list.dart';
import '../services/shopping_optimizer_service.dart';

class OptimizationState {
  final bool isLoading;
  final OptimizationResult? result;
  final String? error;

  OptimizationState({this.isLoading = false, this.result, this.error});

  OptimizationState copyWith({bool? isLoading, OptimizationResult? result, String? error}) {
    return OptimizationState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      error: error ?? this.error,
    );
  }
}

class OptimizationNotifier extends StateNotifier<OptimizationState> {
  OptimizationNotifier() : super(OptimizationState());

  Future<void> optimizeList(ShoppingList list) async {
    if (list.items.isEmpty) {
      state = OptimizationState(error: 'A lista está vazia.');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await ShoppingOptimizerService.optimize(list);
      state = state.copyWith(isLoading: false, result: result);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Erro ao calcular: $e');
    }
  }

  void clear() {
    state = OptimizationState();
  }
}

final optimizationProvider =
    StateNotifierProvider<OptimizationNotifier, OptimizationState>((ref) {
  return OptimizationNotifier();
});
