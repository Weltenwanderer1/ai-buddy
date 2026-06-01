// App + System Status Checker
// Checks GitHub Releases for app updates and Android System Update API.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class UpdateService {
  static const String _githubOwner = 'Weltenwanderer1';
  static const String _githubRepo = 'ai-buddy';
  static const Duration _cacheTtl = Duration(minutes: 5);

  DateTime? _lastCheck;
  ({bool updateAvailable, String currentVersion, String? latestVersion, String? releaseUrl})? _cached;

  /// Check if a newer app release exists on GitHub.
  Future<({
    bool updateAvailable,
    String currentVersion,
    String? latestVersion,
    String? releaseUrl,
    String? releaseNotes,
  })> checkAppUpdate() async {
    // Return cached result if fresh
    if (_cached != null && _lastCheck != null && DateTime.now().difference(_lastCheck!) < _cacheTtl) {
      return (
        updateAvailable: _cached!.updateAvailable,
        currentVersion: _cached!.currentVersion,
        latestVersion: _cached!.latestVersion,
        releaseUrl: _cached!.releaseUrl,
        releaseNotes: null,
      );
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = 'v${packageInfo.version}';

    try {
      final uri = Uri.https(
        'api.github.com',
        '/repos/$_githubOwner/$_githubRepo/releases/latest',
      );
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'AI-Buddy-UpdateChecker',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        return (
          updateAvailable: false,
          currentVersion: currentVersion,
          latestVersion: null,
          releaseUrl: null,
          releaseNotes: 'GitHub API-Fehler: HTTP ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = data['tag_name'] as String?;
      final htmlUrl = data['html_url'] as String?;
      final body = data['body'] as String?;

      if (tagName == null || tagName.isEmpty) {
        return (
          updateAvailable: false,
          currentVersion: currentVersion,
          latestVersion: null,
          releaseUrl: null,
          releaseNotes: 'Keine Release-Version gefunden',
        );
      }

      final updateAvailable = _isNewer(tagName, currentVersion);
      _cached = (
        updateAvailable: updateAvailable,
        currentVersion: currentVersion,
        latestVersion: tagName,
        releaseUrl: htmlUrl,
      );
      _lastCheck = DateTime.now();

      return (
        updateAvailable: updateAvailable,
        currentVersion: currentVersion,
        latestVersion: tagName,
        releaseUrl: htmlUrl,
        releaseNotes: body,
      );
    } on SocketException {
      return (
        updateAvailable: false,
        currentVersion: currentVersion,
        latestVersion: null,
        releaseUrl: null,
        releaseNotes: 'Keine Internetverbindung',
      );
    } on TimeoutException {
      return (
        updateAvailable: false,
        currentVersion: currentVersion,
        latestVersion: null,
        releaseUrl: null,
        releaseNotes: 'Zeitueberschreitung beim Abruf',
      );
    } catch (e) {
      return (
        updateAvailable: false,
        currentVersion: currentVersion,
        latestVersion: null,
        releaseUrl: null,
        releaseNotes: 'Fehler: $e',
      );
    }
  }

  /// Get Android system info + security patch level.
  Future<Map<String, dynamic>> getSystemStatus() async {
    if (!Platform.isAndroid) {
      return {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
        'systemUpdateAvailable': null,
      };
    }

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;

    return {
      'platform': 'Android',
      'version': androidInfo.version.release,
      'sdkInt': androidInfo.version.sdkInt,
      'securityPatch': androidInfo.version.securityPatch,
      'brand': androidInfo.brand,
      'model': androidInfo.model,
      'isPhysicalDevice': androidInfo.isPhysicalDevice,
    };
  }

  /// Open the GitHub release page in browser.
  Future<void> openReleasePage(String? url) async {
    if (url == null || url.isEmpty) return;
    // Handled externally via url_launcher
  }

  // Semver-ish comparison: v1.2.3 vs v1.2.4
  bool _isNewer(String latest, String current) {
    final l = _parseVersion(latest);
    final c = _parseVersion(current);
    for (var i = 0; i < 3; i++) {
      final li = i < l.length ? l[i] : 0;
      final ci = i < c.length ? c[i] : 0;
      if (li > ci) return true;
      if (li < ci) return false;
    }
    return false; // equal
  }

  List<int> _parseVersion(String v) {
    final clean = v.toLowerCase().replaceFirst('v', '').split('+').first;
    return clean.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }
}
