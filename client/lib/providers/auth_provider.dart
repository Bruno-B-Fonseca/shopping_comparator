import 'package:client/providers/websocket_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthState {
  final bool isOperator;
  final String? locationId;
  final String? locationPassword;

  AuthState({
    required this.isOperator,
    this.locationId,
    this.locationPassword,
  });

  AuthState copyWith({
    bool? isOperator,
    String? locationId,
    String? locationPassword,
  }) {
    return AuthState(
      isOperator: isOperator ?? this.isOperator,
      locationId: locationId ?? this.locationId,
      locationPassword: locationPassword ?? this.locationPassword,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(AuthState(isOperator: false)) {
    loadCredentials();
  }

  Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('location_id');
    final password = prefs.getString('location_password');

    state = AuthState(
      isOperator: id != null && id.isNotEmpty && password != null && password.isNotEmpty,
      locationId: id,
      locationPassword: password,
    );
  }

  Future<void> setCredentials(String id, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('location_id', id);
    await prefs.setString('location_password', password);
    
    state = AuthState(
      isOperator: id.isNotEmpty && password.isNotEmpty,
      locationId: id,
      locationPassword: password,
    );
  }

  Future<bool> verifyAndSetCredentials(String id, String password) async {
    final success = await ref.read(webSocketServiceProvider).verifyCredentials(id, password);
    
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('location_id', id);
      await prefs.setString('location_password', password);
      
      state = AuthState(
        isOperator: true,
        locationId: id,
        locationPassword: password,
      );
    }
    
    return success;
  }

  Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('location_id');
    await prefs.remove('location_password');
    state = AuthState(isOperator: false);
  }
}
