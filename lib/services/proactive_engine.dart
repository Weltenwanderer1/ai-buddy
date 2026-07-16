import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'memory_service.dart';
import 'location_service.dart';
import 'timer_service.dart';
import 'proactive_notification_service.dart';
import '../tools/get_calendar_events_tool.dart';
import '../tools/get_weather_tool.dart';

import 'dart:math' as math;

/// Proactivity level: 0=off, 1=low (only urgent), 2=normal (time+location),
/// 3=high (suggestions, routines, learning).
enum ProactivityLevel { off, low, normal, high }

/// Triggers the engine can react to.
enum ProactiveTriggerType {
  timeOfDay,
  calendar,
  location,
  timer,
  weather,
  memory,
  routine,
  custom,
}

/// An active geofence-like POI (point of interest).
class _Poi {
  final String name;
  final String category;
  final double lat;
  final double lng;
  final double radiusMeters;
  final String? suggestedAction;

  _Poi({
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    this.radiusMeters = 200,
    this.suggestedAction,
  });

  double distanceTo(double otherLat, double otherLng) {
    const earthRadius = 6371000.0;
    final dLat = _rad(otherLat - lat);
    final dLng = _rad(otherLng - lng);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(otherLat)) *
            math.pow(math.sin(dLng / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  static double _rad(double deg) => deg * math.pi / 180;
}

// ── ProactiveEngine v3 ──
/// Erweitert Zeit-Trigger um Location, Wetter, Timer und Routinen.
class ProactiveEngine {
  final MemoryService _memory;
  LocationService? _locationService;
  TimerService? _timerService;
  ProactiveNotificationService? _notificationService;

  SharedPreferences? _prefs;
  Timer? _timer;
  bool _running = false;
  bool _initialized = false;

  /// Proactivity level from settings (0-3)
  ProactivityLevel _level = ProactivityLevel.normal;

  /// Callback injected after init — routes to ChatScreen
  void Function(String message, {List<Map<String, String>>? actions})? _onMessage;

  // ── POIs (learned + hardcoded) ──
  final List<_Poi> _pois = [];

  ProactiveEngine({
    required MemoryService memory,
    LocationService? locationService,
    TimerService? timerService,
    ProactiveNotificationService? notificationService,
  })  : _memory = memory,
        _locationService = locationService,
        _timerService = timerService,
        _notificationService = notificationService;

  void setLevel(ProactivityLevel level) {
    _level = level;
    debugPrint('ProactiveEngine: level = $level');
  }

  void setServices({
    LocationService? locationService,
    TimerService? timerService,
    ProactiveNotificationService? notificationService,
  }) {
    _locationService = locationService ?? _locationService;
    _timerService = timerService ?? _timerService;
    _notificationService = notificationService ?? _notificationService;
  }

  /// Initialize shared prefs and dependencies.
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadPois();
    _initialized = true;
    debugPrint('ProactiveEngine v3 initialized (level=$_level)');
  }

  /// Start periodic checks (every 15 min + once immediately).
  void start({
    void Function(String message, {List<Map<String, String>>? actions})? onMessage,
  }) {
    if (!_initialized) {
      debugPrint('ProactiveEngine: start() called before init()');
      return;
    }
    if (_level == ProactivityLevel.off) {
      debugPrint('ProactiveEngine: disabled (level=off)');
      return;
    }
    if (_running) return;
    _running = true;
    _onMessage = onMessage;

    // Immediate first check
    _check();

    // Periodic: every 15 minutes (finer for location triggers)
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _check());
    debugPrint('ProactiveEngine v3 started');
  }

  /// Stop the periodic timer.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    debugPrint('ProactiveEngine v3 stopped');
  }

  // ─── Core Logic ───────────────────────────────────────────

  static const _lastKey = 'proactive_last_trigger_v3';
  static const _lastTextKey = 'proactive_last_text_v3';
  static const _minHoursLow = 8;
  static const _minHoursNormal = 4;
  static const _minHoursHigh = 2;

  Future<void> _check() async {
    if (!_running || _prefs == null) return;
    final prefs = _prefs;
    if (prefs == null) return;

    try {
      // Debounce based on level
      final minHours = _level == ProactivityLevel.high
          ? _minHoursHigh
          : _level == ProactivityLevel.low
              ? _minHoursLow
              : _minHoursNormal;
      final lastStr = prefs.getString(_lastKey);
      if (lastStr != null) {
        final last = DateTime.tryParse(lastStr);
        if (last != null && DateTime.now().difference(last) < Duration(hours: minHours)) {
          return;
        }
      }

      final now = DateTime.now();
      final hour = now.hour;
      final msgs = <_ProactiveMsg>[];
      final events = await _fetchCalendarEvents();

      // ── 1. Calendar checks (all levels) ──
      _checkCalendar(events, now, hour, msgs);

      // ── 2. Time-of-day greetings & routines (normal+) ──
      if (_level.index >= ProactivityLevel.normal.index) {
        _checkTimeOfDay(hour, msgs);
        _checkRoutines(hour, msgs);
      }

      // ── 3. Core-memory hints (all levels, but filtered by level) ──
      _checkMemoryTriggers(hour, msgs);

      // ── 4. Location triggers (normal+) ──
      if (_level.index >= ProactivityLevel.normal.index) {
        await _checkLocationTriggers(msgs);
      }

      // ── 5. Timer awareness (normal+) ──
      if (_level.index >= ProactivityLevel.normal.index) {
        _checkTimers(msgs);
      }

      // ── 6. Weather (high only, morning) ──
      if (_level == ProactivityLevel.high && (hour >= 6 && hour <= 9)) {
        await _checkWeather(msgs);
      }

      if (msgs.isEmpty) return;

      // Pick best, filter duplicates
      msgs.sort((a, b) => b.urgency.compareTo(a.urgency));
      final chosen = msgs.first;

      final lastText = prefs.getString(_lastTextKey);
      if (lastText == chosen.text) return;

      await prefs.setString(_lastKey, now.toIso8601String());
      await prefs.setString(_lastTextKey, chosen.text);

      // Send as chat message (if foreground) or notification (if background)
      _onMessage?.call(chosen.text, actions: chosen.actions);

      // Also push notification for high-priority items
      if (chosen.urgency >= 8 && _notificationService != null) {
        final actions = <ProactiveAction>[];
        for (final a in chosen.actions) {
          actions.add(ProactiveAction(
            id: a['id'] ?? 'action_${DateTime.now().millisecondsSinceEpoch}',
            label: a['label'] ?? 'OK',
            payload: a['payload'],
          ));
        }
        await _notificationService!.sendNotification(
          type: chosen.triggerType == ProactiveTriggerType.calendar
              ? ProactiveNotificationType.calendarHeadsup
              : ProactiveNotificationType.contextualSuggestion,
          title: _titleForTrigger(chosen.triggerType),
          body: chosen.text,
          actions: actions,
        );
      }
    } catch (e) {
      debugPrint('ProactiveEngine v3 check error: $e');
    }
  }

  // ── Calendar ──
  void _checkCalendar(List<Map<String, dynamic>> events, DateTime now, int hour, List<_ProactiveMsg> msgs) {
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
      final start = _parseDate(next['start']);
      if (start == null) return;
      final diff = start.difference(now);
      final title = next['title'] as String? ?? 'Termin';

      if (diff.inMinutes <= 30 && diff.inMinutes > 0) {
        msgs.add(_ProactiveMsg(
          text: '⏰ "$title" in ${diff.inMinutes} Minuten!',
          urgency: 10,
          triggerType: ProactiveTriggerType.calendar,
          actions: [
            {'id': 'open_calendar', 'label': '📅 Kalender', 'payload': 'open_calendar'},
            {'id': 'navigate', 'label': '🧭 Navigation', 'payload': 'navigate_to_event'},
          ],
        ));
      } else if (diff.inHours <= 2) {
        msgs.add(_ProactiveMsg(
          text: '📅 "$title" in ${diff.inHours}h ${diff.inMinutes % 60}min.',
          urgency: 8,
          triggerType: ProactiveTriggerType.calendar,
        ));
      } else if (hour >= 7 && hour <= 10) {
        msgs.add(_ProactiveMsg(
          text: '📅 Heute: ${upcoming.map((e) => e['title']).join(", ")}',
          urgency: 5,
          triggerType: ProactiveTriggerType.calendar,
        ));
      }
    }
  }

  // ── Time of day ──
  void _checkTimeOfDay(int hour, List<_ProactiveMsg> msgs) {
    if (hour >= 7 && hour <= 9) {
      final greeting = _morningGreeting();
      if (greeting != null) {
        msgs.add(_ProactiveMsg(
          text: greeting,
          urgency: 4,
          triggerType: ProactiveTriggerType.timeOfDay,
          actions: [
            {'id': 'check_day', 'label': '☀️ Check den Tag', 'payload': 'check_day'},
          ],
        ));
      }
    } else if (hour >= 20 && hour <= 22) {
      final recap = _eveningRecap();
      if (recap != null) {
        msgs.add(_ProactiveMsg(
          text: recap,
          urgency: 3,
          triggerType: ProactiveTriggerType.timeOfDay,
        ));
      }
    } else if (hour >= 12 && hour <= 13) {
      msgs.add(_ProactiveMsg(
        text: '🍕 Mittagszeit — sollen wir kurz den Tag checken?',
        urgency: 2,
        triggerType: ProactiveTriggerType.timeOfDay,
      ));
    }
  }

  // ── Routines (learned) ──
  void _checkRoutines(int hour, List<_ProactiveMsg> msgs) {
    for (final mem in _memory.longTermMemories) {
      final meta = mem.metadata;
      final trigger = meta['routineTrigger'];
      if (trigger == null) continue;

      final triggerHour = meta['routineHour'] as int?;
      final triggerDays = (meta['routineDays'] as List<dynamic>?)?.cast<int>() ?? [];
      final weekday = DateTime.now().weekday;

      if (triggerHour != null && hour == triggerHour) {
        if (triggerDays.isEmpty || triggerDays.contains(weekday)) {
          msgs.add(_ProactiveMsg(
            text: '🔁 Routine: $trigger',
            urgency: 4,
            triggerType: ProactiveTriggerType.routine,
            actions: [
              {'id': 'do_it', 'label': '✅ Mach ich', 'payload': 'confirm_routine'},
              {'id': 'later', 'label': '⏰ Später', 'payload': 'snooze_routine'},
            ],
          ));
        }
      }
    }
  }

  // ── Memory triggers ──
  void _checkMemoryTriggers(int hour, List<_ProactiveMsg> msgs) {
    for (final mem in _memory.coreMemories) {
      final text = mem.content;
      final lower = text.toLowerCase();
      if (lower.contains('morgen') && hour < 10) {
        msgs.add(_ProactiveMsg(
          text: '🧠 Erinnerung: $text',
          urgency: 6,
          triggerType: ProactiveTriggerType.memory,
        ));
      }
      if (lower.contains('abend') && hour >= 18) {
        msgs.add(_ProactiveMsg(
          text: '🧠 Erinnerung: $text',
          urgency: 5,
          triggerType: ProactiveTriggerType.memory,
        ));
      }
      // High level: check for project keywords
      if (_level == ProactivityLevel.high) {
        if (lower.contains('baustelle') || lower.contains('projekt') || lower.contains('terrass')) {
          msgs.add(_ProactiveMsg(
            text: '🏗️ Projekt-Erinnerung: $text',
            urgency: 5,
            triggerType: ProactiveTriggerType.memory,
            actions: [
              {'id': 'note', 'label': '📝 Notiz', 'payload': 'add_project_note'},
            ],
          ));
        }
      }
    }
  }

  // ── Location triggers ──
  Future<void> _checkLocationTriggers(List<_ProactiveMsg> msgs) async {
    if (_locationService == null) return;
    final loc = await _locationService!.getLocation();
    if (loc == null) return;

    for (final poi in _pois) {
      final dist = poi.distanceTo(loc.latitude, loc.longitude);
      if (dist <= poi.radiusMeters) {
        // Check if we already triggered for this POI today
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final key = 'proactive_poi_${poi.name}_$today';
        if (_prefs?.getString(key) == today) continue;
        await _prefs?.setString(key, today);

        msgs.add(_ProactiveMsg(
          text: poi.suggestedAction ?? '📍 Du bist bei ${poi.name}. Brauchst du was?',
          urgency: 7,
          triggerType: ProactiveTriggerType.location,
          actions: [
            {'id': 'yes_${poi.name}', 'label': '👍 Ja', 'payload': 'poi_yes'},
            {'id': 'no_${poi.name}', 'label': '👎 Nein', 'payload': 'poi_no'},
          ],
        ));
      }
    }
  }

  // ── Timer awareness ──
  void _checkTimers(List<_ProactiveMsg> msgs) {
    if (_timerService == null) return;
    final timers = _timerService!.activeTimers;
    if (timers.isEmpty) return;

    // Alert if timer expires in < 2 min
    for (final t in timers) {
      final remaining = t.remainingSeconds;
      if (remaining > 0 && remaining <= 120) {
        msgs.add(_ProactiveMsg(
          text: '⏱️ "${t.label}" läuft in ${remaining ~/ 60} Min ab!',
          urgency: 9,
          triggerType: ProactiveTriggerType.timer,
          actions: [
            {'id': 'add_5min', 'label': '+5 Min', 'payload': 'timer_extend_${t.id}'},
          ],
        ));
      }
    }
  }

  // ── Weather (high level) ──
  Future<void> _checkWeather(List<_ProactiveMsg> msgs) async {
    try {
      final tool = GetWeatherTool(locationService: _locationService!);
      final result = await tool.execute({'forecast_days': 1});
      final text = result.result.toLowerCase();

      // Rain check
      if (text.contains('regen') || text.contains('niederschlag')) {
        msgs.add(_ProactiveMsg(
          text: '🌧️ Achtung, Regen heute! Regenschirm mitnehmen?',
          urgency: 6,
          triggerType: ProactiveTriggerType.weather,
        ));
      }
      // Cold check
      final tempMatch = RegExp(r'(-?\d+)°c').firstMatch(text);
      if (tempMatch != null) {
        final temp = int.tryParse(tempMatch.group(1) ?? '');
        if (temp != null && temp < 5) {
          msgs.add(_ProactiveMsg(
            text: '🥶 Brrr, nur $temp°C heute. Warm anziehen!',
            urgency: 5,
            triggerType: ProactiveTriggerType.weather,
          ));
        }
      }
    } catch (e) {
      debugPrint('ProactiveEngine weather check error: $e');
    }
  }

  // ── Helpers ──

  String? _morningGreeting() {
    final core = _memory.coreMemories;
    final hint = core.where((m) => m.content.toLowerCase().contains('name')).firstOrNull;
    if (hint != null) return '☀️ Guten Morgen! ${hint.content}';
    return '☀️ Guten Morgen! Soll ich die Termine für heute checken?';
  }

  String? _eveningRecap() {
    return '🌙 Der Tag neigt sich dem Ende — noch was offen?';
  }

  String _titleForTrigger(ProactiveTriggerType type) {
    switch (type) {
      case ProactiveTriggerType.calendar:
        return '📅 Termin-Erinnerung';
      case ProactiveTriggerType.timeOfDay:
        return '⏰ Tagesroutine';
      case ProactiveTriggerType.location:
        return '📍 Ortsbasiert';
      case ProactiveTriggerType.weather:
        return '🌤️ Wetter-Check';
      case ProactiveTriggerType.memory:
        return '🧠 Erinnerung';
      case ProactiveTriggerType.routine:
        return '🔁 Routine';
      default:
        return '💡 Kiro sagt';
    }
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

  // ── POI Management ──

  /// Learn a new POI from user data or hardcode one.
  Future<void> addPoi({
    required String name,
    required String category,
    required double lat,
    required double lng,
    double radiusMeters = 200,
    String? suggestedAction,
  }) async {
    _pois.add(_Poi(
      name: name,
      category: category,
      lat: lat,
      lng: lng,
      radiusMeters: radiusMeters,
      suggestedAction: suggestedAction,
    ));
    await _savePois();
  }

  Future<void> removePoi(String name) async {
    _pois.removeWhere((p) => p.name == name);
    await _savePois();
  }

  Future<void> _savePois() async {
    final data = _pois.map((p) => {
      'name': p.name,
      'category': p.category,
      'lat': p.lat,
      'lng': p.lng,
      'radiusMeters': p.radiusMeters,
      'suggestedAction': p.suggestedAction,
    }).toList();
    await _prefs?.setString('proactive_pois', jsonEncode(data));
  }

  Future<void> _loadPois() async {
    try {
      final data = _prefs?.getString('proactive_pois');
      if (data == null) return;
      final list = jsonDecode(data) as List<dynamic>;
      _pois.clear();
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        _pois.add(_Poi(
          name: map['name'] as String,
          category: map['category'] as String,
          lat: (map['lat'] as num).toDouble(),
          lng: (map['lng'] as num).toDouble(),
          radiusMeters: (map['radiusMeters'] as num?)?.toDouble() ?? 200,
          suggestedAction: map['suggestedAction'] as String?,
        ));
      }
    } catch (e) {
      debugPrint('ProactiveEngine POI load error: $e');
    }

    // Seed default POIs if empty
    if (_pois.isEmpty) {
      // Baumarkt area (approximate)
      _pois.add(_Poi(
        name: 'Baumarkt-Gegend',
        category: 'shopping',
        lat: 48.2305,
        lng: 16.3365,
        radiusMeters: 300,
        suggestedAction: '🏗️ Du bist beim Baumarkt — brauchst du noch Dübel oder Farbe für die Terrasse?',
      ));
      // Supermarkt area
      _pois.add(_Poi(
        name: 'Supermarkt-Gegend',
        category: 'shopping',
        lat: 48.2295,
        lng: 16.3380,
        radiusMeters: 200,
        suggestedAction: '🛒 Du bist beim Supermarkt — Milch oder Brötchen noch nötig?',
      ));
      await _savePois();
    }
  }
}

/// Internal message candidate with scoring.
class _ProactiveMsg {
  final String text;
  final int urgency; // 1-10
  final ProactiveTriggerType triggerType;
  final List<Map<String, String>> actions;

  _ProactiveMsg({
    required this.text,
    required this.urgency,
    required this.triggerType,
    this.actions = const [],
  });
}
