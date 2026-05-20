import '../services/location_service.dart';
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Tool that returns the user's current location (city, district, country, lat/lng).
class GetLocationTool implements ToolInterface {
  final LocationService _locationService;

  GetLocationTool(this._locationService);

  static const _definition = ToolDefinition(
    name: 'get_location',
    description:
        'Ermittelt den aktuellen Standort des Users (Stadt, Bezirk, Land, Koordinaten). Nützlich für lokale Empfehlungen, Wetter, Zeitzonen oder ortsbezogene Fragen.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'refresh': {
          'type': 'boolean',
          'description':
              'Wenn true, wird der Standort neu abgefragt (ignoriert Cache). Standard: false.',
        },
      },
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    try {
      final refresh = parameters['refresh'] as bool? ?? false;
      final loc = refresh
          ? await _locationService.refreshLocation()
          : await _locationService.getLocation();

      if (loc == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Standort nicht verfügbar. Mögliche Gründe: GPS deaktiviert, keine Berechtigung oder kein Empfang.',
          displayText: '📍 Standort unbekannt',
          isError: true,
        );
      }

      final parts = <String>[
        'Stadt: ${loc.city}',
      ];
      if (loc.district != null && loc.district!.isNotEmpty) {
        parts.add('Bezirk: ${loc.district}');
      }
      if (loc.street != null && loc.street!.isNotEmpty) {
        parts.add('Straße: ${loc.street}');
      }
      parts.add('Land: ${loc.country}');
      if (loc.countryCode != null) parts.add('Ländercode: ${loc.countryCode}');
      parts.add('Koordinaten: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}');

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: parts.join('\n'),
        displayText: '📍 ${loc.toShortString()}',
        extraData: {
          'lat': loc.latitude,
          'lon': loc.longitude,
          'label': loc.toShortString(),
        },
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler bei Standortermittlung: $e',
        displayText: '📍 Fehler',
        isError: true,
      );
    }
  }
}
