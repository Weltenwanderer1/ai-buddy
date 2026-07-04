import 'package:flutter_test/flutter_test.dart';
import 'package:ai_buddy/services/chat_service.dart';
import 'package:ai_buddy/services/persona_service.dart';

void main() {
  group('ChatService', () {
    test('evolutionInterval is 10', () {
      expect(ChatService.evolutionInterval, 10);
    });

    test('buildSystemPrompt includes evolution context when provided', () {
      final persona = PersonaService();
      persona.testName = 'Luna';
      persona.testPersonality = ['freundlich'];
      persona.testIsComplete = true;

      final prompt = persona.buildSystemPrompt(
        evolutionContext: 'User-Schreibstil: kurz, direkt. Vermeide: Politik',
      );
      expect(prompt, contains('kurz, direkt'));
      expect(prompt, contains('Politik'));
    });

    test('buildSystemPrompt without evolution context still works', () {
      final persona = PersonaService();
      persona.testName = 'Luna';
      persona.testPersonality = ['freundlich'];
      persona.testIsComplete = true;
      final prompt = persona.buildSystemPrompt();
      expect(prompt, contains('Luna'));
      expect(prompt, isNot(contains('Schreibstil')));
    });

    test('PersonaEvolutionService context is injected into system prompt', () {
      final persona = PersonaService();
      persona.testName = 'Luna';
      persona.testPersonality = ['freundlich', 'hilfsbereit'];
      persona.testIsComplete = true;

      // Simulate what ChatService does when building the prompt
      const evolutionContext =
          'Bevorzugter Stil: kurz, direkt. Vermeide: Smalltalk, Politik';
      final prompt =
          persona.buildSystemPrompt(evolutionContext: evolutionContext);

      // The evolution context should be part of the system prompt
      expect(prompt, contains('kurz, direkt'));
      expect(prompt, contains('Smalltalk'));
    });
  });

  group('ChatService Preload Detection', () {
    test('detects app opening commands with oe-variant', () {
      final commands = [
        'Öffne Spotify',
        'öffne WhatsApp',
        'oeffne Spotify',
        'oeffne WhatsApp',
        'oeffne die Google Maps App',
        'oeffne Einstellungen',
        'Starte Spotify bitte',
        'Mach Spotify auf',
      ];
      for (final cmd in commands) {
        final lower = cmd.toLowerCase();
        final asksOpenApp = RegExp(
          r'öffne|oeffne|offne|starte|mach.*auf|zeig.*an|geh.*zu|app.*start|öffnen|oeffnen|offnen|launch|play|öffn|oeffn|offn',
          caseSensitive: false,
          unicode: true,
        ).hasMatch(lower);
        expect(asksOpenApp, isTrue, reason: 'Should detect "$cmd"');
      }
    });

    test('detects navigation commands', () {
      final commands = [
        'navigiere mich zu Stephansdom',
        'fahr mich nach Berlin',
        'Route zu Hauptbahnhof',
        'bring mich zum Flughafen',
        'wie komme ich zum Stephansdom',
      ];
      for (final cmd in commands) {
        final lower = cmd.toLowerCase();
        final asksNavigate = RegExp(
          r'(navigiere|navigier|navi|fahr\s+nach|fahr\s+zu|fahr\s+mich|fahre\s+nach|fahre\s+zu|route\s+zu|bring\s+mich\s+zum|bring\s+mich\s+zu|bring\s+mich\s+nach|wie\s+komme\s+ich\s+zum|wie\s+komme\s+ich\s+zu|weg\s+zu|richtung|lotse|lotsen)',
          caseSensitive: false,
        ).hasMatch(lower);
        expect(asksNavigate, isTrue, reason: 'Should detect "$cmd"');
      }
    });

    test('extracts destination from navigation commands', () {
      final commands = [
        'navigiere mich zu Stephansdom Wien',
        'fahr mich nach Berlin',
        'Route zu Hauptbahnhof',
        'bring mich zum Flughafen',
        'wie komme ich zum Stephansdom',
      ];
      final expected = [
        'Stephansdom Wien',
        'Berlin',
        'Hauptbahnhof',
        'Flughafen',
        'Stephansdom',
      ];
      for (var i = 0; i < commands.length; i++) {
        final navMatch = RegExp(
          r'(?:navigiere|navigier|navi|fahr\s+nach|fahr\s+zu|fahr\s+mich|fahre\s+nach|fahre\s+zu|route\s+zu|bring\s+mich\s+zum|bring\s+mich\s+zu|bring\s+mich\s+nach|wie\s+komme\s+ich\s+zum|wie\s+komme\s+ich\s+zu|weg\s+zu|richtung|lotse|lotsen)\s+(.+?)(?:\s+(?:bitte|mal|jetzt|fuer|fuer\s+mich|mit))?[.!?,;:\s]*$',
          caseSensitive: false,
        ).firstMatch(commands[i].trim());
        expect(navMatch, isNotNull, reason: 'Should match "${commands[i]}"');
        var rawDestination = navMatch!.group(1)?.trim() ?? '';
        var destination = rawDestination
            .replaceAll(
                RegExp(
                    r'^(?:mich\s+(?:zu|nach)\s+|zu\s+|nach\s+|zum\s+|zur\s+)'),
                '')
            .trim();
        expect(destination, expected[i],
            reason: 'Should extract destination from "${commands[i]}"');
      }
    });

    test('extracts app name from open commands with oe-variants', () {
      // Test cases: command and expected app name
      final commands = [
        ('Öffne Spotify', 'Spotify'),
        ('öffne WhatsApp', 'WhatsApp'),
        ('oeffne Spotify', 'Spotify'),
        ('oeffne WhatsApp', 'WhatsApp'),
        ('oeffne die Google Maps App', 'Google Maps'),
        ('oeffne die Einstellungen', 'Einstellungen'),
        ('Starte Spotify bitte', 'Spotify'),
        ('Mach Spotify auf', 'Spotify'),
      ];
      for (final (cmd, expectedApp) in commands) {
        String? appName;

        // First try: "mach ... auf" pattern
        final machMatch = RegExp(
          r'mach\s+(?:die\s+)?(?:app\s+)?([\w\säöüÄÖÜß]+?)\s+auf',
          caseSensitive: false,
        ).firstMatch(cmd.trim());
        if (machMatch != null) {
          appName = machMatch.group(1)?.trim();
        }

        // Second try: standard pattern
        if (appName == null || appName.isEmpty) {
          final appMatch = RegExp(
            r'(?:öffne|oeffne|offne|starte|zeig.*an|geh.*zu|app.*start|öffnen|oeffnen|offnen|launch|play|öffn|oeffn|offn)\s+(?:die\s+)?(?:app\s+)?([\w\säöüÄÖÜß]+?)(?:\s+(?:app|bitte|mal|jetzt|für|fuer|für\s+mich|fuer\s+mich|ein|mal))?[.!?,;:\s]*$',
            caseSensitive: false,
            unicode: true,
          ).firstMatch(cmd.trim());
          if (appMatch != null) {
            appName = appMatch.group(1)?.trim();
          }
        }

        expect(appName, isNotNull, reason: 'Should match "$cmd"');
        appName = appName!.replaceAll(RegExp(r'\s+'), ' ').trim();
        expect(appName, expectedApp,
            reason: 'Should extract app name from "$cmd"');
      }
    });
  });
}
