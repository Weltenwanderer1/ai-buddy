import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:latlong2/latlong.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'tool_interface.dart';

/// Smartes Navigationstool:
/// - auto / driving → Google Maps extern (Turn-by-turn)
/// - walking / cycling → OSM in der App mit Route+Karte
/// - Ohne GPS: Ziel trotzdem auf Karte zeigen (Pin, keine Route)
class NavigateToTool implements ToolInterface {
  final NavigationService _nav;

  NavigateToTool({NavigationService? navigationService})
      : _nav = navigationService ?? NavigationService();

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'open_navigation',
    description:
        'Navigiere den User zu einem Ziel. Standard ist ZU FUSS (profile=walking). '
        'Fuß-Routen werden auf einer OSM-Karte IN der App mit Live-Tracking '
        '(Schritt-fuer-Schritt, Re-Routing bei Abweichung). '
        'Fuer Auto: profile=driving (oeffnet Google Maps). '
        'Fuer Rad: profile=cycling.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'destination': {
          'type': 'string',
          'description': 'Zielort z.B. "Stephansdom Wien", "Badesee", "Albertgasse 38"',
        },
        'profile': {
          'type': 'string',
          'description': 'walking (default, zu Fuss), cycling (Rad), driving (Auto)',
          'enum': ['walking', 'cycling', 'driving'],
        },
      },
      'required': ['destination'],
    },
  );

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final destination = parameters['destination'] as String;
    final profile = (parameters['profile'] as String?) ?? 'walking';

    // ── Auto-Modus: Google Maps Intent (Turn-by-turn, real-time traffic) ──
    if (profile == 'driving') {
      try {
        final intent = AndroidIntent(
          action: 'android.intent.action.VIEW',
          data: 'google.navigation:q=${Uri.encodeComponent(destination)}',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Google Maps Navigation zu "$destination" gestartet.',
          displayText: '🚗 Navigation nach $destination gestartet',
        );
      } catch (_) {
        // Fallback: Google Maps URL
        try {
          final intent = AndroidIntent(
            action: 'android.intent.action.VIEW',
            data: 'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=driving',
            flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
          );
          await intent.launch();
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Google Maps zu "$destination" geoeffnet.',
            displayText: '🗺️ $destination in Maps geöffnet',
          );
        } catch (e) {
          return ToolResult(
            toolName: definition.name,
            parameters: parameters,
            result: 'Konnte Navigation nicht öffnen: $e',
            isError: true,
            displayText: 'Navigation fehlgeschlagen',
          );
        }
      }
    }

    // ── Fuß/Rad: OSM In-App-Navigation ──
    // Ziel geocoden
    final to = await _nav.geocode(destination);
    if (to == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Ziel "$destination" nicht gefunden.',
        isError: true,
        displayText: 'Ziel nicht gefunden',
      );
    }

    // GPS optional — ohne geht's auch, dann nur Pin
    final loc = await LocationService().getLocation();
    final from = loc != null ? LatLng(loc.latitude, loc.longitude) : null;

    // Route berechnen wenn GPS da
    RouteResult? route;
    if (from != null) {
      route = await _nav.getRoute(from, to, profile: profile);
    }

    // Ergebnis-Text
    final buf = StringBuffer();
    final modeLabel = profile == 'cycling' ? 'Rad' : 'Wandern';
    buf.writeln('📍 $destination');

    if (route != null) {
      buf.writeln('${route.distanceText} | ${route.durationText} ($modeLabel)');
      buf.writeln();
      buf.writeln('Schritte:');
      for (var i = 0; i < route.steps.length; i++) {
        final s = route.steps[i];
        buf.writeln('${i + 1}. ${s.instruction} (${s.distance >= 1000 ? "${(s.distance / 1000).toStringAsFixed(1)} km" : "${s.distance.round()} m"})');
      }
    } else if (from == null) {
      buf.writeln('(Kein GPS — Ziel wird auf Karte angezeigt)');
    } else {
      buf.writeln('Route konnte nicht berechnet werden.');
    }

    final displayText = route != null
        ? '🗺️ ${route.distanceText} · ${route.durationText} nach $destination'
        : '📍 $destination auf Karte';

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: buf.toString(),
      displayText: displayText,
      extraData: {
        'route': route?.toJson(),
        'target': {'lat': to.latitude, 'lon': to.longitude},
        'destination_name': destination,
        'show_map': true,
      },
    );
  }
}
