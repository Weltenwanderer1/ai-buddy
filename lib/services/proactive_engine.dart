import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';
import '../tools/get_calendar_events_tool.dart';

/// Intelligent pro-active thinking engine v2.
/// Runs locally (zero API tokens), generates contextual hints based on
/// calendar, time-of-day, learned patterns and core memories.
///
/// API compatible with ChatScreen (expects .init()/.start()/.stop()).
class ProactiveEngine {
  final MemoryService _memory;

  SharedPreferences? _prefs;
  Timer? _timer;
  bool _running = false;
  bool _initialized = false;

  // Callback injected after init
  void Function(String message)? _onMessage;

  ProactiveEngine({
    required MemoryService memory,
  })  : _memory = memory;

  /// Initialize shared prefs and dependencies.
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    debugPrint('ProactiveEngine v2 initialized');
  }

  /// Start periodic checks (every 30 min + once immediately).
  void start({void Function(String message)? onMessage}) {
    if (!_initialized) {
      debugPrint('ProactiveEngine: start() called before init()');
      return;
    }
    if (_running) return;
    _running = true;
    _onMessage = onMessage;

    // Immediate first check
    _check();

    // Periodic every 30 minutes
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check());
    debugPrint('ProactiveEngine v2 started');
  }

  /// Stop the periodic timer.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('ProactiveEngine v2 stopped');
  }

  // ─── Core Logic ───────────────────────────────────────────

  static const _lastKey = 'proactive_last_trigger_v2';
  static const _lastTextKey = 'proactive_last_text_v2';
  static const _minHours = 4;

  Future<void> _check() async {
    if (!_running || _prefs == null) return;
    try {
      // Debounce
      final lastStr = _prefs!.getString(_lastKey);
      if (lastStr != null) {
        final last = DateTime.tryParse(lastStr);
        if (last != null &&
            DateTime.now().difference(last) < const Duration(hours: _minHours)) {
          return;
        }
      }

      final now = DateTime.now();
      final hour = now.hour;
      final msgs = <String>[];
      final events = await _fetchCalendarEvents();

      // ── 1. Calendar checks ──
      if (events.isNotEmpty) {
        final upcoming = events.where((e) {
          final s = _parseDate(e['start']);
          if (s == null) return false;
          final d = s.difference(now);
          return d.inHours >= 0 && d.inHours <= 24;
        }).toList();

        if (upcoming.isNotEmpty) {
          upcoming.sort((a, b) {
            final sa = _parseDate(a['start']) ?? now;
            final sb = _parseDate(b['start']) ?? now;
            return sa.compareTo(sb);
          });

          final next = upcoming.first;
          final s = _parseDate(next['start'])!;
          final diff = s.difference(now);
          final title = next['title'] as String? ?? 'Termin';

          if (diff.inMinutes <= 30 && diff.inMinutes > 0) {
            msgs.add('⏰ "$title" in ${diff.inMinutes} Minuten!');
          } else if (diff.inHours <= 2) {
            msgs.add('📅 "$title" in ${diff.inHours}h ${diff.inMinutes % 60}min.');
          } else if (hour >= 7 && hour <= 10) {
            msgs.add('📅 Heute: ${upcoming.map((e) => e['title']).join(", ")}');
          }
        }
      }

      // ── 2. Time-of-day greetings ──
      if (hour >= 7 && hour <= 9) {
        final greeting = _morningGreeting();
        if (greeting != null) msgs.add(greeting);
      } else if (hour >= 20 && hour <= 22) {
        final recap = await _eveningRecap(events);
        if (recap != null) msgs.add(recap);
      } else if (hour >= 12 && hour <= 13) {
        msgs.add('🍕 Mittagszeit — sollen wir kurz den Tag checken?');
      }

      // ── 3. Core-memory hints ──
      for (final mem in _memory.coreMemories) {
        final text = mem.content;
        final lower = text.toLowerCase();
        if (lower.contains('morgen') && hour < 10) msgs.add('🧠 Erinnerung: $text');
        if (lower.contains('abend') && hour >= 18) msgs.add('🧠 Erinnerung: $text');
      }

      if (msgs.isEmpty) return;

      final chosen = _pickBest(msgs);
      final lastText = _prefs!.getString(_lastTextKey);
      if (lastText == chosen) return;

      await _prefs!.setString(_lastKey, now.toIso8601String());
      await _prefs!.setString(_lastTextKey, chosen);
      _onMessage?.call(chosen);
    } catch (e) {
      debugPrint('ProactiveEngine v2 check error: $e');
    }
  }

  /// Pick the most urgent/relevant message.
  String _pickBest(List<String> msgs) {
    for (final m in msgs) {
      if (m.startsWith('⏰')) return m;
    }
    for (final m in msgs) {
      if (m.startsWith('📅')) return m;
    }
    return msgs.first;
  }

  String? _morningGreeting() {
    final core = _memory.coreMemories;
    final hint = core.where((m) => m.content.toLowerCase().contains('name')).firstOrNull;
    if (hint != null) return '☀️ Guten Morgen! ${hint.content}';
    return '☀️ Guten Morgen! Soll ich die Termine für heute checken?';
  }

  Future<String?> _eveningRecap(List<Map<String, dynamic>> events) async {
    final tomorrow = events.where((e) {
      final s = _parseDate(e['start']);
      if (s == null) return false;
      final n = DateTime.now();
      final tStart = DateTime(n.year, n.month, n.day + 1);
      final tEnd = tStart.add(const Duration(days: 1));
      return s.isAfter(tStart) && s.isBefore(tEnd);
    }).toList();

    if (tomorrow.isNotEmpty) {
      final titles = tomorrow.map((e) => '"${e['title']}"').join(', ');
      return '🌙 Heads-up für morgen: $titles';
    }
    return '🌙 Der Tag neigt sich dem Ende — noch was offen?';
  }

  Future<List<Map<String, dynamic>>> _fetchCalendarEvents() async {
    if (GetCalendarEventsTool.getEventsCallback == null) return [];
    try {
      return await GetCalendarEventsTool.getEventsCallback!(daysAhead: 2);
    } catch (e) {
      debugPrint('ProactiveEngine calendar fetch error: $e');
      return [];
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt;
      final match = RegExp(r'(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})').firstMatch(value);
      if (match != null) {
        return DateTime(
          int.parse(match.group(3)!),
          int.parse(match.group(2)!),
          int.parse(match.group(1)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
        );
      }
    }
    return null;
  }
}
