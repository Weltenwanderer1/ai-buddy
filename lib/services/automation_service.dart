import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trigger types for automation rules.
enum AutomationTriggerType {
  wifiConnect,
  wifiDisconnect,
  locationEnter,
  locationLeave,
  timeOfDay,
  calendarEvent,
  batteryLow,
  batteryCharging,
  screenOn,
  screenOff,
}

/// Action types for automation rules.
enum AutomationActionType {
  setVolume,
  muteDevice,
  sendNotification,
  setTimer,
  sendMessage,
  openApp,
  setWifi,
  setBluetooth,
  custom,
}

/// A trigger condition.
class AutomationTrigger {
  final AutomationTriggerType type;
  final Map<String, dynamic> params;

  const AutomationTrigger({
    required this.type,
    this.params = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'params': params,
      };

  factory AutomationTrigger.fromJson(Map<String, dynamic> json) =>
      AutomationTrigger(
        type: AutomationTriggerType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AutomationTriggerType.timeOfDay,
        ),
        params: (json['params'] as Map<String, dynamic>?) ?? {},
      );
}

/// An action to execute.
class AutomationAction {
  final AutomationActionType type;
  final Map<String, dynamic> params;

  const AutomationAction({
    required this.type,
    this.params = const {},
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'params': params,
      };

  factory AutomationAction.fromJson(Map<String, dynamic> json) =>
      AutomationAction(
        type: AutomationActionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AutomationActionType.custom,
        ),
        params: (json['params'] as Map<String, dynamic>?) ?? {},
      );
}

/// An automation rule: "When [trigger], then [actions]".
class AutomationRule {
  final String id;
  final String name;
  final bool enabled;
  final AutomationTrigger trigger;
  final List<AutomationAction> actions;
  final DateTime createdAt;
  DateTime? lastFired;

  AutomationRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.trigger,
    required this.actions,
    DateTime? createdAt,
    this.lastFired,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'trigger': trigger.toJson(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'lastFired': lastFired?.toIso8601String(),
      };

  factory AutomationRule.fromJson(Map<String, dynamic> json) =>
      AutomationRule(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        trigger: AutomationTrigger.fromJson(
            json['trigger'] as Map<String, dynamic>? ?? {}),
        actions: (json['actions'] as List<dynamic>?)
                ?.map((a) =>
                    AutomationAction.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastFired: json['lastFired'] != null
            ? DateTime.tryParse(json['lastFired'] as String)
            : null,
      );
}

/// Callback to execute an automation action.
typedef AutomationActionExecutor = Future<bool> Function(
    AutomationAction action);

/// Service for managing and executing automation rules.
class AutomationService extends ChangeNotifier {
  static const _prefKey = 'automation_rules';
  final List<AutomationRule> _rules = [];
  Timer? _timeCheckTimer;
  final Map<String, AutomationActionExecutor> _executors = {};

  List<AutomationRule> get rules => List.unmodifiable(_rules);
  int get activeRuleCount => _rules.where((r) => r.enabled).length;

  /// Initialize and load persisted rules.
  Future<void> init() async {
    await _loadRules();
    _startTimeCheck();
  }

  /// Register an action executor for a specific action type.
  void registerExecutor(AutomationActionType type, AutomationActionExecutor executor) {
    _executors[type.name] = executor;
  }

  /// Add a new automation rule.
  Future<void> addRule(AutomationRule rule) async {
    _rules.add(rule);
    await _saveRules();
    notifyListeners();
  }

  /// Update an existing rule.
  Future<void> updateRule(String id, AutomationRule updated) async {
    final idx = _rules.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _rules[idx] = updated;
      await _saveRules();
      notifyListeners();
    }
  }

  /// Delete a rule by ID.
  Future<void> deleteRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _saveRules();
    notifyListeners();
  }

  /// Enable or disable a rule.
  Future<void> toggleRule(String id, bool enabled) async {
    final idx = _rules.indexWhere((r) => r.id == id);
    if (idx >= 0) {
      _rules[idx] = AutomationRule(
        id: _rules[idx].id,
        name: _rules[idx].name,
        enabled: enabled,
        trigger: _rules[idx].trigger,
        actions: _rules[idx].actions,
        createdAt: _rules[idx].createdAt,
        lastFired: _rules[idx].lastFired,
      );
      await _saveRules();
      notifyListeners();
    }
  }

  /// Fire a trigger — checks all rules and executes matching actions.
  Future<void> fireTrigger(AutomationTriggerType type,
      {Map<String, dynamic>? context}) async {
    final matchingRules = _rules.where((r) =>
        r.enabled && r.trigger.type == type);

    for (final rule in matchingRules) {
      debugPrint('AutomationService: firing rule "${rule.name}"');
      await _executeRule(rule);
    }
  }

  /// Execute all actions of a rule.
  Future<void> _executeRule(AutomationRule rule) async {
    for (final action in rule.actions) {
      final executor = _executors[action.type.name];
      if (executor != null) {
        try {
          await executor(action);
        } catch (e) {
          debugPrint(
              'AutomationService: action ${action.type.name} failed: $e');
        }
      } else {
        debugPrint(
            'AutomationService: no executor for ${action.type.name}');
      }
    }

    // Update lastFired
    final idx = _rules.indexWhere((r) => r.id == rule.id);
    if (idx >= 0) {
      _rules[idx].lastFired = DateTime.now();
      await _saveRules();
    }
  }

  /// Periodic check for time-based triggers.
  void _startTimeCheck() {
    _timeCheckTimer?.cancel();
    _timeCheckTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkTimeTriggers();
    });
  }

  void _checkTimeTriggers() {
    final now = DateTime.now();
    final currentTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.trigger.type != AutomationTriggerType.timeOfDay) continue;

      final triggerTime = rule.trigger.params['time'] as String?;
      if (triggerTime == currentTime) {
        // Don't fire twice in the same minute
        if (rule.lastFired != null) {
          final diff = now.difference(rule.lastFired!);
          if (diff.inMinutes < 1) continue;
        }
        _executeRule(rule);
      }
    }
  }

  Future<void> _loadRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_prefKey);
      if (data != null) {
        final list = jsonDecode(data) as List<dynamic>;
        _rules.clear();
        _rules.addAll(
          list.map((j) =>
              AutomationRule.fromJson(j as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      debugPrint('AutomationService: load error: $e');
    }
  }

  Future<void> _saveRules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = jsonEncode(_rules.map((r) => r.toJson()).toList());
      await prefs.setString(_prefKey, data);
    } catch (e) {
      debugPrint('AutomationService: save error: $e');
    }
  }

  @override
  void dispose() {
    _timeCheckTimer?.cancel();
    super.dispose();
  }
}
