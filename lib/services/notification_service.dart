import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Service for scheduling local notifications (reminders).
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _canUseExactAlarms = false;

  /// Initialize the notification service, timezone data, and channels.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone database
    tz_data.initializeTimeZones();
    // Set local timezone — use device timezone instead of hardcoded Europe/Berlin
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final tzName = 'Etc/GMT${offset.isNegative ? "+" : "-"}${offset.inHours.abs()}';
      tz.setLocalLocation(tz.getLocation(tzName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Berlin'));
    }

    // Create notification channel explicitly (Android 8+)
    const channel = AndroidNotificationChannel(
      'ai_buddy_reminders',
      'AI-Buddy Erinnerungen',
      description: 'Lokale Erinnerungen von AI-Buddy',
      importance: Importance.high,
      enableVibration: true,
      enableLights: true,
    );
    await _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

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

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await _requestNotificationPermission();

    // Check exact alarm permission (Android 12+)
    await _checkExactAlarmPermission();
  }

  /// Request POST_NOTIFICATIONS runtime permission (Android 13+).
  Future<void> _requestNotificationPermission() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied || status.isPermanentlyDenied) {
        final result = await Permission.notification.request();
        debugPrint('POST_NOTIFICATIONS permission: $result');
      }
    } catch (e) {
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Check if exact alarms are allowed (Android 12+ / API 31+).
  /// Some OEMs (Xiaomi, Samsung) deny this by default.
  Future<void> _checkExactAlarmPermission() async {
    try {
      final status = await Permission.scheduleExactAlarm.status;
      debugPrint('SCHEDULE_EXACT_ALARM permission: $status');
      if (status.isGranted) {
        _canUseExactAlarms = true;
      } else if (status.isDenied) {
        // Try requesting — some devices allow it
        final result = await Permission.scheduleExactAlarm.request();
        _canUseExactAlarms = result.isGranted;
        debugPrint('SCHEDULE_EXACT_ALARM request result: $result');
      } else {
        _canUseExactAlarms = false;
        debugPrint('SCHEDULE_EXACT_ALARM permanently denied — using inexact alarms');
      }
    } catch (e) {
      // Permission not available on this Android version or plugin doesn't support it
      _canUseExactAlarms = false;
      debugPrint('SCHEDULE_EXACT_ALARM check failed (likely pre-Android 12): $e');
    }
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
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Generate a unique ID based on time + hash of title to avoid collisions
    // when multiple reminders are scheduled within the same second.
    final titleHash = title.hashCode.abs() % 1000;
    final id = (scheduledTime.millisecondsSinceEpoch ~/ 1000 % 100000) * 1000 + titleHash;

    try {
      final tzDateTime = tz.TZDateTime.from(scheduledTime, tz.local);
      debugPrint('Scheduling notification "$title" at $scheduledTime (tzDateTime=$tzDateTime)');

      // Choose schedule mode based on permission and delay
      final delay = scheduledTime.difference(DateTime.now());
      AndroidScheduleMode scheduleMode;

      if (_canUseExactAlarms && delay.inMinutes < 30) {
        scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
        debugPrint('Using exact alarm mode (permission granted, delay < 30min)');
      } else {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        debugPrint('Using inexact alarm mode (exactAlarms=$_canUseExactAlarms, delay=${delay.inMinutes}min)');
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDateTime,
        notificationDetails,
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint('Notification scheduled successfully: "$title" at $scheduledTime (id=$id, mode=$scheduleMode)');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Failed to schedule notification: $e');
      debugPrint('Stack trace: $stackTrace');

      // Last resort: try with inexact mode if exact failed
      if (_canUseExactAlarms) {
        try {
          debugPrint('Retrying with inexact mode...');
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
          debugPrint('Inexact fallback succeeded');
          return true;
        } catch (e2) {
          debugPrint('Inexact fallback also failed: $e2');
        }
      }
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
