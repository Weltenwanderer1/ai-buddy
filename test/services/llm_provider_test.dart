import 'package:ai_buddy/services/llm_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveToolLoopText', () {
    test('prefers the model response after tool execution', () {
      expect(
        resolveToolLoopText(
          modelContent: 'Im Vault liegen echte Notizen.',
          toolResults: const ['Vault-Dateien: Index.md'],
        ),
        'Im Vault liegen echte Notizen.',
      );
    });

    test('returns actual tool data when the model emits no final text', () {
      expect(
        resolveToolLoopText(
          modelContent: '',
          toolResults: const [
            'Vault-Dateien (2):\n- Index (`Index.md`)\n- Regeln (`00-Regeln/Regeln.md`)',
          ],
        ),
        'Vault-Dateien (2):\n- Index (`Index.md`)\n- Regeln (`00-Regeln/Regeln.md`)',
      );
    });

    test('keeps results from parallel tool calls instead of hiding them', () {
      expect(
        resolveToolLoopText(
          modelContent: '   ',
          toolResults: const ['Ergebnis A', '', 'Ergebnis B'],
        ),
        'Ergebnis A\n\nErgebnis B',
      );
    });

    test('uses the generic message only if no tool produced data', () {
      expect(
        resolveToolLoopText(modelContent: '', toolResults: const []),
        'Tool-Aufruf ausgeführt.',
      );
    });
  });
}
