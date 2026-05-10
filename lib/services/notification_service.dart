import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Service for scheduling local notifications (reminders).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialize the notification service and timezone data.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();
    // Set local timezone
    tz.setLocalLocation(tz.getLocation('Europe/Berlin'));

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_launcher',
    );
    const initSettings = InitializationSettings(android: androidSettings);

    final result = await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = result ?? false;
    debugPrint('NotificationService initialized: $_initialized');
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('Notification tapped: id=${response.id}, payload=${response.payload}');
  }

  /// Schedule a local notification.
  Future<bool> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    if (!_initialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      'ai_buddy_reminders',
      'AI-Buddy Erinnerungen',
      channelDescription: 'Lokale Erinnerungen von AI-Buddy',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_launcher',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Generate a unique ID based on time
    final id = scheduledTime.millisecondsSinceEpoch ~/ 1000 % 100000;

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Notification scheduled: "$title" at $scheduledTime (id=$id)');
      return true;
    } catch (e) {
      debugPrint('Failed to schedule notification: $e');
      return false;
    }
  }

  /// Cancel a specific notification by ID.
  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }

  /// Cancel all scheduled notifications.
  Future<void> cancelAllNotifications() async {
    await _plugin.cancelAll();
  }

  void dispose() {
    // No cleanup needed
  }
}