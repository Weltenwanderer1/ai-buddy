import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Opens navigation to a destination using Google Maps or Android geo intent.
/// Handles German commands like "navigiere mich zu Stephansdom",
/// "fahr mich nach Berlin", "Route zu Hauptbahnhof".
class NavigateTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'open_navigation',
    description:
        'Öffnet die Navigation zu einem Ziel. Nutze dies für Navigationsbefehle wie "navigiere mich zu …", "fahr mich nach …", "Route zu …", "bring mich zu …". Öffnet Google Maps Navigation auf dem Gerät.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'destination': {
          'type': 'string',
          'description':
              'Zielort oder Adresse (z.B. "Stephansdom Wien", "Berlin Hauptbahnhof", "Schönbrunn Palace")',
        },
        'mode': {
          'type': 'string',
          'description':
              'Verkehrsmittel: "auto" (Standard), "fuss" / "gehen" / "laufen", "fahrrad" / "rad", "öpnv" / "transit". Optional.',
        },
      },
      'required': ['destination'],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  /// Normalize transport mode to Google Maps direction mode parameter.
  static String _normalizeMode(String? mode) {
    if (mode == null || mode.isEmpty) return 'd';
    final m = mode.toLowerCase().trim();
    switch (m) {
      case 'fuss':
      case 'fuß':
      case 'gehen':
      case 'laufen':
      case 'walking':
      case 'walk':
      case 'zu fuss':
      case 'zu fuß':
        return 'w';
      case 'fahrrad':
      case 'rad':
      case 'bike':
      case 'cycling':
      case 'bicycle':
      case 'velo':
        return 'b';
      case 'öpnv':
      case 'oepnv':
      case 'transit':
      case 'public':
      case 'bus':
      case 'bahn':
      case 'zug':
      case 'train':
      case 'oeffentlich':
      case 'öffentliche':
        return 't';
      case 'auto':
      case 'car':
      case 'fahren':
      case 'driving':
      case 'drive':
      default:
        return 'd';
    }
  }

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final destination = (parameters['destination'] as String? ?? '').trim();
      if (destination.isEmpty) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Kein Ziel angegeben',
          isError: true,
          displayText: 'Kein Ziel angegeben',
        );
      }

      final mode = _normalizeMode(parameters['mode'] as String?);

      // Try google.navigation intent first (turn-by-turn navigation)
      final navIntent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data:
            'google.navigation:q=${Uri.encodeComponent(destination)}&mode=$mode',
        flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
      );

      try {
        await navIntent.launch();
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Navigation gestartet: $destination (Modus: $mode)',
          displayText: '🧭 Navigation zu $destination gestartet',
        );
      } catch (navError) {
        // Fallback: open in Google Maps (no turn-by-turn but shows route)
        final mapsIntent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data:
              'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=${mode == 'd' ? 'driving' : mode == 'w' ? 'walking' : mode == 'b' ? 'bicycling' : 'transit'}',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        try {
          await mapsIntent.launch();
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Google Maps geöffnet: $destination (Modus: $mode)',
            displayText: '🧭 Route zu $destination in Maps geöffnet',
          );
        } catch (mapsError) {
          // Last resort: plain geo intent
          final geoIntent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'geo:0,0?q=${Uri.encodeComponent(destination)}',
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );

          try {
            await geoIntent.launch();
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Karte geöffnet: $destination',
              displayText: '🧭 $destination auf Karte angezeigt',
            );
          } catch (geoError) {
            return ToolResult(
              toolName: definition.name,
              parameters: parameters,
              result: 'Konnte Navigation nicht öffnen: $geoError',
              isError: true,
              displayText: 'Navigation konnte nicht geöffnet werden',
            );
          }
        }
      }
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei der Navigation: $e',
        isError: true,
        displayText: 'Fehler bei der Navigation',
      );
    }
  }
}
