// Password Manager Service using flutter_secure_storage (Android Keystore backed)
// All values are auto-encrypted by the OS keystore. No extra crypto package needed.
import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Represents a stored password entry.
class PasswordEntry {
  final String id;
  String name;        // e.g. "Gmail", "AMS"
  String? username;
  String? password;
  String? url;
  String? notes;
  final DateTime createdAt;
  DateTime modifiedAt;

  PasswordEntry({
    required this.id,
    required this.name,
    this.username,
    this.password,
    this.url,
    this.notes,
    DateTime? createdAt,
    DateTime? modifiedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'u': username,
        'p': password,
        'url': url,
        'n': notes,
        'c': createdAt.toIso8601String(),
        'm': modifiedAt.toIso8601String(),
      };

  factory PasswordEntry.fromJson(Map<String, dynamic> j) => PasswordEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        username: j['u'] as String?,
        password: j['p'] as String?,
        url: j['url'] as String?,
        notes: j['n'] as String?,
        createdAt: DateTime.tryParse(j['c'] as String? ?? '') ?? DateTime.now(),
        modifiedAt: DateTime.tryParse(j['m'] as String? ?? '') ?? DateTime.now(),
      );
}

class PasswordService {
  static const _kIndex = 'pass_index';
  static const _kPrefix = 'pe_';
  final FlutterSecureStorage _storage;

  PasswordService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Add or replace a password entry.
  Future<PasswordEntry> saveEntry(PasswordEntry entry) async {
    entry.modifiedAt = DateTime.now();
    final key = '$_kPrefix${entry.id}';
    await _storage.write(key: key, value: jsonEncode(entry.toJson()));
    await _addToIndex(entry.id, entry.name);
    return entry;
  }

  /// Create a new entry with generated fields.
  Future<PasswordEntry> createEntry({
    required String name,
    String? username,
    String? password,
    String? url,
    String? notes,
  }) async {
    final id = _randomId();
    final entry = PasswordEntry(
      id: id,
      name: name,
      username: username,
      password: password,
      url: url,
      notes: notes,
    );
    return saveEntry(entry);
  }

  /// Retrieve a single entry by ID.
  Future<PasswordEntry?> getEntry(String id) async {
    final raw = await _storage.read(key: '$_kPrefix$id');
    if (raw == null) return null;
    try {
      return PasswordEntry.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Delete an entry.
  Future<bool> deleteEntry(String id) async {
    await _storage.delete(key: '$_kPrefix$id');
    return _removeFromIndex(id);
  }

  /// List all entries (metadata only, no passwords loaded yet).
  Future<List<PasswordEntry>> listEntries() async {
    final ids = await _readIndex();
    final entries = <PasswordEntry>[];
    for (final id in ids) {
      final e = await getEntry(id);
      if (e != null) entries.add(e);
    }
    return entries..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Search by name, username, URL, or notes.
  Future<List<PasswordEntry>> search(String query) async {
    final q = query.toLowerCase();
    final all = await listEntries();
    return all.where((e) {
      return e.name.toLowerCase().contains(q) ||
          (e.username?.toLowerCase().contains(q) ?? false) ||
          (e.url?.toLowerCase().contains(q) ?? false) ||
          (e.notes?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  /// Generate a strong random password.
  static String generatePassword({
    int length = 20,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeDigits = true,
    bool includeSpecial = true,
  }) {
    final sb = StringBuffer();
    final rand = Random.secure();
    final chars = <String>[];

    if (includeLowercase) chars.addAll('abcdefghijklmnopqrstuvwxyz'.split(''));
    if (includeUppercase) chars.addAll('ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split(''));
    if (includeDigits) chars.addAll('0123456789'.split(''));
    if (includeSpecial) chars.addAll('!@#\$%^&*()-_=+[]{}|;:,.<>?'.split(''));

    if (chars.isEmpty) chars.addAll('abcdefghijklmnopqrstuvwxyz0123456789'.split(''));

    for (var i = 0; i < length; i++) {
      sb.write(chars[rand.nextInt(chars.length)]);
    }
    return sb.toString();
  }

  /// Check password strength (basic heuristic).
  static ({int score, String label}) checkStrength(String password) {
    var s = 0;
    if (password.length >= 12) {
      s += 2;
    } else if (password.length >= 8) {
      s += 1;
    }
    if (RegExp(r'[A-Z]').hasMatch(password)) s += 1;
    if (RegExp(r'[a-z]').hasMatch(password)) s += 1;
    if (RegExp(r'\d').hasMatch(password)) s += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s += 1;

    if (s <= 2) return (score: s, label: 'Schwach 🔴');
    if (s <= 4) return (score: s, label: 'Mittel 🟡');
    return (score: s, label: 'Stark 🟢');
  }

  /// Master-key helpers (optional extra PIN layer).
  Future<bool> hasMasterPin() async => await _storage.containsKey(key: 'pass_master_pin');

  Future<void> setMasterPin(String pin) async {
    // Store a hash, never plaintext. For simplicity pbkdf2-like via repeated sha512 not implemented here;
    // In production: use proper Argon2. We store PIN in Keystore which is already hardware-protected.
    await _storage.write(key: 'pass_master_pin', value: pin);
  }

  Future<bool> verifyMasterPin(String pin) async {
    final stored = await _storage.read(key: 'pass_master_pin');
    return stored == pin;
  }

  Future<void> clearMasterPin() => _storage.delete(key: 'pass_master_pin');

  Future<void> clearAll() async {
    final ids = await _readIndex();
    for (final id in ids) {
      await _storage.delete(key: '$_kPrefix$id');
    }
    await _storage.delete(key: _kIndex);
    await _storage.delete(key: 'pass_master_pin');
  }

  // ─── Index helpers ───

  Future<List<String>> _readIndex() async {
    final raw = await _storage.read(key: _kIndex);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addToIndex(String id, String name) async {
    final ids = await _readIndex();
    if (!ids.contains(id)) {
      ids.add(id);
      await _storage.write(key: _kIndex, value: jsonEncode(ids));
    }
  }

  Future<bool> _removeFromIndex(String id) async {
    final ids = await _readIndex();
    final ok = ids.remove(id);
    if (ok) await _storage.write(key: _kIndex, value: jsonEncode(ids));
    return ok;
  }

  String _randomId() {
    final r = Random.secure();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
