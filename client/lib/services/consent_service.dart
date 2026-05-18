import 'package:shared_preferences/shared_preferences.dart';

class ConsentService {
  static const String _locationConsentKey = 'consent_location';
  static const String _aiProcessingConsentKey = 'consent_ai_processing';
  static const String _privacyAcknowledgedKey = 'privacy_acknowledged';

  static Future<bool> hasLocationConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_locationConsentKey) ?? false;
  }

  static Future<void> setLocationConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationConsentKey, value);
  }

  static Future<bool> hasAiProcessingConsent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_aiProcessingConsentKey) ?? false;
  }

  static Future<void> setAiProcessingConsent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_aiProcessingConsentKey, value);
  }

  static Future<bool> hasPrivacyAcknowledged() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_privacyAcknowledgedKey) ?? false;
  }

  static Future<void> setPrivacyAcknowledged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_privacyAcknowledgedKey, value);
  }

  static Future<void> resetAllConsents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_locationConsentKey);
    await prefs.remove(_aiProcessingConsentKey);
    await prefs.remove(_privacyAcknowledgedKey);
  }
}
