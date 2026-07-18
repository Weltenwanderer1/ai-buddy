import 'dart:io';

import 'package:ai_buddy/services/obsidian_vault_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('listNotes at vault root includes real notes from nested folders', () async {
    final vault = await Directory.systemTemp.createTemp('ai_buddy_vault_');
    addTearDown(() => vault.delete(recursive: true));

    await File('${vault.path}/Index.md').writeAsString('# Index');
    await Directory('${vault.path}/10-Notes').create();
    await File('${vault.path}/10-Notes/Echte Notiz.md')
        .writeAsString('# Echte Notiz');

    final service = ObsidianVaultService()..updatePath(vault.path);
    addTearDown(service.dispose);

    final notes = await service.listNotes();

    expect(notes.map((note) => note['path']), containsAll([
      'Index.md',
      '10-Notes/Echte Notiz.md',
    ]));
  });
}
