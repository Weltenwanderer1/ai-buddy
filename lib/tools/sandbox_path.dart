/// Resolves [subPath] relative to [root] and normalizes `.`/`..` segments.
///
/// Returns `null` when the path would escape [root] (path traversal),
/// so callers can return a tool error instead of touching files outside
/// the sandbox.
String? resolveSandboxPath(String root, String subPath) {
  final cleaned = subPath.replaceFirst(RegExp(r'^/+'), '');
  final segments = <String>[];
  for (final part in cleaned.split('/')) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (segments.isEmpty) return null; // would escape the root
      segments.removeLast();
    } else {
      segments.add(part);
    }
  }
  return segments.isEmpty ? root : '$root/${segments.join('/')}';
}

/// Resolves [subPath] for the file tools, allowing the assistant to reach the
/// wider device filesystem — not just its private sandbox.
///
/// - An **absolute** path (starts with `/`) is normalized (`.`/`..` collapsed)
///   and returned as-is, so the buddy can read/write anywhere the user has
///   granted All-Files access (e.g. `/storage/emulated/0/Download/notes.txt`).
/// - A **relative** path stays sandboxed under [root] via [resolveSandboxPath],
///   preserving traversal protection for the common case.
///
/// Returns `null` only when a relative path tries to escape [root].
String? resolveFsPath(String root, String subPath) {
  final trimmed = subPath.trim();
  if (trimmed.startsWith('/')) {
    final segments = <String>[];
    for (final part in trimmed.split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (segments.isNotEmpty) segments.removeLast();
      } else {
        segments.add(part);
      }
    }
    return '/${segments.join('/')}';
  }
  return resolveSandboxPath(root, trimmed);
}
