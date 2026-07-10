import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

/// Represents an active timer.
class TimerEntry {
  final String id;
  final String label;
  final int totalSeconds;
  final DateTime createdAt;
  DateTime endsAt;
  Timer? _countdown;
  bool fired = false;

  TimerEntry({
    required this.id,
    required this.label,
    required this.totalSeconds,
    DateTime? createdAt,
    DateTime? endsAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        endsAt = endsAt ?? DateTime.now().add(Duration(seconds: totalSeconds));

  int get remainingSeconds {
    final diff = endsAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  bool get isExpired => remainingSeconds <= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'totalSeconds': totalSeconds,
        'createdAt': createdAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
      };

  factory TimerEntry.fromJson(Map<String, dynamic> json) => TimerEntry(
        id: json['id'] as String,
        label: json['label'] as String? ?? 'Timer',
        totalSeconds: json['totalSeconds'] as int? ?? 60,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        endsAt: DateTime.tryParse(json['endsAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

/// Service for managing countdown timers with audible alarm notifications.
class TimerService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications;
  final Map<String, TimerEntry> _timers = {};
  Timer? _ticker;
  static const _prefKey = 'active_timers';
  static const _alarmChannelId = 'ai_buddy_timer_alarm';

  TimerService({FlutterLocalNotificationsPlugin? notifications})
      : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  List<TimerEntry> get activeTimers =>
      _timers.values.where((t) => !t.isExpired).toList();

  /// Initialize and restore persisted timers.
  Future<void> init() async {
    // Create alarm channel with high importance + sound
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _alarmChannelId,
          'AI-Buddy Timer Alarme',
          description: 'Lauter Alarm wenn ein Timer abläuft',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
    }

    await _restoreTimers();
    _ensureTicker();
  }

  /// Start a new timer. Returns the timer ID.
  Future<String> startTimer({
    required String label,
    required int durationSeconds,
  }) async {
    final id = const Uuid().v4().substring(0, 8);
    final entry = TimerEntry(
      id: id,
      label: label,
      totalSeconds: durationSeconds,
    );
    _timers[id] = entry;
    _scheduleAlarm(entry);
    await _persistTimers();
    _ensureTicker();
    notifyListeners();
    return id;
  }

  /// Cancel a timer by ID. Returns true if found and cancelled.
  Future<bool> cancelTimer(String id) async {
    final entry = _timers.remove(id);
    if (entry == null) return false;
    entry._countdown?.cancel();
    // Cancel the scheduled notification
    await _notifications.cancel(id.hashCode.abs() % 100000);
    await _persistTimers();
    notifyListeners();
    return true;
  }

  /// Get list of active timer summaries.
  List<Map<String, dynamic>> listTimers() {
    return activeTimers
        .map((t) => {
              'id': t.id,
              'label': t.label,
              'remainingSeconds': t.remainingSeconds,
              'totalSeconds': t.totalSeconds,
            })
        .toList();
  }

  /// Start the 1 Hz ticker only while there are running timers. When the last
  /// timer finishes the ticker stops, so an idle app is not rebuilt every
  /// second forever. Call again whenever a new timer is added.
  void _ensureTicker() {
    if (_ticker != null) return;
    if (_timers.values.every((t) => t.isExpired)) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      bool changed = false;
      for (final entry in _timers.values) {
        if (!entry.fired && entry.isExpired) {
          entry.fired = true;
          _fireAlarm(entry);
          changed = true;
        }
      }
      if (changed) {
        _persistTimers();
      }
      // Per-second notify is needed for the live countdown UI — but only while
      // at least one timer is still running.
      notifyListeners();
      if (_timers.values.every((t) => t.isExpired)) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  /// Schedule a notification alarm when the timer expires.
  void _scheduleAlarm(TimerEntry entry) {
    // Use a short delay before scheduling to ensure it fires
    final delay = entry.endsAt.difference(DateTime.now());
    if (delay.isNegative) return;

    // Schedule via flutter_local_notifications
    _notifications.zonedSchedule(
      entry.id.hashCode.abs() % 100000,
      '⏱️ Timer abgelaufen!',
      entry.label,
      tz.TZDateTime.from(entry.endsAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          'AI-Buddy Timer Alarme',
          channelDescription: 'Lauter Alarm wenn ein Timer abläuft',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  void _fireAlarm(TimerEntry entry) {
    debugPrint('TimerService: Alarm fired for "${entry.label}" (${entry.id})');
    // The scheduled notification handles the alarm sound.
    // We also show an immediate notification as backup.
    _notifications.show(
      entry.id.hashCode.abs() % 100000 + 50000,
      '⏱️ Timer abgelaufen!',
      entry.label,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _alarmChannelId,
          'AI-Buddy Timer Alarme',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
        ),
      ),
    );
  }

  Future<void> _persistTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final active = _timers.values
          .where((t) => !t.isExpired)
          .map((t) => t.toJson())
          .toList();
      await prefs.setString(_prefKey, jsonEncode(active));
    } catch (e) {
      debugPrint('TimerService: persist error: $e');
    }
  }

  Future<void> _restoreTimers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_prefKey);
      if (data == null || data.isEmpty) return;
      final List<dynamic> list = jsonDecode(data);
      for (final json in list) {
        final entry = TimerEntry.fromJson(json as Map<String, dynamic>);
        if (!entry.isExpired) {
          _timers[entry.id] = entry;
          _scheduleAlarm(entry);
        }
      }
      debugPrint('TimerService: restored ${_timers.length} timers');
    } catch (e) {
      debugPrint('TimerService: restore error: $e');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final entry in _timers.values) {
      entry._countdown?.cancel();
    }
    super.dispose();
  }
}


