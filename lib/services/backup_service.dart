import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'memory_service.dart';
import 'persona_service.dart';
import 'persona_evolution_service.dart';
import 'chat_history_service.dart';
import 'settings_service.dart';
import 'self_identity_service.dart';

/// Backup/Restore service — exports all app data as a JSON zip bundle.
class BackupService {
  final MemoryService memory;
  final PersonaService persona;
  final SettingsService settings;
  final ChatHistoryService? chatHistory;
  final PersonaEvolutionService? personaEvolution;
  final SelfIdentityService? selfIdentity;

  static const int backupVersion = 4;

  BackupService({
    required this.memory,
    required this.persona,
    required this.settings,
    this.chatHistory,
    this.personaEvolution,
    this.selfIdentity,
  });


  static const redactedSecret = '***REDACTED***';

  @visibleForTesting
  static Map<String, dynamic> redactSecretsForBackup(Map<String, dynamic> data) {
    return _sanitizeMap(data, redact: true);
  }

  @visibleForTesting
  static Map<String, dynamic> stripRedactedSecrets(Map<String, dynamic> data) {
    return _sanitizeMap(data, redact: false);
  }

  static Map<String, dynamic> _sanitizeMap(
    Map<String, dynamic> data, {
    required bool redact,
  }) {
    final sanitized = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;
      if (_isSensitiveKey(key)) {
        if (redact) {
          sanitized[key] = redactedSecret;
        }
        continue;
      }
      if (!redact && value == redactedSecret) {
        continue;
      }
      if (value is Map) {
        sanitized[key] = _sanitizeMap(
          value.map((k, v) => MapEntry(k.toString(), v)),
          redact: redact,
        );
      } else if (value is List) {
        sanitized[key] = value
            .map((item) => item is Map
                ? _sanitizeMap(item.map((k, v) => MapEntry(k.toString(), v)), redact: redact)
                : item)
            .toList();
      } else {
        sanitized[key] = value;
      }
    }
    return sanitized;
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized.contains('apikey') ||
        normalized.contains('secret') ||
        normalized.contains('token') ||
        normalized.contains('password');
  }

  /// Export all data to a zip file, returns the file path.
  Future<String> exportBackup() async {
    final bundle = <String, dynamic>{
      'version': backupVersion,
      'timestamp': DateTime.now().toIso8601String(),
      'memory': memory.exportAll(),
      'persona': persona.exportData(),
      'settings': redactSecretsForBackup(settings.exportData()),
    };

    if (chatHistory != null) {
      bundle['chat_history'] = chatHistory!.exportData();
    }
    if (personaEvolution != null) {
      bundle['persona_evolution'] = personaEvolution!.exportData();
    }

    if (selfIdentity != null) {
      bundle['self_identity'] = {
        'name': selfIdentity!.name,
        'essence': selfIdentity!.essence,
        'behaviorRules': selfIdentity!.behaviorRules,
        'userName': selfIdentity!.userName,
        'relationshipDescription': selfIdentity!.relationshipDescription,
        'keyExperiences': selfIdentity!.keyExperiences,
        'emotionalTone': selfIdentity!.emotionalTone,
        'purpose': selfIdentity!.purpose,
        'ongoingGoals': selfIdentity!.ongoingGoals,
        'lastModified': selfIdentity!.lastModified.toIso8601String(),
        'lastAutoUpdate': selfIdentity!.lastAutoUpdate.toIso8601String(),
      };
    }

    final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
    const encoded = Utf8Encoder();
    final encodedBytes = encoded.convert(jsonStr);
    final archive = Archive();
    archive.addFile(ArchiveFile('backup.json', encodedBytes.length, encodedBytes));

    final zipData = ZipEncoder().encode(archive);
    if (zipData.isEmpty) throw Exception('Failed to create zip archive (empty result)');

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').substring(0, 19);
    final file = File('${dir.path}/ai_buddy_backup_$ts.zip');
    await file.writeAsBytes(zipData);
    return file.path;
  }

  /// Pick a backup zip file without importing it.
  Future<String?> pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }

  /// Import from a file picker selection.
  Future<String?> importBackupWithPicker() async {
    final path = await pickBackupFile();
    if (path == null) return null;

    await importBackup(path);
    return path;
  }

  /// Validate a backup file without importing.
  /// Returns a human-readable summary or throws on error.
  Future<String> validateBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final jsonFile = archive.findFile('backup.json');
    if (jsonFile == null) throw Exception('Ungültiges Backup: backup.json nicht gefunden');

    final jsonStr = const Utf8Decoder().convert(jsonFile.content as List<int>);
    final bundle = jsonDecode(jsonStr) as Map<String, dynamic>;

    final version = bundle['version'] as int? ?? 0;
    if (version < 1) throw Exception('Ungültige Backup-Version: $version');

    final ts = bundle['timestamp'] as String? ?? 'unbekannt';
    final memCount = (bundle['memory']?['short_term'] as List?)?.length ?? 0;
    final ltCount = (bundle['memory']?['long_term'] as List?)?.length ?? 0;
    final name = bundle['persona']?['name'] as String? ?? 'unbekannt';
    final msgCount = (bundle['chat_history']?['messages'] as List?)?.length ?? 0;
    final hasEvolution = bundle['persona_evolution'] != null;

    final parts = [
      'Backup v$version vom $ts',
      'Kurzzeit: $memCount Einträge',
      'Langzeit: $ltCount Einträge',
      'Persona: $name',
    ];
    if (msgCount > 0) parts.add('Chat: $msgCount Nachrichten');
    if (hasEvolution) parts.add('Persona-Evolution: ja');

    return parts.join('\n');
  }

  /// Import from a zip file path.
  Future<void> importBackup(String zipPath) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final jsonFile = archive.findFile('backup.json');
    if (jsonFile == null) throw Exception('Ungültiges Backup: backup.json nicht gefunden');

    final jsonStr = const Utf8Decoder().convert(jsonFile.content as List<int>);
    Map<String, dynamic> bundle;
    try {
      bundle = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Backup-Datei ist beschädigt: JSON konnte nicht gelesen werden');
    }

    final version = bundle['version'] as int? ?? 0;
    if (version < 1) throw Exception('Nicht unterstützte Backup-Version: $version');

    if (bundle['memory'] != null) {
      final mem = bundle['memory'];
      if (mem is Map<String, dynamic>) {
        await memory.importAll(mem);
      }
    }
    if (bundle['persona'] != null) {
      final per = bundle['persona'];
      if (per is Map<String, dynamic>) {
        await persona.importData(per);
      }
    }
    if (bundle['settings'] != null) {
      final set = bundle['settings'];
      if (set is Map<String, dynamic>) {
        final safeSettings = stripRedactedSecrets(set);
        await settings.importData(safeSettings);
      }
    }
    if (bundle['chat_history'] != null && chatHistory != null) {
      final ch = bundle['chat_history'];
      if (ch is Map<String, dynamic>) {
        await chatHistory!.importData(ch);
      }
    }
    if (bundle['persona_evolution'] != null && personaEvolution != null) {
      final evo = bundle['persona_evolution'];
      if (evo is Map<String, dynamic>) {
        await personaEvolution!.importData(evo);
      }
    }
    if (bundle['self_identity'] != null && selfIdentity != null) {
      final si = bundle['self_identity'];
      if (si is Map<String, dynamic>) {
        await selfIdentity!.importData(si);
      }
    }
  }
}
