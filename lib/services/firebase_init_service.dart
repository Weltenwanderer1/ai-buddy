import 'dart:developer' as dev;
import 'package:firebase_core/firebase_core.dart';

/// Initializes Firebase with graceful fallback.
/// If google-services.json is missing, Firebase stays disabled.
class FirebaseInitService {
  static bool _initialized = false;
  static bool get isAvailable => _initialized;

  static Future<void> init() async {
    if (_initialized) return; // idempotent — wird aus main() UND Service-Init gerufen
    try {
      await Firebase.initializeApp();
      _initialized = true;
      dev.log('Firebase initialized successfully');
    } catch (e) {
      _initialized = false;
      dev.log('Firebase not available (missing google-services.json?): $e');
    }
  }
}
