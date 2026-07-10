import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';

/// Fetches weather from Open-Meteo (free, no API key needed).
/// Supports current conditions and short-term forecast.
class GetWeatherTool implements ToolInterface {
  static const _definition = ToolDefinition(
    name: 'get_weather',
    description:
        'Aktuelles Wetter und Kurzprognose. Nutze fuer Tagesplanung oder Kleidungstipps.',
    parametersSchema: {
      'type': 'object',
      'properties': {
        'forecast_days': {
          'type': 'integer',
          'description': 'Anzahl Prognosetage (Standard: 1 = heute, max 3)',
        },
      },
      'required': [],
    },
  );

  @override
  ToolDefinition get definition => _definition;

  // Vienna default coordinates
  static const _lat = 48.22;
  static const _lon = 16.30;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final days = (parameters['forecast_days'] as num?)?.toInt().clamp(1, 3) ?? 1;

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$_lat',
        'longitude': '$_lon',
        'current': 'temperature_2m,relative_humidity_2m,weather_code,is_day,apparent_temperature',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'timezone': 'Europe/Vienna',
        'forecast_days': '$days',
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Wetterdaten nicht verfügbar (HTTP ${response.statusCode}).',
          displayText: '🌤️ Wetter nicht verfügbar',
          isError: true,
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final current = data['current'] as Map<String, dynamic>?;
      final daily = (data['daily'] as Map<String, dynamic>?);

      if (current == null) {
        return ToolResult(
          toolName: definition.name,
          parameters: parameters,
          result: 'Wetterdaten unvollständig.',
          displayText: '🌤️ Wetter unvollständig',
          isError: true,
        );
      }

      final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 0.0;
      final feelsLike = (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
      // Open-Meteo may return these as doubles — as int? would throw.
      final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 0;
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;
      final isDay = (current['is_day'] as num?)?.toInt() == 1;

      final icon = _weatherIcon(code, isDay);
      final description = _weatherDescription(code);

      String result = 'Aktuell in Wien: $icon ${temp.round()}°C (gefühlt ${feelsLike.round()}°C), $description. Luftfeuchtigkeit $humidity%.';

      if (daily != null) {
        final codes = daily['weather_code'] as List<dynamic>?;
        final maxs = daily['temperature_2m_max'] as List<dynamic>?;
        final mins = daily['temperature_2m_min'] as List<dynamic>?;
        if (codes != null && maxs != null && mins != null && codes.length > 1) {
          result += '\n\nVorschau:';
          final now = DateTime.now();
          for (int i = 1; i < codes.length && i < days; i++) {
            final day = now.add(Duration(days: i));
            final dayCode = (codes[i] as num?)?.toInt() ?? 0;
            final dayMax = (maxs[i] as num).toDouble().round();
            final dayMin = (mins[i] as num).toDouble().round();
            result += '\n${day.day}.${day.month}.: ${_weatherIcon(dayCode, true)} $dayMin°–$dayMax° ${_weatherDescription(dayCode)}';
          }
        }
      }

      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: result,
        displayText: '$icon ${temp.round()}°C, $description',
      );
    } catch (e) {
      return ToolResult(
        toolName: definition.name,
        parameters: parameters,
        result: 'Fehler beim Wetterabruf: $e',
        displayText: '🌤️ Wetter-Fehler',
        isError: true,
      );
    }
  }

  static String _weatherIcon(int code, bool isDay) {
    // WMO Weather interpretation codes
    if (code == 0) return isDay ? '☀️' : '🌙';
    if (code <= 3) return isDay ? '⛅' : '☁️';
    if (code <= 48) return '🌫️';
    if (code <= 55) return '🌧️';
    if (code <= 57) return '🌧️';
    if (code <= 67) return '☔';
    if (code <= 77) return '❄️';
    if (code <= 82) return '🌦️';
    if (code <= 86) return '🌨️';
    if (code <= 99) return '⛈️';
    return '❓';
  }

  static String _weatherDescription(int code) {
    if (code == 0) return 'klar';
    if (code <= 3) return 'teils bewölkt';
    if (code <= 48) return 'neblig';
    if (code <= 55) return 'Nieselregen';
    if (code <= 57) return 'leichter Regen';
    if (code <= 67) return 'Regen';
    if (code <= 77) return 'Schnee';
    if (code <= 82) return 'Regenschauer';
    if (code <= 86) return 'Schneeschauer';
    if (code <= 99) return 'Gewitter';
    return 'unbekannt';
  }
}
