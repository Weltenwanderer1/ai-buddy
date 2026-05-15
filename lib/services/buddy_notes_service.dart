import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistente Notizen für Buddy — Tools, Skills, Passwörter, etc.
/// KI kann lesen und schreiben. User kann in Settings einsehen und editieren.
class BuddyNotesService extends ChangeNotifier {
  String _notes = '';
  File? _file;

  String get notes => _notes;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _file = File('${dir.path}/ai_buddy/buddy_notes.txt');
    await _load();
    notifyListeners();
  }

  Future<void> _load() async {
    final file = _file;
    if (file == null || !await file.exists()) {
      _notes = _defaultNotes();
      await _save();
      return;
    }
    try {
      _notes = await file.readAsString();
    } catch (e) {
      debugPrint('BuddyNotesService: read error: $e');
      _notes = _defaultNotes();
    }
  }

  Future<void> _save() async {
    final file = _file;
    if (file == null) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(_notes);
  }

  Future<void> updateNotes(String value) async {
    _notes = value;
    await _save();
    notifyListeners();
  }

  /// Called by the tool — appends a line to the notes.
  Future<void> append(String line) async {
    if (line.trim().isEmpty) return;
    final ts = DateTime.now().toIso8601String().split('T').first;
    _notes = '${_notes.trimRight()}\n\n[$ts] $line'.trimLeft();
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    _notes = '';
    await _save();
    notifyListeners();
  }

  String _defaultNotes() => """=== BUDDY NOTIZEN ===
Hier speichert die KI wichtige Dinge:
- Werkzeuge die funktionieren / nicht funktionieren
- Neue Fähigkeiten (Skills) die der User erwähnt
- Passwörter oder Zugangsdaten (verschlüsselt gespeichert)
- Wichtige Erkenntnisse aus Gesprächen
- To-Dos oder Erinnerungen für den User

Diese Datei wird automatisch aktualisiert.""";
}
