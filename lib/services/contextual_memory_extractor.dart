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

    // ── Personal Info — enriched with context ──
    _extractPattern(combined, _personalNamePatterns, MemoryCategory.personalInfo, baseTier: 7, results: results,
      enricher: (match, fullText) => _enrichPersonalName(match, fullText));
    _extractPattern(combined, _familyPatterns, MemoryCategory.personalInfo, baseTier: 8, results: results,
      enricher: (match, fullText) => _enrichFamily(match, fullText));
    _extractPattern(combined, _jobPatterns, MemoryCategory.personalInfo, baseTier: 7, results: results,
      enricher: (match, fullText) => _enrichJob(match, fullText));

    // ── Preferences — enriched ──
    _extractPattern(combined, _preferencePatterns, MemoryCategory.preference, baseTier: 5, results: results,
      enricher: (match, fullText) => _enrichPreference(match, fullText));

    // ── Events ──
    _extractPattern(combined, _eventPatterns, MemoryCategory.event, baseTier: 6, results: results,
      enricher: (match, fullText) => _enrichEvent(match, fullText));

    // ── Routines ──
    _extractPattern(combined, _routineTriggerPatterns, MemoryCategory.routine, baseTier: 5, results: results,
      enricher: (match, fullText) => _enrichRoutine(match, fullText));

    // ── Purchases ──
    _extractPattern(combined, _purchasePatterns, MemoryCategory.fact, baseTier: 4, results: results,
      enricher: (match, fullText) => _enrichPurchase(match, fullText));

    // ── Projects ──
    _extractPattern(combined, _projectPatterns, MemoryCategory.goal, baseTier: 6, results: results,
      enricher: (match, fullText) => _enrichProject(match, fullText));

    // ── Goals ──
    _extractPattern(combined, _goalPatterns, MemoryCategory.goal, baseTier: 7, results: results,
      enricher: (match, fullText) => _enrichGoal(match, fullText));

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
    _extractPattern(combined, _routineTriggerPatterns, MemoryCategory.routine,       baseTier: 5, results: results);
    _extractPattern(combined, _purchasePatterns, MemoryCategory.fact, baseTier: 4, results: results);
    _extractPattern(combined, _projectPatterns, MemoryCategory.goal, baseTier: 6, results: results);
    _extractPattern(combined, _goalPatterns,          MemoryCategory.goal,          baseTier: 7, results: results);
    if (results.isEmpty) return null;
    results.sort((a, b) => b.tier.compareTo(a.tier));
    return results.first;
  }

  // ── Pattern Lists ──

  static final _personalNamePatterns = [
    _Pattern(r'\b(ich heiße|mein name ist|nenn mich|ich bin)\s+([a-zäöüß]+)', bonus: 1),
    _Pattern(r'\b(ich bin|ich arbeite als)\s+([a-zäöüß\s]+)(pädagogin|erzieher|lehrer|ärztin|ingenieur|entwickler)', bonus: 1),
  ];

  static final _familyPatterns = [
    _Pattern(r'\b(meine frau|mein mann|mein partner|meine partnerin)\s+heißt\s+([a-zäöüß]+)', bonus: 2),
    _Pattern(r'\b(mein sohn|meine tochter|mein kind)\s+heißt\s+([a-zäöüß]+)', bonus: 2),
    _Pattern(r'\b(atreju|ellie|saskia|aju)\b', bonus: 2), // already known names from context
    _Pattern(r'\b(vater von|mutter von|eltern von)\s+([a-zäöüß]+)', bonus: 2),
  ];

  static final _jobPatterns = [
    _Pattern(r'\b(arbeite bei|job bei|stelle als)\s+([a-zäöüß\s]+)', bonus: 1),
    _Pattern(r'\b(elementar|kindergarten|schule|pädagog|erzieh)', bonus: 1),
  ];

  static final _preferencePatterns = [
    _Pattern(r'\b(ich mag|ich liebe|ich hasse|ich mag kein|nicht mein)\s+([a-zäöüß\s]+)', bonus: 1),
    _Pattern(r'\b(mein favorit|mein lieblings|am liebsten|bevorzuge)', bonus: 1),
    _Pattern(r'\b(immer|nie|oft|selten)\s+([a-zäöüß\s]+)', bonus: 1),
  ];

  static final _eventPatterns = [
    _Pattern(r'\b(geburtstag|jubiläum|hochzeit|termin|verabredung|arztbesuch|impftermin|stammtisch|treffen)\s+(?:von|am|für|mit)?\s*([^.\n]*)', bonus: 1),
    _Pattern(r'\b(am\s+\d+\.\s*(?:januar|februar|märz|april|mai|juni|juli|august|september|oktober|november|dezember|jan|feb|mär|apr|mai|jun|jul|aug|sep|okt|nov|dez)\.?\s*\d*)', bonus: 1),
    _Pattern(r'\b(nächste woche|nächsten monat|übermorgen|morgen|heute abend|heute nachmittag|dieses wochenende|am wochenende)\s+([^.\n]*)', bonus: 1),
    _Pattern(r'\b(bis\s+(?:morgen|übermorgen|freitag|montag|nächste woche|ende (?:der woche|des monats)))\s+([^.\n]*)', bonus: 2), // deadline
    _Pattern(r'\b(deadline|abgabe|frist|um \d{1,2}[.:]\d{2}\s+uhr|um \d{1,2}\s+uhr)', bonus: 1),
  ];

  // ── Routine triggers (learned) ──
  static final _routineTriggerPatterns = [
    _Pattern(r'\b(immer\s+(?:um|ab|nach))\s+(\d{1,2}[:\.]?\d{0,2})\s+([a-zäöüß\s]+)', bonus: 2),
    _Pattern(r'\b(jeden\s+(?:tag|morgen|abend|montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag))\s+(?:um)?\s*(\d{1,2}[:\.]?\d{0,2})?\s*([a-zäöüß\s]+)', bonus: 2),
    _Pattern(r'\b(meine routine|mein ritual|mein rhythmus)', bonus: 1),
    _Pattern(r'\b(normalerweise|gewöhnlich|üblicherweise|fast immer)\s+([a-zäöüß\s]+)', bonus: 1),
  ];

  // ── Purchase / shopping patterns ──
  static final _purchasePatterns = [
    _Pattern(r'\b(milch|brot|eier|butter|käse|joghurt|wurst|fleisch|gemüse|obst)\s+(?:war|ist|fast|bald|leer|alle)', bonus: 1),
    _Pattern(r'\b(brauche|muss|sollte)\s+(?:noch|nochmal|wieder)\s+([a-zäöüß\s]+)\s+(?:kaufen|holen|bestellen)', bonus: 1),
  ];

  // ── Project / task patterns ──
  static final _projectPatterns = [
    _Pattern(r'\b(terrass|baustell|projekt|renovier|umbau|gart|balkon|dach|fenster|tür)\s+([a-zäöüß\s]+)', bonus: 1),
    _Pattern(r'\b(muss|will|soll)\s+noch\s+([a-zäöüß\s]+)\s+(?:machen|erledigen|fertig|bauen)', bonus: 1),
  ];

  static final _goalPatterns = [
    _Pattern(r'\b(ich will|ich möchte|mein ziel|ich plane|vorhaben)\s+([^.\n]*)', bonus: 2),
    _Pattern(r'\b(bis\s+(?:morgen|nächste woche|nächstes jahr|ende des)\s+[^.\n]*)', bonus: 1),
  ];

  // ── Core extraction logic ──

  void _extractPattern(
    String combined,
    List<_Pattern> patterns,
    MemoryCategory category, {
    required int baseTier,
    required List<ExtractedMemory> results,
    String Function(String match, String fullText)? enricher,
  }) {
    for (final p in patterns) {
      final regex = RegExp(p.regex, caseSensitive: false);
      for (final match in regex.allMatches(combined)) {
        // Immer der VOLLE Treffer: die Trigger-Wörter machen die Erinnerung
        // selbsterklärend ("bis morgen bericht abgeben" statt nur "bericht
        // abgeben"). Die frühere Gruppe-2-Heuristik verlor bei Deadline- und
        // Routine-Mustern den entscheidenden Teil (Frist bzw. Uhrzeit) oder
        // ließ Treffer am Längenfilter scheitern.
        var raw = match.group(0)!;
        raw = raw.trim();
        if (raw.length < 3 || raw.length > 200) continue;

        // Deduplicate against existing results (same-ish content)
        final isDuplicate = results.any((r) => _similarity(r.content, raw) > 0.75);
        if (isDuplicate) continue;

        // Build a context-enriched sentence
        var clean = _cleanSentence(raw);
        if (enricher != null) {
          clean = enricher(raw, combined);
        }
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

  // ── Context Enrichers ──
  // Build full, meaningful sentences from raw pattern matches.

  /// Extract the sentence containing the match from the full text.
  static String _findSurroundingSentence(String match, String fullText) {
    final matchLower = match.toLowerCase();
    final idx = fullText.toLowerCase().indexOf(matchLower);
    if (idx == -1) return match;
    // Find sentence boundaries
    int start = idx;
    while (start > 0 && !'.!?\n'.contains(fullText[start - 1])) {
      start--;
    }
    int end = idx + match.length;
    while (end < fullText.length && !'.!?\n'.contains(fullText[end])) {
      end++;
    }
    return fullText.substring(start, end).trim();
  }

  static String _enrichPersonalName(String match, String fullText) {
    // match is the captured name from the pattern
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Der Nutzer heißt $match');
  }

  static String _enrichFamily(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    // Try to determine relation from context
    if (fullText.contains('sohn') || fullText.contains('son')) {
      return _cleanSentence('Der Nutzer hat einen Sohn namens $match');
    }
    if (fullText.contains('tochter') || fullText.contains('daughter')) {
      return _cleanSentence('Der Nutzer hat eine Tochter namens $match');
    }
    return _cleanSentence('Familienmitglied: $match');
  }

  static String _enrichJob(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Der Nutzer arbeitet im Bereich $match');
  }

  static String _enrichPreference(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Der Nutzer hat eine Vorliebe für $match');
  }

  static String _enrichEvent(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Termin/Ereignis: $match');
  }

  static String _enrichRoutine(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Gewohnheit: $match');
  }

  static String _enrichPurchase(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Einkaufsbedarf: $match');
  }

  static String _enrichProject(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Projekt/Aufgabe: $match');
  }

  static String _enrichGoal(String match, String fullText) {
    final sentence = _findSurroundingSentence(match, fullText);
    if (sentence.length >= 10) return _cleanSentence(sentence);
    return _cleanSentence('Ziel: $match');
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
  final int bonus; // added to baseTier

  const _Pattern(this.regex, {this.bonus = 0});
}
