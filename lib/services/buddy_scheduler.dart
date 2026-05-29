import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background task callback — must be TOP-LEVEL function for workmanager.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    debugPrint('BuddyScheduler: task=$task, data=$inputData');

    switch (task) {
      case 'self_optimization':
        return await _runSelfOptimization(inputData);
      case 'proactive_check':
        return await _runProactiveCheck(inputData);
      default:
        debugPrint('BuddyScheduler: unknown task $task');
        return true;
    }
  });
}

/// Self-optimization: Memory cleanup, stale entry removal, stats.
/// Runs in background isolate — can only use shared_prefs + file I/O.
Future<bool> _runSelfOptimization(Map<String, dynamic>? input) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // 1. Clean up old fired-once markers (proactive engine)
    final keys = prefs.getKeys().where((k) => k.startsWith('proactive_')).toList();
    int cleaned = 0;
    final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
    for (final key in keys) {
      final val = prefs.getString(key);
      if (val != null && val != today) {
        await prefs.remove(key);
        cleaned++;
      }
    }

    // 2. Trim chat history if too long (keep last 200 entries)
    final historyJson = prefs.getString('chat_messages');
    int trimmed = 0;
    if (historyJson != null) {
      try {
        final List<dynamic> messages = jsonDecode(historyJson);
        if (messages.length > 200) {
          final trimmed_msgs = messages.sublist(messages.length - 200);
          await prefs.setString('chat_messages', jsonEncode(trimmed_msgs));
          trimmed = messages.length - 200;
        }
      } catch (_) {}
    }

    // 3. Remove short-term memories older than TTL
    final ttlMinutes = prefs.getInt('memory_ttl_minutes') ?? 60;
    final memJson = prefs.getString('short_term_memories');
    int memCleaned = 0;
    if (memJson != null) {
      try {
        final List<dynamic> mems = jsonDecode(memJson);
        final cutoff = DateTime.now().subtract(Duration(minutes: ttlMinutes));
        final kept = <Map<String, dynamic>>[];
        for (final m in mems) {
          final map = m as Map<String, dynamic>;
          final ts = map['timestamp'];
          if (ts != null) {
            final dt = DateTime.tryParse(ts.toString());
            if (dt != null && dt.isAfter(cutoff)) {
              kept.add(map);
              continue;
            }
          }
          kept.add(map); // keep entries without timestamp
        }
        if (kept.length < mems.length) {
          await prefs.setString('short_term_memories', jsonEncode(kept));
          memCleaned = mems.length - kept.length;
        }
      } catch (_) {}
    }

    // 4. Update last-run timestamp
    await prefs.setString('self_opt_last_run', DateTime.now().toIso8601String());
    await prefs.setInt('self_opt_cleaned_keys', cleaned);
    await prefs.setInt('self_opt_trimmed_msgs', trimmed);
    await prefs.setInt('self_opt_cleaned_mems', memCleaned);

    debugPrint('SelfOptimization done: $cleaned keys, $trimmed msgs, $memCleaned mems');

    // Show notification about optimization
    await _showNotification(
      id: 9001,
      title: '🧠 Tintin optimiert',
      body: cleaned + memCleaned > 0
        ? 'Optimierung durchgeführt: $cleaned alte Marker, $memCleaned Memories aufgeräumt'
        : 'Alles aktuell, kein Aufräumbedarf',
    );

    return true;
  } catch (e) {
    debugPrint('SelfOptimization error: $e');
    return false;
  }
}

/// Proactive check: Calendar heads-up, evening recap, etc.
Future<bool> _runProactiveCheck(Map<String, dynamic>? input) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hour = DateTime.now().hour;

    // Evening recap (20-22h)
    if (hour >= 20 && hour < 23) {
      final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      final alreadyFired = prefs.getString('proactive_evening_recap') == today;
      if (!alreadyFired) {
        await prefs.setString('proactive_evening_recap', today);
        await _showNotification(
          id: 9002,
          title: '🌙 Tagesrückblick',
          body: 'Der Tag neigt sich dem Ende. Öffne AI-Buddy für deinen Rückblick!',
        );
      }
    }

    // Morning check (7-9h)
    if (hour >= 7 && hour < 9) {
      final today = '${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      final alreadyFired = prefs.getString('proactive_morning') == today;
      if (!alreadyFired) {
        await prefs.setString('proactive_morning', today);
        await _showNotification(
          id: 9003,
          title: '☀️ Guten Morgen!',
          body: 'Soll ich deine Termine für heute checken?',
        );
      }
    }

    return true;
  } catch (e) {
    debugPrint('ProactiveCheck error: $e');
    return false;
  }
}

/// Show a local notification from background isolate.
Future<void> _showNotification({required int id, required String title, required String body}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await plugin.initialize(initSettings);

  const androidDetails = AndroidNotificationDetails(
    'buddy_background',
    'AI-Buddy Hintergrund',
    channelDescription: 'Benachrichtigungen von AI-Buddy im Hintergrund',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  const details = NotificationDetails(android: androidDetails);
  await plugin.show(id, title, body, details);
}

// ─── Foreground Service ────────────────────────────────────────

/// Manages scheduled background tasks (cron-like) for AI-Buddy.
class BuddyScheduler with ChangeNotifier {
  bool _initialized = false;
  SharedPreferences? _prefs;

  /// Task configuration
  final Map<String, BuddyTaskConfig> _tasks = {};

  /// Available tasks
  Map<String, BuddyTaskConfig> get tasks => Map.unmodifiable(_tasks);
  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();

    await Workmanager().initialize(callbackDispatcher);

    // Register default tasks
    _tasks['self_optimization'] = BuddyTaskConfig(
      name: 'Selbstoptimierung',
      description: 'Memory aufräumen, alte Einträge entfernen',
      frequency: const Duration(hours: 6),
      enabled: _prefs?.getBool('buddy_task_self_optimization') ?? true,
    );
    _tasks['proactive_check'] = BuddyTaskConfig(
      name: 'Proaktiver Check',
      description: 'Morgengruß, Abendrückblick, Kalender-Check',
      frequency: const Duration(hours: 2),
      enabled: _prefs?.getBool('buddy_task_proactive_check') ?? true,
    );

    // Start enabled tasks
    for (final entry in _tasks.entries) {
      if (entry.value.enabled) {
        await _scheduleTask(entry.key, entry.value);
      }
    }

    _initialized = true;
    debugPrint('BuddyScheduler initialized with ${_tasks.length} tasks');
  }

  /// Enable/disable a task
  Future<void> setTaskEnabled(String taskId, bool enabled) async {
    final task = _tasks[taskId];
    if (task == null) return;

    _tasks[taskId] = BuddyTaskConfig(
      name: task.name,
      description: task.description,
      frequency: task.frequency,
      enabled: enabled,
    );

    await _prefs?.setBool('buddy_task_$taskId', enabled);

    if (enabled) {
      await _scheduleTask(taskId, _tasks[taskId]!);
    } else {
      await Workmanager().cancelByUniqueName(taskId);
    }

    notifyListeners();
  }

  /// Update task frequency
  Future<void> setTaskFrequency(String taskId, Duration frequency) async {
    final task = _tasks[taskId];
    if (task == null) return;

    _tasks[taskId] = BuddyTaskConfig(
      name: task.name,
      description: task.description,
      frequency: frequency,
      enabled: task.enabled,
    );

    if (task.enabled) {
      await _scheduleTask(taskId, _tasks[taskId]!);
    }

    notifyListeners();
  }

  /// Run a task immediately (one-shot)
  Future<void> runTaskNow(String taskId) async {
    final task = _tasks[taskId];
    if (task == null) return;
    await Workmanager().registerOneOffTask(
      '${taskId}_now',
      taskId,
    );
  }

  /// Cancel all tasks
  Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    for (final key in _tasks.keys.toList()) {
      final task = _tasks[key]!;
      _tasks[key] = BuddyTaskConfig(
        name: task.name,
        description: task.description,
        frequency: task.frequency,
        enabled: false,
      );
    }
    notifyListeners();
  }

  /// Get last run info for a task
  String? getLastRun(String taskId) {
    return _prefs?.getString('${taskId}_last_run');
  }

  Future<void> _scheduleTask(String taskId, BuddyTaskConfig config) async {
    await Workmanager().registerPeriodicTask(
      taskId,
      taskId,
      frequency: config.frequency,
      initialDelay: const Duration(minutes: 5),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
    debugPrint('BuddyScheduler: scheduled $taskId every ${config.frequency.inMinutes}min');
  }
}

/// Configuration for a scheduled task.
class BuddyTaskConfig {
  final String name;
  final String description;
  final Duration frequency;
  final bool enabled;

  const BuddyTaskConfig({
    required this.name,
    required this.description,
    required this.frequency,
    this.enabled = true,
  });

  BuddyTaskConfig copyWith({String? name, String? description, Duration? frequency, bool? enabled}) {
    return BuddyTaskConfig(
      name: name ?? this.name,
      description: description ?? this.description,
      frequency: frequency ?? this.frequency,
      enabled: enabled ?? this.enabled,
    );
  }
}