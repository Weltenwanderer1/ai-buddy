import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/tools/sandbox_path.dart';

void main() {
  group('resolveSandboxPath', () {
    const root = '/data/app';

    test('resolves simple relative path', () {
      expect(resolveSandboxPath(root, 'notes/todo.txt'), '$root/notes/todo.txt');
    });

    test('strips leading slashes', () {
      expect(resolveSandboxPath(root, '//notes/todo.txt'), '$root/notes/todo.txt');
    });

    test('empty path resolves to root', () {
      expect(resolveSandboxPath(root, ''), root);
    });

    test('normalizes . and redundant separators', () {
      expect(resolveSandboxPath(root, './a//b/./c'), '$root/a/b/c');
    });

    test('allows .. that stays inside root', () {
      expect(resolveSandboxPath(root, 'a/b/../c'), '$root/a/c');
    });

    test('rejects traversal escaping the root', () {
      expect(resolveSandboxPath(root, '../etc/passwd'), isNull);
      expect(resolveSandboxPath(root, 'a/../../etc/passwd'), isNull);
      expect(resolveSandboxPath(root, '..'), isNull);
    });
  });
}
