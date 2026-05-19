import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/tile_download_service.dart';
import '../services/location_service.dart';

class OfflineMapDialog extends StatefulWidget {
  const OfflineMapDialog({super.key});

  @override
  State<OfflineMapDialog> createState() => _OfflineMapDialogState();
}

class _OfflineMapDialogState extends State<OfflineMapDialog> {
  bool _isDownloading = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _status = '';
  Map<String, dynamic>? _regionInfo;

  @override
  void initState() {
    super.initState();
    _loadRegionInfo();
  }

  Future<void> _loadRegionInfo() async {
    final info = await TileDownloadService.getRegionInfo();
    if (mounted) setState(() => _regionInfo = info);
  }

  Future<void> _download() async {
    setState(() {
      _isDownloading = true;
      _progressCurrent = 0;
      _progressTotal = 0;
      _status = 'Standort wird ermittelt...';
    });
    final loc = await LocationService().refreshLocation();
    if (loc == null) {
      setState(() {
        _isDownloading = false;
        _status = 'Standort nicht verfuegbar.';
      });
      return;
    }
    setState(() => _status = '${_progressCurrent}/${_progressTotal} Kacheln geladen...');
    final result = await TileDownloadService.downloadRegion(
      lat: loc.latitude,
      lon: loc.longitude,
      radiusDeg: 0.03,
      zoomMin: 13,
      zoomMax: 16,
      onProgress: (current, total) => setState(() {
        _progressCurrent = current;
        _progressTotal = total;
      }),
    );
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _status = result.success
            ? '${result.downloaded}/${result.total} Kacheln OK.'
            : 'Fehler: ${result.downloaded}/${result.total} geladen.';
      });
      _loadRegionInfo();
    }
  }

  Future<void> _clear() async {
    await TileDownloadService.clearTiles();
    setState(() {
      _regionInfo = null;
      _status = 'Offline-Karten geloescht.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.map, color: AppColors.primary),
              const SizedBox(width: 10),
              const Text('Offline-Karten',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 16),
            if (_regionInfo != null) ...[
              Text('Bereich: ${_regionInfo!["lat"]?.toStringAsFixed(3) ?? ""}, ${_regionInfo!["lon"]?.toStringAsFixed(3) ?? ""}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              Text('Zoom: ${_regionInfo!["zoomMin"]}-${_regionInfo!["zoomMax"]}, ${_regionInfo!["tileCount"] ?? 0} Kacheln',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              Text('Aktualisiert: ${_regionInfo!["updatedAt"]?.toString().substring(0, 10) ?? ""}',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 12),
            ],
            if (_isDownloading) ...[
              LinearProgressIndicator(
                value: _progressTotal > 0 ? _progressCurrent / _progressTotal : null,
                backgroundColor: AppColors.bgElevated,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                borderRadius: BorderRadius.circular(4),
              ),
              const SizedBox(height: 8),
              Text('$_progressCurrent / $_progressTotal',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              const SizedBox(height: 8),
            ],
            if (_status.isNotEmpty)
              Text(_status, style: TextStyle(
                color: _status.contains('Fehler') ? AppColors.error : AppColors.primary,
                fontSize: 13)),
            const SizedBox(height: 16),
            Row(children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isDownloading ? null : _download,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Laden'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgElevated,
                  foregroundColor: Colors.white.withOpacity(0.7),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isDownloading ? null : _clear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Loeschen'),
              ),
            ]),
            const SizedBox(height: 6),
            Text('~10–17 MB. Download: ~6 Min.',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
