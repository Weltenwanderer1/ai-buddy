import 'package:latlong2/latlong.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import 'tool_interface.dart';

/// Tool fuer Navigation — die KI kann den User zu einem Ziel leiten.
class NavigateToTool implements ToolInterface {
  final NavigationService _nav;

  NavigateToTool({NavigationService? navigationService})
      : _nav = navigationService ?? NavigationService();

  @override
  ToolDefinition get definition => ToolDefinition(
    name: 'navigate_to',
    description:
        'Navigiere den User zu einem Ziel. Gib den Zielort an. '
        'Fuer Wanderungen/Routen im Wald: profile=walking (default). '
        'Fuer Fahrten: profile=driving. Fuer Rad: profile=cycling.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'destination': {
          'type': 'string',
          'description':
              'Zielort z.B. "Waldweg Gersthof", "Stephansdom Wien", "Badesee"',
        },
        'profile': {
          'type': 'string',
          'description': 'walking (default), cycling, driving',
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

    // Aktueller Standort
    final loc = await LocationService().getLocation();
    if (loc == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Standort nicht verfuegbar. Bitte GPS aktivieren.',
        isError: true,
        displayText: 'Standort nicht verfuegbar',
      );
    }

    final from = LatLng(loc.latitude, loc.longitude);

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

    // Route berechnen
    final route = await _nav.getRoute(from, to, profile: profile);
    if (route == null) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Route konnte nicht berechnet werden.',
        isError: true,
        displayText: 'Route nicht verfuegbar',
      );
    }

    final buf = StringBuffer();
    buf.writeln('Route nach "$destination":');
    buf.writeln(
        '${route.distanceText} | ${route.durationText} (${profile == 'walking' ? 'Wandern' : profile == 'cycling' ? 'Rad' : 'Auto'})');
    buf.writeln();
    buf.writeln('Schritte:');
    for (var i = 0; i < route.steps.length; i++) {
      final s = route.steps[i];
      buf.writeln(
          '${i + 1}. ${s.instruction} (${s.distance >= 1000 ? "${(s.distance / 1000).toStringAsFixed(1)} km" : "${s.distance.round()} m"})');
    }

    return ToolResult(
      toolName: definition.name,
      parameters: parameters,
      result: buf.toString(),
      displayText: '🗺️ Navigation nach $destination gestartet',
      extraData: {
        'route': route.toJson(),  // Vorher: rohes RouteResult-Objekt → JSON-Serialisierung bricht!
        'target': {'lat': to.latitude, 'lon': to.longitude},
        'destination_name': destination,
        'show_map': true,
      },
    );
  }
}
