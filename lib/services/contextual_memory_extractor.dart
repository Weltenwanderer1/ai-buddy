/// Auto-extracted memory category.
/// Mirrors the [MemoryService] tier system: extracted facts → long-term.
enum MemoryCategory {
  personalInfo, // Name, Beruf, Familie
  preference,   // Vorlieben, Abneigungen
  relationship, // Bezug zu Personen
  event,        // Geplantes, Vergangenes
  fact,         // Allgemeine Wissen
  routine,      // Gewohnheiten, Muster
  goal,         // Ziele, Pläne
}

/// Score-based auto-extracted memory item.
/// The [tier] (1-10) denotes importance: 10 = critical, 1 = trivia.
class ExtractedMemory {
  final String content;
  final MemoryCategory category;
  final int tier;
  final DateTime timestamp;

  const ExtractedMemory({
    required this.content,
    required this.category,
    required this.tier,
    required this.timestamp,
  });

  bool get isImportant => tier >= 6;
  bool get isCore => tier >= 9;
}

/// Heuristic-based contextual memory extractor.
/// Runs **locally** (no LLM call) to keep latency low.
///
/// Strategy: pattern-matching on the *combined* user+assistant text
/// to find facts the user cares about. Scores are conservative
/// to avoid noise — anything tier < 5 is discarded.
class ContextualMemoryExtractor {
  static const int _maxExtractionsPerTurn = 3;

  /// Extract memories from a complete turn (user msg + assistant reply).
  /// Returns up to [_maxExtractionsPerTurn] scored items.
  List<ExtractedMemory> extract(String userMsg, String assistantReply) {
    final combined = '$userMsg\n$assistantReply'.toLowerCase();
    final results = <ExtractedMemory>[];

    // ── Personal Info ──
    _extractPattern(combined, _personalNamePatterns, MemoryCategory.personalInfo, baseTier: 7, results: results);
    _extractPattern(combined, _familyPatterns,       MemoryCategory.personalInfo, baseTier: 8, results: results);
    _extractPattern(combined, _jobPatterns,          MemoryCategory.personalInfo, baseTier: 7, results: results);

    // ── Preferences ──
    _extractPattern(combined, _preferencePatterns,   MemoryCategory.preference,   baseTier: 5, results: results);

    // ── Events ──
    _extractPattern(combined, _eventPatterns,         MemoryCategory.event,         baseTier: 6, results: results);

    // ── Routines ──
    _extractPattern(combined, _routinePatterns,       MemoryCategory.routine,       baseTier: 5, results: results);

    // ── Goals ──
    _extractPattern(combined, _goalPatterns,          MemoryCategory.goal,          baseTier: 7, results: results);

    // Cap and sort by tier (highest first)
    results.sort((a, b) => b.tier.compareTo(a.tier));
    return results.take(_maxExtractionsPerTurn).toList();
  }

  /// Extract a single memory from a specific user message (e.g. after
  /// save_memory tool was called with user text).
  ExtractedMemory? extractSingle(String text) {
    final combined = text.toLowerCase();
    final results = <ExtractedMemory>[];
    _extractPattern(combined, _personalNamePatterns, MemoryCategory.personalInfo, baseTier: 7, results: results);
    _extractPattern(combined, _familyPatterns,       MemoryCategory.personalInfo, baseTier: 8, results: results);
    _extractPattern(combined, _jobPatterns,          MemoryCategory.personalInfo, baseTier: 7, results: results);
    _extractPattern(combined, _preferencePatterns,   MemoryCategory.preference,   baseTier: 5, results: results);
    _extractPattern(combined, _eventPatterns,         MemoryCategory.event,         baseTier: 6, results: results);
    _extractPattern(combined, _routinePatterns,       MemoryCategory.routine,       baseTier: 5, results: results);
    _extractPattern(combined, _goalPatterns,          MemoryCategory.goal,          baseTier: 7, results: results);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.tier.compareTo(a.tier));
    return results.first;
  }

  // ── Pattern Lists ──

  static final _personalNamePatterns = [
    _Pattern(r'\b(ich heiße|mein name ist|nenn mich|ich bin)\s+([a-zäöüß]+)', 2, bonus: 1),
    _Pattern(r'\b(ich bin|ich arbeite als)\s+([a-zäöüß\s]+)(pädagogin|erzieher|lehrer|ärztin|ingenieur|entwickler)', 2, bonus: 1),
  ];

  static final _familyPatterns = [
    _Pattern(r'\b(meine frau|mein mann|mein partner|meine partnerin)\s+heißt\s+([a-zäöüß]+)', 2, bonus: 2),
    _Pattern(r'\b(mein sohn|meine tochter|mein kind)\s+heißt\s+([a-zäöüß]+)', 2, bonus: 2),
    _Pattern(r'\b(atreju|ellie|saskia|aju)\b', 0, bonus: 2), // already known names from context
    _Pattern(r'\b(vater von|mutter von|eltern von)\s+([a-zäöüß]+)', 0, bonus: 2),
  ];

  static final _jobPatterns = [
    _Pattern(r'\b(arbeite bei|job bei|stelle als)\s+([a-zäöüß\s]+)', 2, bonus: 1),
    _Pattern(r'\b(elementar|kindergarten|schule|pädagog|erzieh)', 0, bonus: 1),
  ];

  static final _preferencePatterns = [
    _Pattern(r'\b(ich mag|ich liebe|ich hasse|ich mag kein|nicht mein)\s+([a-zäöüß\s]+)', 2, bonus: 1),
    _Pattern(r'\b(mein favorit|mein lieblings|am liebsten|bevorzuge)', 0, bonus: 1),
    _Pattern(r'\b(immer|nie|oft|selten)\s+([a-zäöüß\s]+)', 1, bonus: 1),
  ];

  static final _eventPatterns = [
    _Pattern(r'\b(geburtstag|jubiläum|hochzeit|termin|verabredung)\s+(?:von|am|für)?\s*([^.\n]*)', 1, bonus: 1),
    _Pattern(r'\b(am\s+\d+\.\s*(?:jan|feb|mär|apr|mai|jun|jul|aug|sep|okt|nov|dez)[^\n.]*)', 0, bonus: 1),
    _Pattern(r'\b(nächste woche|nächsten monat|übermorgen|morgen)\s+([^.\n]*)', 1, bonus: 1),
  ];

  static final _routinePatterns = [
    _Pattern(r'\b(jeden tag|täglich|immer um|regelmäßig|jeden\s+[a-z]+)\s+([^.\n]*)', 1, bonus: 1),
    _Pattern(r'\b(meine routine|mein ritual|gewohnheit)', 0, bonus: 1),
  ];

  static final _goalPatterns = [
    _Pattern(r'\b(ich will|ich möchte|mein ziel|ich plane|vorhaben)\s+([^.\n]*)', 1, bonus: 2),
    _Pattern(r'\b(bis\s+(?:morgen|nächste woche|nächstes jahr|ende des)\s+[^.\n]*)', 0, bonus: 1),
  ];

  // ── Core extraction logic ──

  void _extractPattern(
    String combined,
    List<_Pattern> patterns,
    MemoryCategory category, {
    required int baseTier,
    required List<ExtractedMemory> results,
  }) {
    for (final p in patterns) {
      final regex = RegExp(p.regex, caseSensitive: false);
      for (final match in regex.allMatches(combined)) {
        // Prefer group 2 (actual content), fall back to full match
        var raw = match.groupCount >= 2 && match.group(2) != null
            ? match.group(2)!
            : match.group(0)!;
        raw = raw.trim();
        if (raw.length < 3 || raw.length > 200) continue;

        // Deduplicate against existing results (same-ish content)
        final isDuplicate = results.any((r) => _similarity(r.content, raw) > 0.75);
        if (isDuplicate) continue;

        // Build a clean sentence
        var clean = _cleanSentence(raw);
        final tier = (baseTier + p.bonus).clamp(1, 10);

        results.add(ExtractedMemory(
          content: clean,
          category: category,
          tier: tier,
          timestamp: DateTime.now(),
        ));
      }
    }
  }

  static String _cleanSentence(String raw) {
    // Capitalize first letter, add period if missing
    var s = raw.trim();
    if (s.isEmpty) return s;
    s = s[0].toUpperCase() + s.substring(1);
    if (!s.endsWith('.') && !s.endsWith('!') && !s.endsWith('?')) {
      s = '$s.';
    }
    return s;
  }

  static double _similarity(String a, String b) {
    final ta = a.toLowerCase().split(RegExp(r'\s+')).toSet();
    final tb = b.toLowerCase().split(RegExp(r'\s+')).toSet();
    if (ta.isEmpty || tb.isEmpty) return 0.0;
    final inter = ta.intersection(tb).length;
    return inter / (ta.length + tb.length - inter);
  }
}

class _Pattern {
  final String regex;
  final int group; // which capture group holds the content
  final int bonus; // added to baseTier

  const _Pattern(this.regex, this.group, {this.bonus = 0});
}
