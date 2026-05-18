import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Represents a resolved location with readable address components.
class LocationInfo {
  final double latitude;
  final double longitude;
  final String city;
  final String? district;
  final String? street;
  final String? countryCode;
  final String country;

  const LocationInfo({
    required this.latitude,
    required this.longitude,
    required this.city,
    this.district,
    this.street,
    this.countryCode,
    required this.country,
  });

  /// Format for system context: "Wien, 1180 Österreich (48.21, 16.35)"
  String toContextString() {
    final parts = <String>[city];
    if (district != null && district!.isNotEmpty) parts.add(district!);
    parts.add(country);
    return '${parts.join(', ')} (${latitude.toStringAsFixed(2)}, ${longitude.toStringAsFixed(2)})';
  }

  /// Short display: "Wien, 1180"
  String toShortString() {
    if (district != null && district!.isNotEmpty) return '$city, $district';
    return city;
  }

  @override
  String toString() =>
      'LocationInfo(city: $city, district: $district, country: $country, lat: $latitude, lng: $longitude)';
}

/// Service that determines the user's current location via GPS and
/// reverse-geocodes coordinates into readable addresses.
///
/// Caches the location for [cacheDuration] (default 5 minutes) to avoid
/// excessive GPS and API calls.
class LocationService extends ChangeNotifier {
  LocationInfo? _cachedLocation;
  DateTime? _cachedAt;

  /// Minimum time between location refreshes.
  static const _defaultCacheDuration = Duration(minutes: 5);
  final Duration cacheDuration;

  LocationService({this.cacheDuration = _defaultCacheDuration});

  /// Current location info (cached if fresh, otherwise re-fetched).
  LocationInfo? get currentLocation => _cachedLocation;

  /// Whether the cache is still valid.
  bool get _cacheIsValid {
    if (_cachedLocation == null || _cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < cacheDuration;
  }

  /// Get the current location. Uses cache if fresh, otherwise requests
  /// a new GPS position and reverse-geocodes it.
  ///
  /// Returns null if location is unavailable (no permission, GPS off, etc.).
  Future<LocationInfo?> getLocation() async {
    if (_cacheIsValid) return _cachedLocation;

    try {
      // Check & request permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: permission denied ($permission)');
        return _cachedLocation; // return stale cache or null
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );

      // Reverse geocode
      final info = await _reverseGeocode(position.latitude, position.longitude);
      if (info != null) {
        _cachedLocation = info;
        _cachedAt = DateTime.now();
        notifyListeners();
      }
      return _cachedLocation;
    } catch (e) {
      debugPrint('LocationService: error getting location: $e');
      // Fallback: try last known position
      if (_cachedLocation != null) return _cachedLocation;
      return _tryLastKnownPosition();
    }
  }

  /// Attempt to use the device's last known position as fallback.
  Future<LocationInfo?> _tryLastKnownPosition() async {
    try {
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        final info =
            await _reverseGeocode(lastPos.latitude, lastPos.longitude);
        if (info != null) {
          _cachedLocation = info;
          _cachedAt = DateTime.now().subtract(
              cacheDuration - const Duration(minutes: 1)); // almost expired
          notifyListeners();
          return info;
        }
      }
    } catch (e) {
      debugPrint('LocationService: last known position fallback failed: $e');
    }
    return null;
  }

  /// Reverse geocode using OpenStreetMap Nominatim (free, no API key).
  /// Rate-limited to 1 request/second per Nominatim policy.
  Future<LocationInfo?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': lat.toStringAsFixed(6),
        'lon': lng.toStringAsFixed(6),
        'format': 'json',
        'accept-language': 'de', // prefer German results
        'zoom': '16', // city/district level
      });

      final response = await http.get(uri, headers: {
        'User-Agent': 'AI-Buddy/0.74 (location-service)',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint(
            'LocationService: Nominatim returned HTTP ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      if (address == null) {
        debugPrint('LocationService: Nominatim returned no address');
        return null;
      }

      // Extract address components — Nominatim field names vary by region
      final city = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['municipality'] ??
          address['county'] ??
          '';
      final district = address['suburb'] ??
          address['city_district'] ??
          address['quarter'] ??
          address['neighbourhood'] ??
          address['borough'] ??
          '';
      final street = (address['road'] ?? address['pedestrian'] ?? '') +
          (address['house_number'] != null
              ? ' ${address['house_number']}'
              : '');
      final countryCode = address['country_code']?.toString().toUpperCase() ??
          address['country_code'] ??
          '';
      final country = address['country'] ?? '';

      return LocationInfo(
        latitude: lat,
        longitude: lng,
        city: city.toString(),
        district: district.toString().isEmpty ? null : district.toString(),
        street: street.toString().isEmpty ? null : street.toString(),
        countryCode: countryCode.toString().isEmpty
            ? null
            : countryCode.toString(),
        country: country.toString(),
      );
    } catch (e) {
      debugPrint('LocationService: reverse geocoding failed: $e');
      return null;
    }
  }

  /// Force a location refresh (ignores cache).
  Future<LocationInfo?> refreshLocation() async {
    _cachedAt = null; // invalidate cache
    return getLocation();
  }

  /// Build the context string for the system prompt.
  /// Returns something like: "Aktueller Standort: Wien, 1180 Österreich (48.21, 16.35)"
  /// Returns empty string if no location available.
  Future<String> buildContextString() async {
    final loc = await getLocation();
    if (loc == null) return '';
    return 'Aktueller Standort: ${loc.toContextString()}';
  }
}