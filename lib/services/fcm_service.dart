import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging service for background push notifications.
///
/// IMPORTANT: Requires Firebase project setup:
/// 1. Add google-services.json to android/app/
/// 2. Configure Firebase in android/build.gradle
/// 3. Enable FCM in Firebase Console
///
/// Until Firebase is configured, this service logs warnings and does nothing.
class FcmService {
  bool _initialized = false;
  String? _token;

  bool get isAvailable => _initialized;
  String? get token => _token;

  /// Initialize FCM. Gracefully degrades if Firebase isn't configured.
  Future<void> init() async {
    try {
      // Firebase.initializeApp() would go here once configured.
      // For now, just log that FCM isn't available.
      debugPrint(
          'FcmService: Firebase not configured yet. '
          'Add google-services.json and enable Firebase to use FCM push notifications.');
      _initialized = false;
    } catch (e) {
      debugPrint('FcmService init error: $e');
      _initialized = false;
    }
  }

  /// Subscribe to a topic for targeted push notifications.
  Future<void> subscribeToTopic(String topic) async {
    if (!_initialized) return;
    // await FirebaseMessaging.instance.subscribeToTopic(topic);
    debugPrint('FcmService: subscribe to topic "$topic" (not yet active)');
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_initialized) return;
    // await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
    debugPrint('FcmService: unsubscribe from topic "$topic" (not yet active)');
  }
}
