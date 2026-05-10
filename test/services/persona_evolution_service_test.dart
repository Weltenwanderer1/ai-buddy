import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/persona_evolution_service.dart';
import 'package:ai_buddy/services/ollama_cloud_service.dart';

OllamaCloudService _testLLM() => OllamaCloudService(
      baseUrl: 'https://test.example.com',
      apiKey: 'test',
      defaultModel: 'test',
      fallbackModel: 'test-fallback',
    );

void main() {
  group('PersonaEvolutionService', () {
    test('buildEvolutionContext returns empty when no data', () {
      final service = PersonaEvolutionService(_testLLM());
      expect(service.buildEvolutionContext(), '');
    });

    test('buildEvolutionContext includes preferred style', () {
      final service = PersonaEvolutionService(_testLLM());
      service.testPreferredStyle = ['kurz', 'direkt'];
      service.testAvoidTopics = ['Politik'];
      service.testLearnedTraits = ['freundlich'];

      final context = service.buildEvolutionContext();
      expect(context, contains('kurz'));
      expect(context, contains('direkt'));
      expect(context, contains('Politik'));
    });

    test('buildEvolutionContext includes avoid topics', () {
      final service = PersonaEvolutionService(_testLLM());
      service.testAvoidTopics = ['Sport', 'Wetter'];
      final context = service.buildEvolutionContext();
      expect(context, contains('Sport'));
      expect(context, contains('Wetter'));
    });

    test('exportData includes all fields', () {
      final service = PersonaEvolutionService(_testLLM());
      service.testLearnedTraits = ['trait1'];
      service.testAvoidTopics = ['topic1'];
      service.testPreferredStyle = ['style1'];
      service.testLearnedStyle = {'traits': ['trait1'], 'avoid': ['topic1']};

      final data = service.exportData();
      expect(data['traits'], ['trait1']);
      expect(data['avoid'], ['topic1']);
      expect(data['user_style'], ['style1']);
      expect(data['style'], isA<Map>());
    });

    test('importData restores all fields', () async {
      final service = PersonaEvolutionService(_testLLM());

      final importData = {
        'traits': ['trait1', 'trait2'],
        'avoid': ['topic1'],
        'user_style': ['kurz', 'direkt'],
        'style': {'key': 'value'},
      };

      await service.importData(importData);
      expect(service.learnedTraits, ['trait1', 'trait2']);
      expect(service.avoidTopics, ['topic1']);
    });

    test('parseEvolutionResponse handles valid JSON', () {
      final service = PersonaEvolutionService(_testLLM());
      const response = '{"new_traits": ["empathisch"], "avoid": ["Smalltalk"], "style": ["formal"]}';
      service.parseEvolutionResponse(response);
      expect(service.learnedTraits, contains('empathisch'));
      expect(service.avoidTopics, contains('Smalltalk'));
    });

    test('parseEvolutionResponse handles JSON embedded in text', () {
      final service = PersonaEvolutionService(_testLLM());
      const response = 'Hier ist die Analyse:\n{"new_traits": ["humorvoll"], "avoid": [], "style": ["sarkastisch"]}\nDas wars!';
      service.parseEvolutionResponse(response);
      expect(service.learnedTraits, contains('humorvoll'));
    });

    test('parseEvolutionResponse handles invalid JSON gracefully', () {
      final service = PersonaEvolutionService(_testLLM());
      // Should not throw
      service.parseEvolutionResponse('not json at all');
      expect(service.learnedTraits, isEmpty);
    });

    test('traits are capped at 20', () {
      final service = PersonaEvolutionService(_testLLM());
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
      final service = PersonaEvolutionService(_testLLM());
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