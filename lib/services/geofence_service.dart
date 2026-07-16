import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'location_service.dart';

/// A geofence definition: a named location with a radius.
class Geofence {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int radiusMeters;   // default 100
  final String message;     // notification text when entering
  final bool active;
  final DateTime createdAt;

  const Geofence({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.radiusMeters = 100,
    this.message = '',
    this.active = true,
    required this.createdAt,
  });

  Geofence copyWith({bool? active}) => Geofence(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    radiusMeters: radiusMeters,
    message: message,
    active: active ?? this.active,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'message': message,
    'active': active,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Geofence.fromJson(Map<String, dynamic> json) => Geofence(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    radiusMeters: (json['radiusMeters'] as num?)?.toInt() ?? 100,
    message: json['message'] as String? ?? '',
    active: json['active'] as bool? ?? true,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

/// Polling-based geofence service.
/// Checks proximity on each location update and fires callbacks.
class GeofenceService extends ChangeNotifier {
  static const String _storageKey = 'geofences';
  List<Geofence> _fences = [];
  Set<String> _enteredFences = {}; // IDs of fences the user is currently inside

  List<Geofence> get fences => List.unmodifiable(_fences);
  List<Geofence> get activeFences => _fences.where((f) => f.active).toList();

  /// Fires when a fence is entered (was outside, now inside).
  VoidCallback? onEnter;

  /// Fires when a fence is left.
  VoidCallback? onExit;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _fences = list.map((e) => Geofence.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_fences.map((e) => e.toJson()).toList()));
  }

  Future<void> addFence(Geofence fence) async {
    _fences.add(fence);
    await _save();
    notifyListeners();
  }

  Future<void> removeFence(String id) async {
    _fences.removeWhere((f) => f.id == id);
    _enteredFences.remove(id);
    await _save();
    notifyListeners();
  }

  Future<void> toggleActive(String id) async {
    final idx = _fences.indexWhere((f) => f.id == id);
    if (idx < 0) return;
    _fences[idx] = _fences[idx].copyWith(active: !_fences[idx].active);
    await _save();
    notifyListeners();
  }

  /// Check current position against all geofences.
  /// Call this when location changes.
  Future<void> checkProximity(LocationInfo loc) async {
    final lat = loc.latitude;
    final lon = loc.longitude;
    final newlyEntered = <String>{};

    for (final fence in _fences.where((f) => f.active)) {
      final dist = _haversine(lat, lon, fence.latitude, fence.longitude);
      if (dist <= fence.radiusMeters) {
        newlyEntered.add(fence.id);
      }
    }

    // Detect new entries
    for (final id in newlyEntered) {
      if (!_enteredFences.contains(id)) {
        debugPrint('Geofence: entered ${_fences.firstWhere((f) => f.id == id).name}');
        onEnter?.call();
      }
    }

    // Detect exits
    for (final id in _enteredFences) {
      if (!newlyEntered.contains(id)) {
        debugPrint('Geofence: left ${_fences.firstWhere((f) => f.id == id).name}');
        onExit?.call();
      }
    }

    _enteredFences = newlyEntered;
  }

  /// Haversine distance in meters between two lat/lon points.
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;
}
