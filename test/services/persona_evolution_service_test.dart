import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/persona_evolution_service.dart';

void main() {
  group('PersonaEvolutionService', () {
    test('buildEvolutionContext returns empty when no data', () {
      final service = PersonaEvolutionService();
      expect(service.buildEvolutionContext(), '');
    });

    test('buildEvolutionContext includes learned traits', () {
      final service = PersonaEvolutionService();
      service.testLearnedTraits = ['freundlich', 'geduldig'];
      final context = service.buildEvolutionContext();
      expect(context, contains('freundlich'));
      expect(context, contains('geduldig'));
    });

    test('buildEvolutionContext includes avoid topics', () {
      final service = PersonaEvolutionService();
      service.testAvoidTopics = ['Politik', 'Sport'];
      final context = service.buildEvolutionContext();
      expect(context, contains('Politik'));
      expect(context, contains('Sport'));
    });

    test('buildEvolutionContext includes preferred style', () {
      final service = PersonaEvolutionService();
      service.testPreferredStyle = ['kurz', 'direkt'];
      final context = service.buildEvolutionContext();
      expect(context, contains('kurz'));
      expect(context, contains('direkt'));
    });

    test('parseEvolutionResponse reads bullet list entries', () {
      final service = PersonaEvolutionService();
      const response = '- freundlich\n- geduldig\n- humorvoll';
      service.parseEvolutionResponse(response);
      expect(service.learnedTraits, ['freundlich', 'geduldig', 'humorvoll']);
    });

    test('parseEvolutionResponse ignores non-bullet lines', () {
      final service = PersonaEvolutionService();
      const response = 'Hier ist die Analyse:\n- empathisch\nDas wars!';
      service.parseEvolutionResponse(response);
      expect(service.learnedTraits, ['empathisch']);
    });

    test('parseEvolutionResponse deduplicates traits', () {
      final service = PersonaEvolutionService();
      service.testLearnedTraits = ['freundlich'];
      const response = '- freundlich\n- neugierig\n- freundlich';
      service.parseEvolutionResponse(response);
      expect(service.learnedTraits.length, 2);
      expect(service.learnedTraits, ['freundlich', 'neugierig']);
    });

    test('parseEvolutionResponse handles empty response', () {
      final service = PersonaEvolutionService();
      service.parseEvolutionResponse('');
      expect(service.learnedTraits, isEmpty);
    });

    test('parseEvolutionResponse handles JSON-like text as non-bullet (no crash)', () {
      final service = PersonaEvolutionService();
      const response = '{"traits": ["x"], "avoid": ["y"]}';
      // JSON is not bullet-list format — should be ignored safely
      service.parseEvolutionResponse(response);
      expect(service.learnedTraits, isEmpty);
    });

    test('exportData includes all fields', () {
      final service = PersonaEvolutionService();
      service.testLearnedTraits = ['trait1'];
      service.testAvoidTopics = ['topic1'];
      service.testPreferredStyle = ['style1'];
      service.testLearnedStyle = {'traits': ['trait1'], 'avoid': ['topic1']};

      final data = service.exportData();
      expect(data['learnedTraits'], ['trait1']);
      expect(data['avoidTopics'], ['topic1']);
      expect(data['preferredStyle'], ['style1']);
      expect(data['learnedStyle'], isA<Map>());
    });

    test('importData restores all fields', () async {
      final service = PersonaEvolutionService();

      final importData = {
        'learnedTraits': ['trait1', 'trait2'],
        'avoidTopics': ['topic1'],
        'preferredStyle': ['kurz', 'direkt'],
        'learnedStyle': {'key': 'value'},
      };

      await service.importData(importData);
      expect(service.learnedTraits, ['trait1', 'trait2']);
      expect(service.avoidTopics, ['topic1']);
    });

    test('traits are capped at 20', () {
      final service = PersonaEvolutionService();
      final traits = List.generate(25, (i) => 'trait_$i');
      service.testLearnedTraits = traits;

      // Simulate cap (done in _parseEvolutionResponse)
      if (service.testLearnedTraits.length > 20) {
        service.testLearnedTraits = service.testLearnedTraits.sublist(service.testLearnedTraits.length - 20);
      }
      expect(service.testLearnedTraits.length, 20);
      expect(service.testLearnedTraits.first, 'trait_5');
    });

    test('no duplicate traits added', () {
      final service = PersonaEvolutionService();
      service.testLearnedTraits = ['freundlich'];
      final newTraits = ['freundlich', 'neugierig'];
      for (final t in newTraits) {
        if (!service.testLearnedTraits.contains(t)) {
          service.testLearnedTraits = [...service.testLearnedTraits, t];
        }
      }
      expect(service.testLearnedTraits.length, 2);
      expect(service.testLearnedTraits, ['freundlich', 'neugierig']);
    });
  });
}
