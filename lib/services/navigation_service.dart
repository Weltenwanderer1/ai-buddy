import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM + Valhalla Open-Source Navigation — Free, no API key.
/// Primary: router.project-osrm.org (OSRM)
/// Fallback 1: valhalla1.openstreetmap.de (Valhalla — different API format)
/// Geocoding via Nominatim.
class NavigationService {
  static const String kDefaultOsrm = 'router.project-osrm.org';
  static const String kValhallaBase = 'valhalla1.openstreetmap.de';

  final String _osrmBase;

  NavigationService({String? customOsrmBase})
      : _osrmBase = (customOsrmBase != null && customOsrmBase.isNotEmpty)
            ? customOsrmBase
            : kDefaultOsrm;

  // ── Geocode: Name → Koordinaten (Nominatim) ──

  Future<LatLng?> geocode(String query) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      'limit': '1',
      'accept-language': 'de',
    });
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'AI-Buddy-Navigator/0.99',
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
    } catch (e) {
      debugPrint('Geocoding error: $e');
      return null;
    }
    return null;
  }

  // ── Route mit Fallback-Kette ──

  Future<RouteResult?> getRoute(LatLng from, LatLng to,
      {String profile = 'walking'}) async {
    // 1. Try OSRM primary
    var result = await _tryOsrmRoute(from, to, _osrmBase, profile);
    if (result != null) return result;

    // 2. Try Valhalla (completely different server, different API)
    result = await _tryValhallaRoute(from, to, profile);
    if (result != null) return result;

    // 3. Try OSRM fallback server if different from primary
    if (_osrmBase != kDefaultOsrm) {
      result = await _tryOsrmRoute(from, to, kDefaultOsrm, profile);
    }
    return result;
  }

  // ── OSRM Route Request ──

  Future<RouteResult?> _tryOsrmRoute(
      LatLng from, LatLng to, String base, String profile) async {
    final osrmProfile = _mapOsrmProfile(profile);
    final uri = Uri.https(base, '/route/v1/$osrmProfile/'
        '${from.longitude},${from.latitude};'
        '${to.longitude},${to.latitude}',
        {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'});
    try {
      final res = await http.get(uri, headers: {
        'User-Agent': 'AI-Buddy-Navigator/0.99',
      }).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('OSRM $base returned ${res.statusCode}: ${res.body.substring(0, res.body.length > 200 ? 200 : res.body.length)}');
        return null;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['code'] != 'Ok') return null;

      final route = (body['routes'] as List).first as Map<String, dynamic>;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();
      final geometry = route['geometry'] as Map<String, dynamic>;
      final coords = (geometry['coordinates'] as List).map((c) {
        final list = c as List;
        return LatLng(
          (list[1] as num).toDouble(),
          (list[0] as num).toDouble(),
        );
      }).toList();
      final steps = ((route['legs'] as List).first['steps'] as List).map((s) {
        final step = s as Map<String, dynamic>;
        final m = step['maneuver'] as Map<String, dynamic>;
        final loc = m['location'] as List;
        return RouteStep(
          instruction: _readableInstruction(
              m['type'] as String, step['name'] as String? ?? ''),
          distance: (step['distance'] as num).toDouble(),
          duration: (step['duration'] as num).toDouble(),
          location: LatLng(
            (loc[1] as num).toDouble(),
            (loc[0] as num).toDouble(),
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
      debugPrint('OSRM route error ($base): $e');
      return null;
    }
  }

  // ── Valhalla Route Request ──

  Future<RouteResult?> _tryValhallaRoute(LatLng from, LatLng to, String profile) async {
    final valhallaProfile = profile == 'driving' ? 'auto' : (profile == 'cycling' ? 'bicycle' : 'pedestrian');
    final uri = Uri.https(kValhallaBase, '/route');
    final body = jsonEncode({
      'locations': [
        {'lat': from.latitude, 'lon': from.longitude},
        {'lat': to.latitude, 'lon': to.longitude},
      ],
      'costing': valhallaProfile,
      'directions_options': {'language': 'de-DE'},
    });
    try {
      final res = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'User-Agent': 'AI-Buddy-Navigator/0.99',
      }, body: body).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint('Valhalla returned ${res.statusCode}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final trip = data['trip'] as Map<String, dynamic>?;
      if (trip == null) return null;

      final legs = (trip['legs'] as List?) ?? [];
      if (legs.isEmpty) return null;

      final leg = legs.first as Map<String, dynamic>;
      final summary = (leg['summary'] as Map<String, dynamic>?) ?? {};
      final shape = leg['shape'] as String? ?? '';

      // Decode Valhalla polyline (encoded polyline format)
      final coords = _decodeValhallaPolyline(shape);
      if (coords.isEmpty) return null;

      final distance = (summary['length'] as num?)?.toDouble() ?? 0.0;
      final duration = (summary['time'] as num?)?.toDouble() ?? 0.0;

      // Parse maneuvers from Valhalla format
      final maneuvers = (leg['maneuvers'] as List?) ?? [];
      final steps = maneuvers.map((m) {
        final man = m as Map<String, dynamic>;
        final instruction = man['instruction'] as String? ?? 'Weiter';
        final beginShapeIndex = (man['begin_shape_index'] as num?)?.toInt() ?? 0;
        LatLng? loc;
        if (beginShapeIndex < coords.length) {
          loc = coords[beginShapeIndex];
        }
        return RouteStep(
          instruction: instruction,
          distance: (man['length'] as num?)?.toDouble() ?? 0.0,
          duration: (man['time'] as num?)?.toDouble() ?? 0.0,
          location: loc ?? LatLng(from.latitude, from.longitude),
        );
      }).toList();

      return RouteResult(
        points: coords,
        distanceMeters: distance * 1000, // Valhalla returns km
        durationSeconds: duration,
        steps: steps.isNotEmpty ? steps : [RouteStep(
          instruction: 'Route berechnet',
          distance: distance * 1000,
          duration: duration,
          location: from,
        )],
        profile: profile,
      );
    } catch (e) {
      debugPrint('Valhalla route error: $e');
      return null;
    }
  }

  /// Decode Valhalla polyline6 format.
  List<LatLng> _decodeValhallaPolyline(String encoded) {
    // Valhalla uses polyline6 encoding (6 decimal places)
    // Similar to Google's polyline but with 1e6 precision
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int? result;
      int shift = 0;
      int b;
      // Latitude
      do {
        if (index >= encoded.length) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result = (result ?? 0) | ((b & 0x1F) << shift);
        shift += 5;
      } while (b >= 0x20);
      lat += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      result = null;
      shift = 0;
      // Longitude
      do {
        if (index >= encoded.length) return points;
        b = encoded.codeUnitAt(index++) - 63;
        result = (result ?? 0) | ((b & 0x1F) << shift);
        shift += 5;
      } while (b >= 0x20);
      lng += ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));

      points.add(LatLng(lat / 1e6, lng / 1e6));
    }
    return points;
  }

  // ── Text-only Route (KI-Antwort ohne Map) ──

  Future<String> getNavigationText(String fromPlace, String toPlace,
      {String profile = 'walking'}) async {
    final from = await geocode(fromPlace);
    final to = await geocode(toPlace);
    if (from == null) return 'Ort "$fromPlace" nicht gefunden.';
    if (to == null) return 'Ort "$toPlace" nicht gefunden.';
    final route = await getRoute(from, to, profile: profile);
    if (route == null) return 'Route nicht berechenbar (Server nicht erreichbar).';
    final buf = StringBuffer();
    buf.writeln('Route → $toPlace:');
    buf.writeln('${route.distanceText} | ${route.durationText}');
    for (var i = 0; i < route.steps.length; i++) {
      buf.writeln('${i + 1}. ${route.steps[i].instruction}');
    }
    return buf.toString();
  }

  // ── Helpers ──

  String _mapOsrmProfile(String p) {
    switch (p) {
      case 'cycling': return 'bike';
      case 'driving': return 'car';
      default: return 'foot'; // walking = Wanderwege!
    }
  }

  String _readableInstruction(String type, String name) {
    final map = {
      'left': 'Links abbiegen',
      'right': 'Rechts abbiegen',
      'slight left': 'Leicht links halten',
      'slight right': 'Leicht rechts halten',
      'sharp left': 'Scharf links',
      'sharp right': 'Scharf rechts',
      'uturn': 'Wenden',
      'straight': 'Geradeaus',
      'depart': 'Starte',
      'arrive': 'Ankunft',
      'fork': 'Abzweigung',
      'merge': 'Einfädeln',
      'roundabout': 'Kreisverkehr',
      'end of road': 'Strassenende',
    };
    final dir = map[type] ?? 'Weiterfahren';
    return name.isNotEmpty ? '$dir auf $name' : dir;
  }

  static void debugPrint(String message) {
    if (kDebugMode) print('[NavigationService] $message');
  }
}

// ── Data Classes ──

class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;
  final String profile;

  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.profile,
  });

  String get distanceText => distanceMeters >= 1000
      ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
      : '${distanceMeters.round()} m';

  String get durationText {
    final m = (durationSeconds / 60).ceil();
    return m >= 60 ? '${m ~/ 60} h ${m % 60} min' : '$m min';
  }

  Map<String, dynamic> toJson() => {
        'points':
            points.map((p) => {'latitude': p.latitude, 'longitude': p.longitude}).toList(),
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

  RouteStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.location,
  });

  Map<String, dynamic> toJson() => {
        'instruction': instruction,
        'distance': distance,
        'duration': duration,
        'location':
            {'latitude': location.latitude, 'longitude': location.longitude},
      };
}