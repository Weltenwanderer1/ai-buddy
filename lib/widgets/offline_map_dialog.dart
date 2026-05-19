import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/tile_download_service.dart';
import '../services/location_service.dart';

/// Vollständiger Offline-Karten-Dialog.
/// - Bereich per Slider wählbar (1km–10km Radius)
/// - Download mit Fortschritt + Abbrechbar
/// - Löschen bestätigt
/// - Info über gespeicherte Region
class OfflineMapDialog extends StatefulWidget {
  const OfflineMapDialog({super.key});

  @override
  State<OfflineMapDialog> createState() => _OfflineMapDialogState();
}

class _OfflineMapDialogState extends State<OfflineMapDialog> {
  bool _isDownloading = false;
  bool _isPaused = false;
  int _progressCurrent = 0;
  int _progressTotal = 0;
  String _status = '';
  String _error = '';
  double _radiusDeg = 0.035; // default ~3-4 km
  int _zoomMin = 13;
  int _zoomMax = 16;
  Map<String, dynamic>? _regionInfo;
  bool _isCheckingLocation = false;

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
      _isPaused = false;
      _progressCurrent = 0;
      _progressTotal = 0;
      _status = 'Standort wird ermittelt...';
      _error = '';
      _isCheckingLocation = true;
    });

    final loc = await LocationService().refreshLocation();
    if (loc == null) {
      setState(() {
        _isDownloading = false;
        _isCheckingLocation = false;
        _error = 'Standort nicht verfügbar. Bitte GPS aktivieren.';
      });
      return;
    }

    setState(() {
      _isCheckingLocation = false;
      _status = 'Kacheln werden geladen...';
    });

    final result = await TileDownloadService.downloadRegion(
      lat: loc.latitude,
      lon: loc.longitude,
      radiusDeg: _radiusDeg,
      zoomMin: _zoomMin,
      zoomMax: _zoomMax,
      onProgress: (current, total) {
        if (mounted && !_isPaused) {
          setState(() {
            _progressCurrent = current;
            _progressTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        if (result.success) {
          _status = '${result.downloaded}/${result.total} Kacheln geladen.';
          _error = '';
        } else {
          _error = 'Nur ${result.downloaded}/${result.total} geladen.';
          _status = '';
        }
      });
      _loadRegionInfo();
    }
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _status = _isPaused ? 'Pausiert (${_progressCurrent}/${_progressTotal})' : 'Kacheln werden geladen...';
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Löschen?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${_regionInfo?['tileCount'] ?? 'Alle'} Kacheln unwiderruflich löschen?',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Abbrechen', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Löschen', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TileDownloadService.clearTiles();
    setState(() {
      _regionInfo = null;
      _status = 'Offline-Karten gelöscht.';
      _error = '';
    });
  }

  String _radiusLabel(double deg) {
    // Approximately: 1 degree ≈ 111 km
    final km = deg * 111;
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = _regionInfo != null && (_regionInfo!['downloaded'] as int?) != null && (_regionInfo!['downloaded'] as int) > 0;
    final tileCount = _regionInfo?['tileCount'] as int? ?? '?' as dynamic;
    final downloaded = _regionInfo?['downloaded'] as int? ?? 0;
    final updated = _regionInfo?['updatedAt'] as String? ?? '';

    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(children: [
              Icon(Icons.map_rounded, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              const Text('Offline-Karten',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ]),
            const SizedBox(height: 8),
            Text(
              'OpenStreetMap-Kacheln für Navigation ohne Internet.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
            ),
            const SizedBox(height: 20),

            // ── Bestehende Region ──
            if (hasExisting) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.success.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.check_circle, color: AppColors.success, size: 18),
                      const SizedBox(width: 8),
                      const Text('Offline-Karten sind geladen',
                        style: TextStyle(color: Color(0xFF34C759), fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                    const SizedBox(height: 6),
                    if (_regionInfo?['lat'] != null && _regionInfo?['lon'] != null)
                      Text(
                        'Bereich: ${(_regionInfo!['lat'] as num).toStringAsFixed(3)}, ${(_regionInfo!['lon'] as num).toStringAsFixed(3)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      ),
                    Text(
                      '$downloaded/$tileCount Kacheln · Zoom ${_regionInfo?['zoomMin'] ?? 13}–${_regionInfo?['zoomMax'] ?? 16}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                    if (updated.isNotEmpty)
                      Text(
                        'Aktualisiert: ${updated.length >= 10 ? updated.substring(0, 10) : updated}',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // ── Download-Loading ──
            if (_isDownloading || _isPaused) ...[
              LinearProgressIndicator(
                value: _progressTotal > 0 ? _progressCurrent / _progressTotal : null,
                backgroundColor: AppColors.bgElevated,
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 8),
              Text('$_progressCurrent / $_progressTotal Kacheln',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
              if (_isPaused)
                Text('⏸️ Pausiert', style: TextStyle(color: AppColors.warning, fontSize: 13)),
              const SizedBox(height: 12),
            ],

            // ── Status / Error ──
            if (_status.isNotEmpty && !_isDownloading)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_status, style: TextStyle(color: AppColors.success, fontSize: 13)),
              ),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error, style: TextStyle(color: AppColors.error, fontSize: 13)),
              ),

            // ── Bereichsauswahl (nur wenn nicht am Downloaden) ──
            if (!_isDownloading) ...[
              const SizedBox(height: 4),
              Text('Bereich: ${_radiusLabel(_radiusDeg)}', 
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
              Slider(
                value: _radiusDeg,
                min: 0.01,
                max: 0.1,
                divisions: 9,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.bgElevated,
                label: _radiusLabel(_radiusDeg),
                onChanged: (v) => setState(() => _radiusDeg = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text('Zoom: $_zoomMin–$_zoomMax',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ca. ${((_radiusDeg * 111 * 111 * 3).toStringAsFixed(0))} Kacheln · ~${((_radiusDeg * 111 * 0.25).toStringAsFixed(0))} Min.',
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
              ),
            ],

            const SizedBox(height: 16),

            // ── Buttons ──
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                // Download / Aktualisieren
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: (_isDownloading && !_isPaused) ? null : _download,
                  icon: Icon(_isDownloading ? Icons.refresh : Icons.download, size: 18),
                  label: Text(hasExisting ? 'Aktualisieren' : 'Laden'),
                ),
                // Pause / Fortsetzen
                if (_isDownloading)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning.withOpacity(0.2),
                      foregroundColor: AppColors.warning,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: _togglePause,
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause, size: 18),
                    label: Text(_isPaused ? 'Fortsetzen' : 'Pause'),
                  ),
                // Löschen
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.bgElevated,
                    foregroundColor: Colors.white.withOpacity(0.7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  onPressed: _isDownloading ? null : _clear,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Löschen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
