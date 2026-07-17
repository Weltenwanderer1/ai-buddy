import 'dart:io';
import 'package:flutter/material.dart';

/// Service for reading, searching, and writing Obsidian vault .md files.
/// The vault path is configured via SettingsService['obsidian_vault_path'].
class ObsidianVaultService extends ChangeNotifier {
  String _vaultPath = '';

  String get vaultPath => _vaultPath;
  bool get isConfigured =>
      _vaultPath.isNotEmpty && Directory(_vaultPath).existsSync();

  void updatePath(String path) {
    _vaultPath = path.trim();
    notifyListeners();
  }

  /// Search .md files for a query using token overlap scoring.
  Future<List<Map<String, dynamic>>> search(String query,
      {int limit = 10}) async {
    if (!isConfigured || query.trim().isEmpty) return [];

    final queryTokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toSet();
    if (queryTokens.isEmpty) return [];

    final results = <Map<String, dynamic>>[];
    final dir = Directory(_vaultPath);

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;
      if (entity.path.contains('/.obsidian/')) continue;

      try {
        final content = await entity.readAsString();
        final contentTokens = content
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toSet();

        if (contentTokens.isEmpty) continue;

        final intersection = queryTokens.intersection(contentTokens).length;
        final score = intersection /
            (queryTokens.length + contentTokens.length - intersection);

        if (score > 0.01) {
          final title = _extractTitle(content, entity.path);
          final excerpt = _extractExcerpt(content);
          final relativePath = entity.path.replaceFirst('$_vaultPath/', '');

          results.add({
            'path': relativePath,
            'title': title,
            'excerpt': excerpt,
            'score': score,
          });
        }
      } catch (_) {
        // Skip unreadable files
      }
    }

    results.sort(
        (a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return results.take(limit).toList();
  }

  /// Read a .md file from the vault.
  Future<String?> readNote(String relativePath) async {
    if (!isConfigured) return null;
    final file = File('$_vaultPath/$relativePath');
    if (!await file.exists()) return null;
    try {
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// Write content to a .md file in the vault.
  Future<bool> writeNote(String relativePath, String content) async {
    if (!isConfigured) return false;
    try {
      final file = File('$_vaultPath/$relativePath');
      await file.parent.create(recursive: true);
      await file.writeAsString(content);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// List .md files in a folder (relative to vault root).
  Future<List<Map<String, String>>> listNotes({String folder = ''}) async {
    if (!isConfigured) return [];
    final dirPath = folder.isEmpty ? _vaultPath : '$_vaultPath/$folder';
    final dir = Directory(dirPath);
    if (!await dir.exists()) return [];

    final results = <Map<String, String>>[];
    await for (final entity in dir.list(recursive: false, followLinks: false)) {
      if (entity is! File) continue;
      if (!entity.path.endsWith('.md')) continue;

      final relativePath = entity.path.replaceFirst('$_vaultPath/', '');
      String title;
      try {
        final content = await entity.readAsString();
        title = _extractTitle(content, entity.path);
      } catch (_) {
        title = relativePath.split('/').last.replaceAll('.md', '');
      }

      results.add({'path': relativePath, 'title': title});
    }

    results.sort(
        (a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
    return results;
  }

  String _extractTitle(String content, String filePath) {
    // Try H1 heading first
    final h1Match =
        RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(content);
    if (h1Match != null) return h1Match.group(1)!.trim();

    // Try frontmatter title: title: "My Title" or title: My Title
    final lines = content.split('\n');
    if (lines.isNotEmpty && lines.first.trim() == '---') {
      for (var i = 1; i < lines.length; i++) {
        if (lines[i].trim() == '---') break;
        if (lines[i].startsWith('title:')) {
          var val = lines[i].substring(6).trim();
          // Strip surrounding quotes
          if ((val.startsWith('"') && val.endsWith('"')) ||
              (val.startsWith("'") && val.endsWith("'"))) {
            val = val.substring(1, val.length - 1);
          }
          if (val.isNotEmpty) return val;
        }
      }
    }

    // Fallback: filename without extension
    return filePath.split('/').last.replaceAll('.md', '');
  }

  String _extractExcerpt(String content) {
    var text = content;

    // Strip frontmatter
    if (text.startsWith('---')) {
      final end = text.indexOf('---', 3);
      if (end != -1) {
        text = text.substring(end + 3).trim();
      }
    }

    // Strip markdown headers
    text = text.replaceAll(RegExp(r'^#+\s+.*$', multiLine: true), '').trim();
    // Unwrap wikilinks
    text = text.replaceAll(RegExp(r'\[\[(.+?)\]\]'), r'$1');

    if (text.length > 200) {
      text = '${text.substring(0, 200)}...';
    }
    return text;
  }
}
