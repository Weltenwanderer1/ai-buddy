/// Simple time-of-day and context classification without requiring
/// network or model access. Used by ProactiveEngine and QuickActions.
enum TimeOfDay {
  earlyMorning, // 00:00-05:59
  morning,      // 06:00-11:59
  afternoon,    // 12:00-16:59
  evening,      // 17:00-20:59
  night,        // 21:00-23:59
}

class ContextSnapshot {
  final TimeOfDay timeOfDay;
  final int hour;
  final int weekday; // 1 = Monday, 7 = Sunday
  final String? location; // e.g. "Wien, 1180 Österreich (48.21, 16.35)"

  const ContextSnapshot({
    required this.timeOfDay,
    required this.hour,
    required this.weekday,
    this.location,
  });

  bool get isWeekend => weekday == 6 || weekday == 7;
  bool get isWorkday => !isWeekend;

  @override
  String toString() =>
      'ContextSnapshot(timeOfDay: $timeOfDay, hour: $hour, weekday: $weekday, location: $location)';
}

class ContextService {
  ContextSnapshot currentContext({String? location}) {
    final now = DateTime.now();
    return ContextSnapshot(
      timeOfDay: _classifyHour(now.hour),
      hour: now.hour,
      weekday: now.weekday,
      location: location,
    );
  }

  static TimeOfDay _classifyHour(int hour) {
    if (hour < 6) return TimeOfDay.earlyMorning;
    if (hour < 12) return TimeOfDay.morning;
    if (hour < 17) return TimeOfDay.afternoon;
    if (hour < 21) return TimeOfDay.evening;
    return TimeOfDay.night;
  }

  /// Quick action suggestions based on context.
  static List<QuickActionDef> suggestedActions(ContextSnapshot ctx) {
    switch (ctx.timeOfDay) {
      case TimeOfDay.earlyMorning:
      case TimeOfDay.morning:
        return [
          QuickActionDef('Briefing', 'was steht heute an?'),
          QuickActionDef('Navi', 'navigiere zu '),
          QuickActionDef('Timer', 'stell einen Timer auf '),
          QuickActionDef('Termine', 'zeig meine Termine'),
          QuickActionDef('Notiz', 'schreib eine Notiz: '),
          QuickActionDef('Akku', 'wie ist der Akku?'),
        ];
      case TimeOfDay.afternoon:
        return [
          QuickActionDef('Navi', 'navigiere zu '),
          QuickActionDef('SMS', 'sende SMS an '),
          QuickActionDef('Apps', 'oeffne '),
          QuickActionDef('Suche', 'such im Web nach '),
          QuickActionDef('Timer', 'stell einen Timer auf '),
          QuickActionDef('Notiz', 'schreib eine Notiz: '),
        ];
      case TimeOfDay.evening:
        return [
          QuickActionDef('Apps', 'oeffne '),
          QuickActionDef('SMS', 'sende SMS an '),
          QuickActionDef('Timer', 'stell einen Timer auf '),
          QuickActionDef('Notiz', 'schreib eine Notiz: '),
          QuickActionDef('Rückblick', 'wie war mein Tag?'),
          QuickActionDef('Akku', 'wie ist der Akku?'),
        ];
      case TimeOfDay.night:
        return [
          QuickActionDef('Timer', 'stell einen Timer auf '),
          QuickActionDef('Ruhe', 'gute Nacht'),
          QuickActionDef('Apps', 'oeffne '),
          QuickActionDef('Notiz', 'schreib eine Notiz: '),
          QuickActionDef('Morgen', 'erinnere mich morgen an'),
          QuickActionDef('Akku', 'wie ist der Akku?'),
        ];
    }
  }
}

class QuickActionDef {
  final String label;
  final String prefix;

  const QuickActionDef(this.label, this.prefix);
}
