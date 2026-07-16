import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'tool_interface.dart';
import 'tool_definition.dart';
import 'tool_result.dart';
import '../services/location_service.dart';

/// Fetches weather from Open-Meteo (free, no API key needed).
/// Uses the device's current location for accurate forecasts.
/// Includes clothing recommendations based on temperature and conditions.
class GetWeatherTool implements ToolInterface {
  final LocationService _locationService;

  GetWeatherTool({required LocationService locationService})
      : _locationService = locationService;

  /// Creates an instance that always uses Vienna as fallback.
  GetWeatherTool.fallback()
      : _locationService = FallbackLocationService();

  static const _definition = ToolDefinition(
    name: 'get_weather',
    description:
        'Aktuelles Wetter und Kurzprognose für den aktuellen Standort. '
        'Enthält Kleidungs- und Regenschirm-Empfehlung für den Tag. '
        'Nutze für Tagesplanung oder um zu wissen was die Kinder anziehen sollen.',
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

  // Vienna default coordinates (fallback)
  static const _defaultLat = 48.22;
  static const _defaultLon = 16.30;

  @override
  Future<ToolResult> execute(Map<String, dynamic> parameters) async {
    final days = (parameters['forecast_days'] as num?)?.toInt().clamp(1, 3) ?? 1;

    // Get dynamic location
    double lat = _defaultLat;
    double lon = _defaultLon;
    String locationName = 'Wien';
    try {
      final loc = await _locationService.getLocation();
      if (loc != null) {
        lat = loc.latitude;
        lon = loc.longitude;
        locationName = loc.toShortString();
      }
    } catch (e) {
      debugPrint('GetWeatherTool: location failed, using default: $e');
    }

    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': lat.toStringAsFixed(2),
        'longitude': lon.toStringAsFixed(2),
        'current': 'temperature_2m,relative_humidity_2m,weather_code,is_day,apparent_temperature,wind_speed_10m,precipitation',
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_speed_10m_max',
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
      final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
      final precip = (current['precipitation'] as num?)?.toDouble() ?? 0.0;
      final isRainy = code >= 40 && code <= 67;

      String result = 'Aktuell in $locationName: $icon ${temp.round()}°C (gefühlt ${feelsLike.round()}°C), $description.';
      result += '\n💨 Wind: ${wind.round()} km/h';
      result += '\n💧 Luftfeuchtigkeit: $humidity%';

      // ─── Clothing recommendation ───
      result += '\n\n👕 Kleidungs-Tipp: ';
      if (temp < 0) {
        result += 'Winterjacke, Mütze, Handschuhe, Schal. Mehrere Schichten.';
      } else if (temp < 8) {
        result += 'Warme Jacke, Pullover, lange Hose. Mütze empfohlen.';
      } else if (temp < 14) {
        result += 'Leichte Jacke oder Strickjacke, langarm reicht meist.';
      } else if (temp < 20) {
        result += 'Pullover oder langarm reicht. Dünne Jacke für abends.';
      } else if (temp < 27) {
        result += 'T-Shirt, kurze Hose. Sonnencreme nicht vergessen!';
      } else {
        result += 'Leichte Kleidung, Sonnenhut, viel trinken. ☀️';
      }

      // ─── Kid-specific tip ───
      result += '\n👶 Für Kinder: ';
      if (temp > 25) {
        result += 'Sonnenhut + Sonnencreme, leichte Kleidung, immer Wasser dabei.';
      } else if (isRainy || precip > 0.3) {
        result += 'Regenjacke oder Schirm nicht vergessen!';
      } else if (temp < 10) {
        result += 'Winterjacke oder dicker Anorak, Ohren warm halten!';
      } else {
        result += 'Eine dünne Jacke zum Überziehen reicht meist.';
      }

      // ─── Umbrella hint ───
      if (isRainy && wind > 30) {
        result += '\n☔ Es regnet UND es ist windig — Schirm bringt nix, Regenjacke ist besser!';
      } else if (isRainy || precip > 0.5) {
        result += '\n☂️ Regenschirm einpacken!';
      }

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
