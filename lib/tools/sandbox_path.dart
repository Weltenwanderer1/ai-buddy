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
