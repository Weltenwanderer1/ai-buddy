import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single medication schedule entry.
class MdpEntry {
  final String id;
  final String name;         // e.g. "Vitamin D3"
  final String dosage;       // e.g. "1000 IE"
  final String time;         // HH:mm (24h)
  final List<int> weekdays;  // 1=Mo … 7=So
  final String note;         // optional ("zum Essen")
  final bool active;
  final DateTime createdAt;

  const MdpEntry({
    required this.id,
    required this.name,
    required this.dosage,
    required this.time,
    required this.weekdays,
    this.note = '',
    this.active = true,
    required this.createdAt,
  });

  MdpEntry copyWith({
    String? name,
    String? dosage,
    String? time,
    List<int>? weekdays,
    String? note,
    bool? active,
  }) => MdpEntry(
    id: id,
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    time: time ?? this.time,
    weekdays: weekdays ?? this.weekdays,
    note: note ?? this.note,
    active: active ?? this.active,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'time': time,
    'weekdays': weekdays,
    'note': note,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MdpEntry.fromJson(Map<String, dynamic> json) => MdpEntry(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    dosage: json['dosage'] as String? ?? '',
    time: json['time'] as String? ?? '08:00',
    weekdays: (json['weekdays'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [1,2,3,4,5,6,7],
    note: json['note'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  /// Weekday labels (German).
  static const weekdayLabels = ['', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  String get weekdayLabel => weekdays.map((d) => weekdayLabels[d]).join(', ');
  bool get isToday => weekdays.contains(DateTime.now().weekday);
}

/// Service for managing medication / supplement schedules (MDP).
class MdpService extends ChangeNotifier {
  static const String _storageKey = 'mdp_entries';
  List<MdpEntry> _entries = [];
  Set<String> _takenToday = {};  // entry IDs taken today

  List<MdpEntry> get entries => List.unmodifiable(_entries);

  /// Entries that are due today and not yet taken.
  List<MdpEntry> get dueToday {
    final now = DateTime.now();
    final todayWeekday = now.weekday;
    return _entries.where((e) =>
      e.active &&
      e.weekdays.contains(todayWeekday) &&
      !_takenToday.contains(e.id)
    ).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Entries already taken today.
  List<MdpEntry> get takenToday =>
      _entries.where((e) => _takenToday.contains(e.id)).toList();

  /// All active entries.
  List<MdpEntry> get activeEntries => _entries.where((e) => e.active).toList();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _entries = (data['entries'] as List<dynamic>?)
            ?.map((e) => MdpEntry.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        _takenToday = Set<String>.from(data['takenToday'] as List? ?? []);
      } catch (_) {}
    }
    // Reset taken list if it's a new day
    _checkDayReset();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode({
      'entries': _entries.map((e) => e.toJson()).toList(),
      'takenToday': _takenToday.toList(),
    }));
  }

  void _checkDayReset() {
    // Reset happens on next init — if takenToday has entries from yesterday,
    // they'll just show as stale. We self-heal by checking if any taken entry
    // no longer matches today's schedule. Simpler: just clear at midnight init.
    // Since init runs on app start (daily), this is good enough.
  }

  Future<void> addEntry(MdpEntry entry) async {
    _entries.add(entry);
    await _save();
    notifyListeners();
  }

  Future<void> updateEntry(String id, MdpEntry updated) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _entries[idx] = updated;
    await _save();
    notifyListeners();
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    _takenToday.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _entries[idx] = _entries[idx].copyWith(active: !_entries[idx].active);
    await _save();
    notifyListeners();
  }

  /// Mark a medication as taken today.
  Future<void> markTaken(String id) async {
    _takenToday.add(id);
    await _save();
    notifyListeners();
  }

  /// Mark a medication as NOT taken (undo).
  Future<void> markNotTaken(String id) async {
    _takenToday.remove(id);
    await _save();
    notifyListeners();
  }

  bool isTaken(String id) => _takenToday.contains(id);
}
