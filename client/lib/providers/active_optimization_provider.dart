import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/optimization_result.dart';

final activeOptimizationProvider = StateProvider<OptimizationResult?>((ref) => null);
