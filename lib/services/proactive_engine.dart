import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/context_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';

/// Events the ProactiveEngine can fire.
enum ProactiveEventType {
  calendarHeadsup,
  batteryLow,
  eveningRecap,
  contextualSuggestion,
}

/// A proactive suggestion the engine wants to surface to the user.
class ProactiveSuggestion {
  final ProactiveEventType type;
  final String title;
  final String body;
  final String? quickAction; // e.g. "navigiere zu Arbeit"
  final DateTime timestamp;

  ProactiveSuggestion({
    required this.type,
    required this.title,
    required this.body,
    this.quickAction,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

typedef ProactiveCallback = void Function(ProactiveSuggestion suggestion);

/// Background engine that checks device state and context periodically,
/// then fires proactive suggestions BEFORE the user asks.
///
/// Checks: calendar heads-up, battery guardian, evening recap.
class ProactiveEngine extends ChangeNotifier {
  final dynamic _llm;
  final MemoryService _memory;
  final PersonaService _persona;
  final ContextService _context;
  final FlutterLocalNotificationsPlugin _notifications;

  Timer? _ticker;
  bool _running = false;
  bool _initialized = false;

  /// Latest suggestion, if any. Consumed by the UI.
  ProactiveSuggestion? currentSuggestion;

  /// Callback for when a new suggestion is generated.
  ProactiveCallback? onSuggestion;

  /// Configuration
  final bool enableCalendarHeadsup;
  final bool enableBatteryGuardian;
  final bool enableEveningRecap;
  final int checkIntervalMinutes;

  /// Time windows (hour of day, local time)
  static const _eveningWindow = (20, 23); // 20:00-22:59
  static const _batteryThreshold = 20; // warn below 20%

  ProactiveEngine({
    required dynamic llm,
    required MemoryService memory,
    required PersonaService persona,
    FlutterLocalNotificationsPlugin? notifications,
    ContextService? context,
    this.enableCalendarHeadsup = true,
    this.enableBatteryGuardian = true,
    this.enableEveningRecap = true,
    this.checkIntervalMinutes = 15,
    this.onSuggestion,
  })  : _llm = llm,
        _memory = memory,
        _persona = persona,
        _context = context ?? ContextService(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  bool get isRunning => _running;

  /// Initialize notification channel and start the ticker.
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(initSettings);
    _initialized = true;
  }

  /// Start periodic checks.
  void start() {
    if (_running) return;
    _running = true;
    _scheduleNextCheck();
    // Also run immediately on start
    _runCheck();
  }

  /// Stop periodic checks cleanly.
  void stop() {
    _running = false;
    _ticker?.cancel();
    _ticker = null;
  }

  void _scheduleNextCheck() {
    _ticker?.cancel();
    if (!_running) return;
    _ticker = Timer(Duration(minutes: checkIntervalMinutes), () {
      if (_running) {
        _runCheck();
        _scheduleNextCheck();
      }
    });
  }

  Future<void> _runCheck() async {
    final now = DateTime.now();
    final hour = now.hour;
    final context = _context.currentContext();

    // ── Evening Recap ──
    if (enableEveningRecap &&
        hour >= _eveningWindow.$1 &&
        hour < _eveningWindow.$2) {
      final alreadyFiredToday = await _alreadyFired('evening_recap', now);
      if (!alreadyFiredToday) {
        await _fireEveningRecap(context, now);
        return;
      }
    }

    // ── Contextual Suggestion (general, any time) ──
    final suggestion = await _buildContextualSuggestion(context, now);
    if (suggestion != null) {
      _dispatchSuggestion(suggestion);
    }
  }

  // ─── Evening Recap ────────────────────────────────────────────────

  Future<void> _fireEveningRecap(ContextSnapshot ctx, DateTime now) async {
    try {
      final recentMemories =
          _memory.shortTermMemories.take(10).map((m) => m.content).toList();
      final memoryBlock = recentMemories.isNotEmpty
          ? 'Heutige Aktivitäten: ${recentMemories.join("; ")}'
          : '';

      final recap = await _llm.chat(
        systemPrompt:
            'Du bist ${_persona.name}, ein freundlicher KI-Assistent. '
            'Erstelle einen kurzen Tagesrückblick (max 3 Sätze). '
            'Sei warm und ermutigend.',
        messages: [
          {
            'role': 'user',
            'content': 'Der Tag neigt sich dem Ende. '
                'Fasse kurz zusammen und gib einen Ausblick auf morgen. '
                '$memoryBlock'
          }
        ],
      );

      final suggestion = ProactiveSuggestion(
        type: ProactiveEventType.eveningRecap,
        title: '🌙 Tagesrückblick',
        body: recap,
        quickAction: 'erinnere mich morgen an...',
      );
      await _markFired('evening_recap', now);
      _dispatchSuggestion(suggestion);
    } catch (e) {
      debugPrint('ProactiveEngine: evening recap failed: $e');
    }
  }

  // ─── Contextual Suggestion ────────────────────────────────────────

  Future<ProactiveSuggestion?> _buildContextualSuggestion(
      ContextSnapshot ctx, DateTime now) async {
    // Morning suggestion: suggest checking calendar
    if (ctx.timeOfDay == TimeOfDay.morning && now.hour >= 10) {
      final alreadyToday = await _alreadyFired('morning_suggestion', now);
      if (!alreadyToday) {
        await _markFired('morning_suggestion', now);
        return ProactiveSuggestion(
          type: ProactiveEventType.contextualSuggestion,
          title: 'Bereit für den Tag?',
          body: 'Soll ich deine Termine für heute checken?',
          quickAction: 'zeig meine Termine',
        );
      }
    }

    return null;
  }

  // ─── Battery Guardian (called from external battery events) ───────

  /// Call this from your battery info tool or a platform channel when
  /// battery drops below threshold.
  Future<void> checkBattery(int percentage, bool isCharging) async {
    if (!enableBatteryGuardian) return;
    if (isCharging) return;
    if (percentage > _batteryThreshold) return;
    // Don't spam — only fire once per low-battery session
    final already = await _alreadyFired('battery_low', DateTime.now());
    if (already) return;

    await _markFired('battery_low', DateTime.now());
    _dispatchSuggestion(ProactiveSuggestion(
      type: ProactiveEventType.batteryLow,
      title: '🔋 Akku niedrig ($percentage%)',
      body: 'Dein Akku ist bald leer. Soll ich Energiesparmodus aktivieren?',
      quickAction: 'oeffne Einstellungen',
    ));
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  void _dispatchSuggestion(ProactiveSuggestion suggestion) {
    currentSuggestion = suggestion;
    onSuggestion?.call(suggestion);

    // Fire native notification
    _notifications.show(
      suggestion.type.index,
      suggestion.title,
      suggestion.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'proactive_engine',
          'AI-Buddy Proaktiv',
          channelDescription: 'Proaktive Vorschläge und Erinnerungen',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );

    notifyListeners();
  }

  /// Track what we've already fired today to avoid duplicates.
  Future<bool> _alreadyFired(String key, DateTime now) async {
    final today = '${now.year}-${now.month}-${now.day}';
    final memories = _memory.longTermMemories;
    final match = memories.where((m) =>
        m.metadata['key'] == 'proactive:$key' && m.content == today);
    return match.isNotEmpty;
  }

  Future<void> _markFired(String key, DateTime now) async {
    final today = '${now.year}-${now.month}-${now.day}';
    await _memory.addLongTerm(today,
        metadata: {'key': 'proactive:$key'}, source: 'system');
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
