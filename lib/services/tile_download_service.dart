import 'dart:convert';
import 'dart:io';
import 'dart:math' show pow, pi, log, tan, cos;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Downloads OSM tiles for a region for offline use. Respects OSM ToS (~1 req/s).
class TileDownloadService {
  static const String _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Download tiles around latitude/longitude.
  /// [radiusDeg]: radius in degrees (0.03 ≈ 3-4 km). [zoomMin/Max]: zoom levels.
  static Future<DownloadResult> downloadRegion({
    required double lat,
    required double lon,
    double radiusDeg = 0.03,
    int zoomMin = 13,
    int zoomMax = 16,
    Function(int current, int total)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${dir.path}/offline_tiles');
    await tilesDir.create(recursive: true);

    // Collect all tile coordinates
    final tiles = <_Tile>[];
    for (int z = zoomMin; z <= zoomMax; z++) {
      final centerX = _lon2x(lon, z);
      final centerY = _lat2y(lat, z);
      final r = _degToTileRadius(radiusDeg, z);
      final xMin = (centerX - r).floor();
      final xMax = (centerX + r).ceil();
      final yMin = (centerY - r).floor();
      final yMax = (centerY + r).ceil();
      for (int x = xMin; x <= xMax; x++) {
        for (int y = yMin; y <= yMax; y++) {
          if (x >= 0 && y >= 0 && x < pow(2, z) && y < pow(2, z)) {
            tiles.add(_Tile(x: x, y: y, z: z));
          }
        }
      }
    }

    // Remove duplicates
    final seen = <String>{};
    final unique = tiles.where((t) => seen.add(t.key)).toList();

    int downloaded = 0;
    int failed = 0;
    final total = unique.length;
    
    for (final tile in unique) {
      final path = '${tilesDir.path}/${tile.z}/${tile.x}/${tile.y}.png';
      final file = File(path);
      if (await file.exists()) {
        downloaded++;
        onProgress?.call(downloaded + failed, total);
        continue; // already cached
      }
      
      await file.parent.create(recursive: true);
      final url = _tileUrl
          .replaceFirst('{z}', '${tile.z}')
          .replaceFirst('{x}', '${tile.x}')
          .replaceFirst('{y}', '${tile.y}');
      
      try {
        final res = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'AI-Buddy-OfflineTiles/0.78'},
        ).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          await file.writeAsBytes(res.bodyBytes);
          downloaded++;
        } else {
          failed++;
        }
      } catch (_) {
        failed++;
      }
      
      onProgress?.call(downloaded + failed, total);
      // Respect OSM ToS: ~1 req/s
      await Future.delayed(const Duration(milliseconds: 1100));
    }

    // Save metadata
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offline_tile_region', jsonEncode({
      'lat': lat,
      'lon': lon,
      'radiusDeg': radiusDeg,
      'zoomMin': zoomMin,
      'zoomMax': zoomMax,
      'tileCount': total,
      'downloaded': downloaded,
      'failed': failed,
      'updatedAt': DateTime.now().toIso8601String(),
    }));

    return DownloadResult(total: total, downloaded: downloaded, failed: failed);
  }

  /// Get the offline tiles directory path.
  static Future<String?> getTilesDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${dir.path}/offline_tiles');
    if (await tilesDir.exists()) {
      return tilesDir.path;
    }
    return null;
  }

  /// Check if offline tiles exist.
  static Future<bool> hasOfflineTiles() async {
    return await getTilesDir() != null;
  }

  /// Get saved region info.
  static Future<Map<String, dynamic>?> getRegionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('offline_tile_region');
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Clear all offline tiles.
  static Future<void> clearTiles() async {
    final dir = await getApplicationDocumentsDirectory();
    final tilesDir = Directory('${dir.path}/offline_tiles');
    if (await tilesDir.exists()) {
      await tilesDir.delete(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offline_tile_region');
  }

  // Tile math helpers
  static int _lon2x(double lon, int z) => ((lon + 180.0) / 360.0 * (1 << z)).floor();
  static int _lat2y(double lat, int z) {
    final latRad = lat * pi / 180;
    return ((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / pi) / 2.0 * (1 << z)).floor();
  }

  static double _degToTileRadius(double deg, int z) {
    // Approx: 1 degree ≈ 111km at equator. At zoom z, 1 tile ≈ 40075km / 2^z.
    // So deg ≈ (40075/2^z) * tile_count / 111
    // Simplified: radius in tiles ≈ deg * (1<<z) / 360 * cos(lat)
    return deg * (1 << z) / 360.0;
  }
}

class _Tile {
  final int x, y, z;
  _Tile({required this.x, required this.y, required this.z});
  String get key => '$z/$x/$y';
}

class DownloadResult {
  final int total;
  final int downloaded;
  final int failed;
  DownloadResult({required this.total, required this.downloaded, required this.failed});
  bool get success => downloaded > total * 0.8; // 80% threshold
}
