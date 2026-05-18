import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/consent_service.dart';

final consentProvider = StateNotifierProvider<ConsentNotifier, ConsentState>((ref) {
  return ConsentNotifier();
});

class ConsentState {
  final bool privacyAcknowledged;
  final bool locationConsent;
  final bool aiProcessingConsent;

  ConsentState({
    required this.privacyAcknowledged,
    required this.locationConsent,
    required this.aiProcessingConsent,
  });

  ConsentState copyWith({
    bool? privacyAcknowledged,
    bool? locationConsent,
    bool? aiProcessingConsent,
  }) {
    return ConsentState(
      privacyAcknowledged: privacyAcknowledged ?? this.privacyAcknowledged,
      locationConsent: locationConsent ?? this.locationConsent,
      aiProcessingConsent: aiProcessingConsent ?? this.aiProcessingConsent,
    );
  }
}

class ConsentNotifier extends StateNotifier<ConsentState> {
  ConsentNotifier()
      : super(ConsentState(
          privacyAcknowledged: false,
          locationConsent: false,
          aiProcessingConsent: false,
        )) {
    _loadConsents();
  }

  Future<void> _loadConsents() async {
    final privacy = await ConsentService.hasPrivacyAcknowledged();
    final location = await ConsentService.hasLocationConsent();
    final ai = await ConsentService.hasAiProcessingConsent();

    state = ConsentState(
      privacyAcknowledged: privacy,
      locationConsent: location,
      aiProcessingConsent: ai,
    );
  }

  Future<void> setPrivacyAcknowledged(bool value) async {
    await ConsentService.setPrivacyAcknowledged(value);
    state = state.copyWith(privacyAcknowledged: value);
  }

  Future<void> setLocationConsent(bool value) async {
    await ConsentService.setLocationConsent(value);
    state = state.copyWith(locationConsent: value);
  }

  Future<void> setAiProcessingConsent(bool value) async {
    await ConsentService.setAiProcessingConsent(value);
    state = state.copyWith(aiProcessingConsent: value);
  }

  Future<void> resetAllConsents() async {
    await ConsentService.resetAllConsents();
    state = ConsentState(
      privacyAcknowledged: false,
      locationConsent: false,
      aiProcessingConsent: false,
    );
  }
}
