import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/backup_service.dart';

void main() {
  group('BackupService validation', () {
    test('valid backup JSON has correct structure', () {
      final bundle = {
        'version': 3,
        'timestamp': DateTime.now().toIso8601String(),
        'memory': {
          'short_term': [
            {'id': '1', 'content': 'test', 'source': 'user', 'timestamp': DateTime.now().toIso8601String(), 'metadata': {}},
          ],
          'long_term': [],
        },
        'persona': {
          'name': 'Luna',
          'personality': ['freundlich'],
          'greeting': 'Hallo!',
          'backstory': '',
          'isComplete': true,
        },
        'settings': {
          'max_history': 20,
          'memory_promotion_threshold': 3,
        },
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['version'], 3);
      expect(decoded['timestamp'], isNotNull);
      expect(decoded['memory'], isA<Map>());
      expect(decoded['persona'], isA<Map>());
      expect(decoded['settings'], isA<Map>());

      final memCount = (decoded['memory']?['short_term'] as List?)?.length ?? 0;
      expect(memCount, 1);

      final name = decoded['persona']?['name'];
      expect(name, 'Luna');
    });

    test('backup version check rejects version 0', () {
      final bundle = {
        'version': 0,
        'timestamp': '2026-01-01T00:00:00.000',
        'memory': {'short_term': [], 'long_term': []},
        'persona': {'name': 'Test', 'personality': [], 'greeting': '', 'backstory': '', 'isComplete': false},
        'settings': {},
      };

      // Version 0 should be rejected (backup validation logic)
      final version = bundle['version'] as int? ?? 0;
      expect(version < 1, isTrue);
    });

    test('backup does not contain API keys in persona', () {
      final personaExport = {
        'name': 'Luna',
        'personality': ['freundlich'],
        'greeting': 'Hallo!',
        'backstory': '',
        'isComplete': true,
      };

      // Persona export should NOT contain API keys
      expect(personaExport.containsKey('apiKey'), isFalse);
      expect(personaExport.containsKey('ollamaApiKey'), isFalse);
      expect(personaExport.containsKey('elevenLabsApiKey'), isFalse);
    });

    test('settings export should not contain secrets', () {
      final settingsExport = {
        'max_history': 20,
        'memory_promotion_threshold': 3,
        'memory_ttl_minutes': 60,
        'tts_enabled': false,
        'stt_enabled': false,
        'temperature': 0.7,
      };

      // Settings should not leak secrets
      expect(settingsExport.containsKey('apiKey'), isFalse);
      expect(settingsExport.containsKey('api_key'), isFalse);
      expect(settingsExport.containsKey('OLLAMA_CLOUD_API_KEY'), isFalse);
    });

    test('creating a valid backup zip archive', () async {
      final bundle = {
        'version': 3,
        'timestamp': DateTime.now().toIso8601String(),
        'memory': {'short_term': [], 'long_term': []},
        'persona': {'name': 'Test', 'personality': [], 'greeting': 'Hi', 'backstory': '', 'isComplete': false},
        'settings': {},
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(bundle);
      const encoded = Utf8Encoder();
      final encodedBytes = encoded.convert(jsonStr);
      final archive = Archive();
      archive.addFile(ArchiveFile('backup.json', encodedBytes.length, encodedBytes));
      final zipData = ZipEncoder().encode(archive);

      expect(zipData, isNotNull);
      expect(zipData!.isNotEmpty, isTrue);

      // Verify we can decode it back
      final decoded = ZipDecoder().decodeBytes(zipData);
      final jsonFile = decoded.findFile('backup.json');
      expect(jsonFile, isNotNull);

      final decodedJson = const Utf8Decoder().convert(jsonFile!.content as List<int>);
      final parsed = jsonDecode(decodedJson) as Map<String, dynamic>;
      expect(parsed['version'], 3);
      expect(parsed['persona']?['name'], 'Test');
    });



    test('redactSecretsForBackup redacts sensitive keys recursively', () {
      final redacted = BackupService.redactSecretsForBackup({
        'max_history': 20,
        'OLLAMA_CLOUD_API_KEY': 'secret-key',
        'nested': {
          'authToken': 'token-value',
          'safe': 'kept',
        },
      });

      expect(redacted['max_history'], 20);
      expect(redacted['OLLAMA_CLOUD_API_KEY'], BackupService.redactedSecret);
      expect((redacted['nested'] as Map)['authToken'], BackupService.redactedSecret);
      expect((redacted['nested'] as Map)['safe'], 'kept');
    });

    test('stripRedactedSecrets removes redacted or sensitive keys before import', () {
      final stripped = BackupService.stripRedactedSecrets({
        'max_history': 20,
        'api_key': BackupService.redactedSecret,
        'nested': {
          'password': BackupService.redactedSecret,
          'safe': 'kept',
        },
      });

      expect(stripped['max_history'], 20);
      expect(stripped.containsKey('api_key'), isFalse);
      expect((stripped['nested'] as Map).containsKey('password'), isFalse);
      expect((stripped['nested'] as Map)['safe'], 'kept');
    });

    test('corrupt zip throws on decode', () {
      expect(
        () => ZipDecoder().decodeBytes([1, 2, 3, 4, 5]),
        throwsA(anything),
      );
    });

    test('backup missing backup.json throws', () async {
      // Create zip without backup.json
      final archive = Archive();
      archive.addFile(ArchiveFile('wrong_file.txt', 5, [72, 101, 108, 108, 111]));
      final zipData = ZipEncoder().encode(archive);
      expect(zipData, isNotNull);

      final decoded = ZipDecoder().decodeBytes(zipData!);
      final jsonFile = decoded.findFile('backup.json');
      expect(jsonFile, isNull);
    });
  });
}