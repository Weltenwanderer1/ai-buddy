import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/memory_service.dart';

void main() {
  group('MemoryItem', () {
    test('toJson and fromJson roundtrip', () {
      final now = DateTime.now();
      final item = MemoryItem(
        id: 'test-id-1',
        content: 'Hello world',
        source: 'user',
        timestamp: now,
        metadata: {'repeatCount': 2, 'promotedAt': now.toIso8601String()},
      );

      final json = item.toJson();
      final restored = MemoryItem.fromJson(json);

      expect(restored.id, 'test-id-1');
      expect(restored.content, 'Hello world');
      expect(restored.source, 'user');
      expect(restored.metadata['repeatCount'], 2);
      expect(restored.metadata['promotedAt'], now.toIso8601String());
    });

    test('fromJson handles null fields with defaults', () {
      final json = <String, dynamic>{};
      final item = MemoryItem.fromJson(json);

      expect(item.id, isNotEmpty); // UUID generated
      expect(item.content, '');
      expect(item.source, 'system');
      expect(item.metadata, isEmpty);
    });

    test('fromJson handles non-string map keys in metadata', () {
      final json = {
        'id': 'meta-test',
        'content': 'test',
        'source': 'user',
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {1: 'value1', 'key2': 'value2'},
      };
      final item = MemoryItem.fromJson(json);
      expect(item.metadata['1'], 'value1');
      expect(item.metadata['key2'], 'value2');
    });

    test('fromJson handles invalid timestamp gracefully', () {
      final json = {
        'id': 'ts-test',
        'content': 'test',
        'source': 'user',
        'timestamp': 'not-a-valid-timestamp',
        'metadata': {},
      };
      final item = MemoryItem.fromJson(json);
      expect(item.timestamp, isNotNull);
    });
  });

  group('MemoryService similarity', () {
    late MemoryService service;

    setUp(() {
      service = MemoryService(
        promotionThreshold: 3,
        ttl: const Duration(hours: 1),
      );
      // No init() — in-memory mode, no file I/O
    });

    test('identical strings have high similarity', () {
      final sim = service.similarity('Hello world', 'Hello world');
      expect(sim, greaterThan(0.9));
    });

    test('completely different strings have low similarity', () {
      final sim = service.similarity('abc xyz', 'def uvw');
      expect(sim, lessThan(0.3));
    });

    test('partial overlap yields intermediate similarity', () {
      final sim = service.similarity('Ich mag Pizza und Pasta', 'Ich mag Pizza und Kaffee');
      expect(sim, greaterThan(0.4));
      expect(sim, lessThan(1.0));
    });

    test('empty strings return 0', () {
      expect(service.similarity('', 'test'), 0.0);
      expect(service.similarity('test', ''), 0.0);
      expect(service.similarity('', ''), 0.0);
    });

    test('case insensitive', () {
      final sim = service.similarity('HELLO WORLD', 'hello world');
      expect(sim, greaterThan(0.9));
    });
  });

  group('MemoryService getRelevantMemories', () {
    late MemoryService service;

    setUp(() {
      service = MemoryService(promotionThreshold: 3, ttl: const Duration(hours: 1));
      // Use @visibleForTesting accessors
      service.shortTermList.add(MemoryItem(
        id: 's1',
        content: 'Ich mag Pizza und Pasta',
        source: 'user',
        timestamp: DateTime.now(),
      ));
      service.shortTermList.add(MemoryItem(
        id: 's2',
        content: 'Das Wetter ist schön heute',
        source: 'user',
        timestamp: DateTime.now(),
      ));
      service.longTermList.add(MemoryItem(
        id: 'l1',
        content: 'Pizza ist mein Lieblingsessen',
        source: 'user',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
      ));
    });

    test('finds relevant pizza memories', () async {
      final relevant = await service.getRelevantMemories('Pizza bestellen');
      expect(relevant, isNotEmpty);
      expect(relevant.any((m) => m.content.contains('Pizza')), isTrue);
    });

    test('empty query returns nothing', () async {
      expect(await service.getRelevantMemories(''), isEmpty);
      expect(await service.getRelevantMemories('   '), isEmpty);
    });

    test('limits results', () async {
      final service2 = MemoryService();
      for (int i = 0; i < 10; i++) {
        service2.shortTermList.add(MemoryItem(
          id: 's$i',
          content: 'Test memory item number $i with some keywords',
          source: 'user',
          timestamp: DateTime.now(),
        ));
      }
      final results = await service2.getRelevantMemories('Test memory', limit: 3);
      expect(results.length, lessThanOrEqualTo(3));
    });
  });

  group('MemoryService addShortTerm and promotion', () {
    test('adding similar content increments repeatCount and promotes', () async {
      final dir = Directory('${Directory.systemTemp.path}/ai_buddy_test_${DateTime.now().millisecondsSinceEpoch}');
      await dir.create(recursive: true);
      final service = MemoryService(
        promotionThreshold: 2,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir,
      );
      await service.init();

      await service.addShortTerm('Ich mag Kaffee', source: 'user');
      expect(service.shortTermMemories.length, 1);

      await service.addShortTerm('Ich mag Kaffee', source: 'user');
      // With threshold 2, second identical message should promote to long-term
      expect(service.longTermMemories.length, 1);
      expect(service.longTermMemories.first.content, 'Ich mag Kaffee');

      try { await dir.delete(recursive: true); } catch (_) {}
    });

    test('adding different content does not promote', () async {
      final dir = Directory('${Directory.systemTemp.path}/ai_buddy_test_${DateTime.now().millisecondsSinceEpoch}');
      await dir.create(recursive: true);
      final service = MemoryService(
        promotionThreshold: 2,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir,
      );
      await service.init();

      await service.addShortTerm('Ich mag Kaffee', source: 'user');
      await service.addShortTerm('Das Wetter ist heute sonnig', source: 'user');
      // Two different items, no promotion
      expect(service.shortTermMemories.length, 2);
      expect(service.longTermMemories.length, 0);

      try { await dir.delete(recursive: true); } catch (_) {}
    });
  });

  group('MemoryService export/import roundtrip', () {
    test('exportAll and importAll preserve data', () async {
      final dir = Directory('${Directory.systemTemp.path}/ai_buddy_test_${DateTime.now().millisecondsSinceEpoch}');
      await dir.create(recursive: true);
      final service = MemoryService(
        promotionThreshold: 3,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir,
      );
      await service.init();

      await service.addShortTerm('Test short', source: 'user');
      await service.addLongTerm('Test long', source: 'system');

      final exported = service.exportAll();

      // Import into a fresh service
      final dir2 = Directory('${Directory.systemTemp.path}/ai_buddy_test2_${DateTime.now().millisecondsSinceEpoch}');
      await dir2.create(recursive: true);
      final service2 = MemoryService(
        promotionThreshold: 3,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir2,
      );
      await service2.init();
      await service2.importAll(exported);

      expect(service2.shortTermMemories.length, 1);
      expect(service2.shortTermMemories.first.content, 'Test short');
      expect(service2.longTermMemories.length, 1);
      expect(service2.longTermMemories.first.content, 'Test long');

      try { await dir.delete(recursive: true); } catch (_) {}
      try { await dir2.delete(recursive: true); } catch (_) {}
    });
  });

  group('MemoryService clearAll', () {
    test('clears both short and long term', () async {
      final dir = Directory('${Directory.systemTemp.path}/ai_buddy_test_${DateTime.now().millisecondsSinceEpoch}');
      await dir.create(recursive: true);
      final service = MemoryService(
        promotionThreshold: 3,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir,
      );
      await service.init();

      await service.addShortTerm('Short', source: 'user');
      await service.addLongTerm('Long', source: 'system');

      await service.clearAll();
      expect(service.shortTermMemories.length, 0);
      expect(service.longTermMemories.length, 0);

      try { await dir.delete(recursive: true); } catch (_) {}
    });
  });

  group('MemoryService persistence', () {
    test('data persists across service instances', () async {
      final dir = Directory('${Directory.systemTemp.path}/ai_buddy_persist_${DateTime.now().millisecondsSinceEpoch}');
      await dir.create(recursive: true);

      // Create and populate
      final service1 = MemoryService(
        promotionThreshold: 3,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir,
      );
      await service1.init();
      await service1.addShortTerm('Persistent memory', source: 'user');
      await service1.addLongTerm('Long-lived memory', source: 'system');

      // Create new instance and load
      final service2 = MemoryService(
        promotionThreshold: 3,
        ttl: const Duration(hours: 1),
        dataDirOverride: dir,
      );
      await service2.init();

      expect(service2.shortTermMemories.any((m) => m.content == 'Persistent memory'), isTrue);
      expect(service2.longTermMemories.any((m) => m.content == 'Long-lived memory'), isTrue);

      try { await dir.delete(recursive: true); } catch (_) {}
    });
  });
}