import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

/// Shows a notification when the buddy sends a message while the app is in background.
class BuddyNotifier {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _idCounter = 8000;

  /// Initialize notification channel for buddy messages.
  static Future<void> init() async {
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Show a notification when the buddy replied.
  /// Only fires if the app is NOT in the foreground (respecting user context).
  static Future<void> notifyBuddyReply({
    required String buddyName,
    required String message,
    bool appInBackground = false,
  }) async {
    if (!_initialized) await init();

    // Trim message for notification preview (max ~80 chars)
    final preview = message.length > 80
        ? '${message.substring(0, 77)}...'
        : message;

    const androidDetails = AndroidNotificationDetails(
      'buddy_messages',
      'Buddy Nachrichten',
      channelDescription: 'Benachrichtigungen wenn dein Buddy schreibt',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      // Only alert if app is in background
      playSound: true,
      enableVibration: true,
    );

    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      _idCounter++,
      buddyName,
      preview,
      details,
    );
    debugPrint('BuddyNotifier: notification shown for "$buddyName"');
  }

  /// Cancel all buddy notifications (e.g. when user opens the chat).
  static Future<void> clearAll() async {
    await _plugin.cancelAll();
  }
}