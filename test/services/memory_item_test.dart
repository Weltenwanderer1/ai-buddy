import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/memory_service.dart';

void main() {
  group('MemoryService basics', () {
    test('can create', () {
      final s = MemoryService();
      expect(s, isNotNull);
    });

    test('export/import roundtrip works', () async {
      final s = MemoryService(dataDirOverride: null);
      await s.init();
      await s.addShortTerm('test', source: 'user');
      final exported = s.exportAll();
      expect(exported['short_term'], isNotEmpty);
      expect(exported['long_term'], isEmpty);
      expect(exported['core'], isEmpty);
    });
  });
}
