import 'dart:convert';
import 'dart:math' show sin, cos, sqrt, atan2;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM-basierte Open-Source Navigation. Kein API-Key nötig.
/// Nutzt den public OSRM demo server. Waldwege via 'walking' (foot) profile.
class NavigationService {
  static const String _defaultOsrmBase = 'router.project-osrm.org';

  String _osrmBase = _defaultOsrmBase;

  NavigationService({String? customOsrmBase}) {
    if (customOsrmBase != null && customOsrmBase.isNotEmpty) {
      _osrmBase = customOsrmBase;
    }
  }

  /// Setze custom OSRM server URL (für offline/lokalen Server)
  void setCustomServer(String url) {
    _osrmBase = url;
  }

  /// Geocode: Ort → LatLng via Nominatim (free, no key)
  Future<LatLng?> geocode(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'accept-language': 'de',
    });
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'AI-Buddy-Navigator/0.77',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data.first['lat'] as String),
            double.parse(data.first['lon'] as String),
          );
        }
      }
    } catch (e) {}
    return null;
  }

  /// Route zwischen zwei Punkten berechnen.
  /// [profile]: 'walking' (default, für Wanderwege), 'cycling', 'driving'
  Future<RouteResult?> getRoute(LatLng from, LatLng to, {String profile = 'walking'}) async {
    final osrmProfile = _mapProfile(profile);
    final uri = Uri.https(
      _osrmBase,
      '/route/v1/$osrmProfile/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'},
    );
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = (geometry['coordinates'] as List).map((c) {
        final list = c as List;
        return LatLng(list[1] as double, list[0] as double);
      }).toList();

      final steps = ((route['legs'] as List).first['steps'] as List).map((s) {
        final step = s as Map<String, dynamic>;
        final maneuver = step['maneuver'] as Map<String, dynamic>;
        return RouteStep(
          instruction: _readableInstruction(
            maneuver['type'] as String,
            step['name'] as String? ?? '',
          ),
          distance: (step['distance'] as num).toDouble(),
          duration: (step['duration'] as num).toDouble(),
          location: LatLng(
            (maneuver['location'] as List)[1] as double,
            (maneuver['location'] as List)[0] as double,
          ),
        );
      }).toList();

      return RouteResult(
        points: coords,
        distanceMeters: distance,
        durationSeconds: duration,
        steps: steps,
        profile: profile,
      );
    } catch (e) {
      return null;
    }
  }

  /// Aktuelle Position → Ziel-Routentext (KI kann das sprechen)
  Future<String> getNavigationText(String fromPlace, String toPlace, {String profile = 'walking'}) async {
    final from = await geocode(fromPlace);
    final to = await geocode(toPlace);
    if (from == null || to == null) return 'Konnte Ort nicht finden.';
    final route = await getRoute(from, to, profile: profile);
    if (route == null) return 'Route konnte nicht berechnet werden.';

    final buf = StringBuffer();
    buf.writeln('Route von $fromPlace nach $toPlace:');
    buf.writeln('Distanz: ${route.distanceText}, Dauer: ${route.durationText}');
    buf.writeln();
    for (var i = 0; i < route.steps.length; i++) {
      buf.writeln('${i + 1}. ${route.steps[i].instruction} (${route.steps[i].distance >= 1000 ? "${(route.steps[i].distance/1000).toStringAsFixed(1)} km" : "${route.steps[i].distance.round()} m"})');
    }
    return buf.toString();
  }

  String _mapProfile(String p) {
    switch (p) {
      case 'cycling': return 'bike';
      case 'driving': return 'car';
      case 'walking':
      default: return 'foot';
    }
  }

  String _readableInstruction(String type, String name) {
    final map = {
      'depart': 'Starte',
      'arrive': 'Ankunft',
      'left': 'Links abbiegen',
      'right': 'Rechts abbiegen',
      'slight left': 'Leicht links halten',
      'slight right': 'Leicht rechts halten',
      'sharp left': 'Scharf links',
      'sharp right': 'Scharf rechts',
      'uturn': 'Wenden',
      'straight': 'Geradeaus',
    };
    final dir = map[type] ?? 'Weiterfahren';
    return name.isNotEmpty ? '$dir auf $name' : dir;
  }
}

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final String profile;

  RouteResult({required this.points, required this.distanceMeters, required this.durationSeconds, required this.steps, required this.profile});

  String get distanceText => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';

  String get durationText {
    final m = (durationSeconds / 60).ceil();
    return m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
  }

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList(),
    'distanceMeters': distanceMeters,
    'durationSeconds': durationSeconds,
    'steps': steps.map((s) => s.toJson()).toList(),
    'profile': profile,
  };
}

class RouteStep {
  final String instruction;
  final double distance;
  final double duration;
  final LatLng location;

  RouteStep({required this.instruction, required this.distance, required this.duration, required this.location});

  Map<String, dynamic> toJson() => {
    'instruction': instruction,
    'distance': distance,
    'duration': duration,
    'location': {'latitude': location.latitude, 'longitude': location.longitude},
  };
}
