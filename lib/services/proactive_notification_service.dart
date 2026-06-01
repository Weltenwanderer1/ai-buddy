import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Types of proactive notifications.
enum ProactiveNotificationType {
  reminder,
  calendarHeadsup,
  batteryLow,
  eveningRecap,
  contextualSuggestion,
  automation,
  custom,
}

/// A proactive notification with optional action buttons.
class ProactiveNotification {
  final String id;
  final ProactiveNotificationType type;
  final String title;
  final String body;
  final String? payload;
  final List<ProactiveAction> actions;
  final DateTime createdAt;
  bool read;

  ProactiveNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.payload,
    this.actions = const [],
    DateTime? createdAt,
    this.read = false,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'body': body,
        'payload': payload,
        'actions': actions.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'read': read,
      };

  factory ProactiveNotification.fromJson(Map<String, dynamic> json) =>
      ProactiveNotification(
        id: json['id'] as String,
        type: ProactiveNotificationType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => ProactiveNotificationType.custom,
        ),
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        payload: json['payload'] as String?,
        actions: (json['actions'] as List<dynamic>?)
                ?.map((a) => ProactiveAction.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        read: json['read'] as bool? ?? false,
      );
}

/// An action button on a proactive notification.
class ProactiveAction {
  final String id;
  final String label;
  final String? payload;

  const ProactiveAction({
    required this.id,
    required this.label,
    this.payload,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'payload': payload,
      };

  factory ProactiveAction.fromJson(Map<String, dynamic> json) =>
      ProactiveAction(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        payload: json['payload'] as String?,
      );
}

/// Callback when a proactive notification action is tapped.
typedef ProactiveActionCallback = void Function(
    ProactiveNotification notification, ProactiveAction action);

/// Service for sending proactive notifications with action buttons.
class ProactiveNotificationService extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _notifications;
  static const _channelId = 'ai_buddy_proactive';
  static const _channelName = 'AI-Buddy Proaktiv';
  static const _prefKey = 'proactive_notifications';
  static const _maxStored = 50;

  final List<ProactiveNotification> _history = [];
  int _nextId = 1000;

  /// Registered action handlers by action ID.
  final Map<String, ProactiveActionCallback> _actionHandlers = {};

  ProactiveNotificationService({FlutterLocalNotificationsPlugin? notifications})
      : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  List<ProactiveNotification> get history => List.unmodifiable(_history);
  int get unreadCount => _history.where((n) => !n.read).length;

  /// Initialize the proactive notification channel.
  Future<void> init() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: 'Proaktive Vorschläge und Benachrichtigungen',
          importance: Importance.high,
          enableVibration: true,
        ),
      );
    }

    // Initialize with action response handler
      tz_data.initializeTimeZones();
    await _notifications.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _loadHistory();
  }

  /// Register an action handler for a specific action ID.
  void registerActionHandler(String actionId, ProactiveActionCallback handler) {
    _actionHandlers[actionId] = handler;
  }

  /// Send a proactive notification immediately.
  Future<void> sendNotification({
    required ProactiveNotificationType type,
    required String title,
    required String body,
    String? payload,
    List<ProactiveAction> actions = const [],
  }) async {
    final id = _nextId++;
    final notification = ProactiveNotification(
      id: id.toString(),
      type: type,
      title: title,
      body: body,
      payload: payload,
      actions: actions,
    );

    _history.insert(0, notification);
    if (_history.length > _maxStored) {
      _history.removeRange(_maxStored, _history.length);
    }
    await _saveHistory();
    notifyListeners();

    // Build Android action buttons
    final androidActions = <AndroidNotificationAction>[];
    for (final action in actions) {
      androidActions.add(
        AndroidNotificationAction(
          action.id,
          action.label,
          showsUserInterface: false,
          cancelNotification: false,
        ),
      );
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Proaktive Vorschläge',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.message,
      actions: androidActions,
      styleInformation: BigTextStyleInformation(body),
    );

    await _notifications.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(notification.toJson()),
    );

    debugPrint(
        'ProactiveNotificationService: sent "$title" with ${actions.length} actions');
  }

  /// Schedule a proactive notification for a future time.
  Future<void> scheduleNotification({
    required ProactiveNotificationType type,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? payload,
    List<ProactiveAction> actions = const [],
  }) async {
    final id = _nextId++;
    final notification = ProactiveNotification(
      id: id.toString(),
      type: type,
      title: title,
      body: body,
      payload: payload,
      actions: actions,
    );

    _history.insert(0, notification);
    await _saveHistory();
    notifyListeners();

    final androidActions = <AndroidNotificationAction>[];
    for (final action in actions) {
      androidActions.add(
        AndroidNotificationAction(
          action.id,
          action.label,
          showsUserInterface: false,
          cancelNotification: false,
        ),
      );
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
      actions: androidActions,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: jsonEncode(notification.toJson()),
    );
  }

  /// Mark a notification as read.
  void markRead(String id) {
    final idx = _history.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _history[idx].read = true;
      _saveHistory();
      notifyListeners();
    }
  }

  /// Mark all as read.
  void markAllRead() {
    for (final n in _history) {
      n.read = true;
    }
    _saveHistory();
    notifyListeners();
  }

  /// Clear notification history.
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
        'Proactive notification tapped: id=${response.id}, actionId=${response.actionId}, payload=${response.payload}');

    if (response.payload != null && response.payload!.isNotEmpty) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        final notification = ProactiveNotification.fromJson(data);

        // If an action button was tapped
        if (response.actionId != null && response.actionId!.isNotEmpty) {
          final action = notification.actions
              .where((a) => a.id == response.actionId)
              .firstOrNull;
          if (action != null) {
            _actionHandlers[action.id]?.call(notification, action);
          }
        }

        markRead(notification.id);
      } catch (e) {
        debugPrint('Proactive notification payload parse error: $e');
      }
    }
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_prefKey);
      if (data != null) {
        final list = jsonDecode(data) as List<dynamic>;
        _history.clear();
        _history.addAll(
          list.map((j) =>
              ProactiveNotification.fromJson(j as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('ProactiveNotificationService: load error: $e');
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_history.map((n) => n.toJson()).toList());
      await prefs.setString(_prefKey, data);
    } catch (e) {
      debugPrint('ProactiveNotificationService: save error: $e');
    }
  }
}


