import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/persona_service.dart';

void main() {
  group('PersonaService', () {
    test('buildSystemPrompt without evolution context', () {
      final service = PersonaService();
      service.testName = 'Luna';
      service.testPersonality = ['freundlich', 'hilfsbereit', 'neugierig'];
      service.testGreeting = 'Hallo!';
      service.testBackstory = 'Luna ist ein AI-Begleiter.';
      service.testIsComplete = true;

      final prompt = service.buildSystemPrompt();
      expect(prompt, contains('Luna'));
      expect(prompt, contains('freundlich'));
      expect(prompt, contains('hilfsbereit'));
      expect(prompt, contains('neugierig'));
      expect(prompt, contains('Luna ist ein AI-Begleiter'));
      expect(prompt, contains('REGELN'));
    });

    test('buildSystemPrompt with evolution context', () {
      final service = PersonaService();
      service.testName = 'Luna';
      service.testPersonality = ['freundlich'];
      service.testIsComplete = true;

      final prompt = service.buildSystemPrompt(
        evolutionContext: 'User-Schreibstil: kurz, direkt. Themen vermeiden: Politik',
      );
      expect(prompt, contains('Luna'));
      expect(prompt, contains('kurz, direkt'));
      expect(prompt, contains('Politik'));
    });

    test('buildSystemPrompt with empty personality', () {
      final service = PersonaService();
      service.testName = 'Bot';
      service.testPersonality = [];
      service.testIsComplete = true;

      final prompt = service.buildSystemPrompt();
      expect(prompt, contains('Bot'));
      // Should not have "Deine Persönlichkeit: " with empty content
      expect(prompt, isNot(contains('Deine Persönlichkeit: ')));
    });

    test('exportData produces correct structure', () {
      final service = PersonaService();
      service.testName = 'Luna';
      service.testPersonality = ['freundlich', 'hilfsbereit'];
      service.testGreeting = 'Hallo!';
      service.testBackstory = 'Test backstory';
      service.testIsComplete = true;

      final exported = service.exportData();
      expect(exported['name'], 'Luna');
      expect(exported['personality'], ['freundlich', 'hilfsbereit']);
      expect(exported['greeting'], 'Hallo!');
      expect(exported['backstory'], 'Test backstory');
      expect(exported['isComplete'], isTrue);

      // exportData verified above — importData requires path_provider for persistence
    });

    test('safeStringList handles various inputs', () {
      expect(PersonaService.safeStringList(null), isEmpty);
      expect(PersonaService.safeStringList([]), isEmpty);
      expect(PersonaService.safeStringList(['a', 'b']), ['a', 'b']);
      expect(PersonaService.safeStringList([1, 2, 3]), ['1', '2', '3']);
      expect(PersonaService.safeStringList(['a', null, 'b']), ['a', 'b']);
    });
  });
}
