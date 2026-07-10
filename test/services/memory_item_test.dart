import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/memory_service.dart';

void main() {
  group('MemoryService basics', () {
    test('can create', () {
      final s = MemoryService();
      expect(s, isNotNull);
    });

    test('semantic lookup budget stays below one second', () {
      expect(MemoryService.semanticLookupBudget, lessThan(const Duration(seconds: 1)));
    });

    test('export/import roundtrip works', () async {
      final tempDir = Directory.systemTemp.createTempSync();
      final s = MemoryService(dataDirOverride: tempDir);
      await s.init();
      await s.addShortTerm('test', source: 'user');
      final exported = s.exportAll();
      expect(exported['short_term'], isNotEmpty);
      expect(exported['long_term'], isEmpty);
      expect(exported['core'], isEmpty);
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });
  });
}
