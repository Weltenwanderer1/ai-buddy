import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min, sqrt, sin, cos, atan2;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../core/theme/buddy_colors.dart';
import '../core/theme/app_colors.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';
import '../services/tile_download_service.dart';
import '../services/tts_playback_service.dart';

/// Fullscreen pedestrian navigation with live tracking, follow-me, compass,
/// step-by-step guidance and auto re-routing.
class NavigationMapScreen extends StatefulWidget {
  final LatLng? target;
  final RouteResult? routeResult;
  final String destinationName;

  const NavigationMapScreen({
    super.key,
    this.target,
    this.routeResult,
    this.destinationName = 'Ziel',
  });

  @override
  State<NavigationMapScreen> createState() => _NavigationMapScreenState();
}

class _NavigationMapScreenState extends State<NavigationMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();

  // ── State ──
  LatLng? _userLocation;
  double? _heading;        // degrees from north (0-360)
  bool _followUser = true;  // auto-center on user
  bool _showSteps = false;
  int _currentStepIndex = 0;
  String? _offlineTilesDir;
  RouteResult? _route;

  // ── TTS Voice Guidance ──
  TtsPlaybackService? _ttsService;
  int _lastAnnouncedStepIndex = -1;
  bool _announcedNow = false;
  bool _announcedArrived = false;

  // ── Live GPS ──
  StreamSubscription<Position>? _positionStream;
  DateTime? _lastReroute;
  static const _rerouteThresholdMeters = 30.0;
  static const _rerouteCooldown = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _route = widget.routeResult;
    _init();
  }

  Future<void> _init() async {
    // Initial location
    try {
      final loc = await LocationService().getLocation();
      if (mounted && loc != null) {
        setState(() => _userLocation = LatLng(loc.latitude, loc.longitude));
      }
    } catch (_) {}

    // Offline tiles
    try {
      final tilesDir = await TileDownloadService.getTilesDir();
      if (mounted) setState(() => _offlineTilesDir = tilesDir);
    } catch (_) {}

    // Start live GPS tracking
    _startLocationTracking();

    // Fit bounds and initialize TTS after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fitBounds();
        try {
          _ttsService = Provider.of<TtsPlaybackService>(context, listen: false);
          _announceStart();
        } catch (_) {}
      }
    });
  }

  void _startLocationTracking() async {
    // Check permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // update every 5m
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position position) {
    if (!mounted) return;
    final newLoc = LatLng(position.latitude, position.longitude);
    final newHeading = position.heading.isFinite && position.heading > 0
        ? position.heading
        : _heading;

    setState(() {
      _userLocation = newLoc;
      _heading = newHeading;
    });

    // Follow user
    if (_followUser) {
      _mapController.move(newLoc, _mapController.camera.zoom);
    }

    // Update current step index based on proximity
    _updateCurrentStep(newLoc);

    // Speak voice prompts
    _speakGuidance();

    // Auto re-route if too far off
    _checkReroute(newLoc);
  }

  void _updateCurrentStep(LatLng userLoc) {
    if (_route == null || _route!.steps.isEmpty) return;
    final steps = _route!.steps;

    // Find closest upcoming step
    int closest = _currentStepIndex;
    double minDist = double.infinity;
    for (int i = _currentStepIndex; i < steps.length; i++) {
      final d = _distanceMeters(userLoc, steps[i].location);
      if (d < minDist) {
        minDist = d;
        closest = i;
      }
    }
    // Only advance, never go back
    if (closest > _currentStepIndex || (_currentStepIndex == 0 && minDist < 20)) {
      setState(() => _currentStepIndex = closest);
    }
  }

  void _checkReroute(LatLng userLoc) async {
    if (_route == null || widget.target == null) return;
    if (_lastReroute != null &&
        DateTime.now().difference(_lastReroute!) < _rerouteCooldown) {
      return;
    }

    // Check if user is far from the route polyline
    final dist = _distanceToPolyline(userLoc, _route!.points);
    if (dist > _rerouteThresholdMeters) {
      _lastReroute = DateTime.now();
      debugPrint('Navigation: re-routing (off by ${dist.round()}m)');

      final newRoute = await NavigationService().getRoute(
        userLoc, widget.target!, profile: 'walking',
      );
      if (newRoute != null && mounted) {
        setState(() {
          _route = newRoute;
          _currentStepIndex = 0;
        });
      }
    }
  }

  void _fitBounds() {
    final points = _route?.points;
    if (points == null || points.isEmpty) {
      // No route: center on user or target
      final center = _userLocation ?? widget.target ?? const LatLng(48.2082, 16.3738);
      _mapController.move(center, 15);
      return;
    }
    final all = [if (_userLocation != null) _userLocation!, ...points];
    var minLat = all.first.latitude; var maxLat = all.first.latitude;
    var minLng = all.first.longitude; var maxLng = all.first.longitude;
    for (final p in all) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.003, minLng - 0.003),
          LatLng(maxLat + 0.003, maxLng + 0.003),
        ),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  // ── Distance helpers ──

  static double _distanceMeters(LatLng a, LatLng b) {
    const R = 6371000.0;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final s = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) * cos(b.latitude * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(s), sqrt(1 - s));
  }

  /// Minimum distance from point to polyline (approximate per-segment check).
  static double _distanceToPolyline(LatLng point, List<LatLng> poly) {
    double minDist = double.infinity;
    for (int i = 0; i < poly.length - 1; i++) {
      final d = _distanceToSegment(point, poly[i], poly[i + 1]);
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  static double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    // Simplified: point-to-point distance to closest endpoint or projection
    final ap = _distanceMeters(p, a);
    final bp = _distanceMeters(p, b);
    if (ap < 1 || bp < 1) return min(ap, bp);
    // Midpoint approximation
    final mid = LatLng((a.latitude + b.latitude) / 2, (a.longitude + b.longitude) / 2);
    final mp = _distanceMeters(p, mid);
    return min(ap, min(bp, mp));
  }

  void _announceStart() {
    final route = _route;
    if (_ttsService == null || route == null) return;
    _ttsService!.speak(
      'Navigation gestartet nach ${widget.destinationName}. Distanz ${route.distanceText}.'
    );
  }

  void _speakGuidance() {
    final tts = _ttsService;
    final route = _route;
    final userLoc = _userLocation;
    if (tts == null || route == null || userLoc == null) return;

    final steps = route.steps;
    if (steps.isEmpty) return;

    // Check arrival first
    final target = widget.target;
    if (target != null && !_announcedArrived) {
      final distToTarget = _distanceMeters(userLoc, target);
      if (distToTarget < 15.0) {
        _announcedArrived = true;
        tts.speak('Sie haben Ihr Ziel ${widget.destinationName} erreicht.');
        return;
      }
    }

    // Step guidance
    if (_currentStepIndex < steps.length) {
      if (_lastAnnouncedStepIndex != _currentStepIndex) {
        _lastAnnouncedStepIndex = _currentStepIndex;
        _announcedNow = false;
        
        final currentStep = steps[_currentStepIndex];
        if (_currentStepIndex == steps.length - 1) {
          tts.speak('Dem Weg folgen für ${currentStep.distance.round()} Meter bis zum Ziel.');
        } else {
          tts.speak('Dem Weg folgen für ${currentStep.distance.round()} Meter, dann ${currentStep.instruction}.');
        }
      } else {
        if (_currentStepIndex + 1 < steps.length && !_announcedNow) {
          final nextStep = steps[_currentStepIndex + 1];
          final distToNext = _distanceMeters(userLoc, nextStep.location);
          if (distToNext < 25.0) {
            _announcedNow = true;
            tts.speak('Jetzt: ${nextStep.instruction}.');
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _ttsService?.stop();
    super.dispose();
  }

  // ── Next step info ──

  RouteStep? get _nextStep {
    if (_route == null || _currentStepIndex >= _route!.steps.length) return null;
    return _route!.steps[_currentStepIndex];
  }

  String get _nextStepDistance {
    final ns = _nextStep;
    if (ns == null || _userLocation == null) return '';
    final d = _distanceMeters(_userLocation!, ns.location);
    return d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
  }

  double get _routeProgress {
    if (_route == null || _route!.steps.isEmpty) return 0;
    return _currentStepIndex / _route!.steps.length;
  }

  // ── Build ──

  void _confirmEndNavigation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.buddy.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Navigation beenden?', style: TextStyle(color: context.buddy.t1)),
        content: Text(
          'Die Navigation wird beendet und du kehrst zur Kartenansicht zurück.',
          style: TextStyle(color: context.buddy.t2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Abbrechen', style: TextStyle(color: context.buddy.t3)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Beenden', style: TextStyle(color: context.buddy.error, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = _route;
    final points = route?.points;
    final hasOffline = _offlineTilesDir != null;
    final nextStep = _nextStep;

    return Scaffold(
      backgroundColor: context.buddy.bg,
      body: Stack(
        children: [
          // ── Map ──
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _userLocation ?? widget.target ?? const LatLng(48.2082, 16.3738),
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.scrollWheelZoom,
              ),
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
            ),
            children: [
              // Hybrid Offline/Online Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.weltenwanderer.ai_buddy',
                tileProvider: hasOffline
                    ? _HybridTileProvider(offlineDir: _offlineTilesDir!)
                    : NetworkTileProvider(),
              ),
              // Route polyline
              if (points != null && points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 5,
                      color: context.buddy.accent.withValues(alpha: 0.85),
                      borderStrokeWidth: 7,
                      borderColor: context.buddy.accent.withValues(alpha: 0.2),
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: [
                  // User position (animated blue dot)
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 28, height: 28,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF4FC3F7),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: _heading != null && _heading! > 0
                            ? Transform.rotate(
                                angle: (_heading! * pi / 180),
                                child: const Icon(Icons.navigation,
                                    color: Colors.white, size: 14),
                              )
                            : null,
                      ),
                    ),
                  // Target pin
                  if (widget.target != null)
                    Marker(
                      point: widget.target!,
                      width: 36, height: 36,
                      child: const Icon(Icons.location_pin,
                          color: Color(0xFFFF9500), size: 36),
                    ),
                ],
              ),
            ],
          ),

          // ── Top Bar ──
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // ── Beenden / Zurück ──
                  GestureDetector(
                    onTap: () => _confirmEndNavigation(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.buddy.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.buddy.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, color: context.buddy.error, size: 16),
                          const SizedBox(width: 4),
                          Text('Beenden', style: TextStyle(color: context.buddy.error, fontWeight: FontWeight.w600, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Route info
                  if (route != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.buddy.card.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(route.distanceText,
                              style: TextStyle(color: context.buddy.t1,
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          Text(route.durationText,
                              style: TextStyle(color: context.buddy.t2, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Steps toggle
                    GestureDetector(
                      onTap: () => setState(() => _showSteps = !_showSteps),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _showSteps
                              ? context.buddy.accent.withValues(alpha: 0.4)
                              : context.buddy.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.format_list_bulleted, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text('${route.steps.length}',
                                style: const TextStyle(color: Colors.white,
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  // Offline badge
                  if (hasOffline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.buddy.success.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.wifi_off, color: context.buddy.success, size: 14),
                          SizedBox(width: 4),
                          Text('Offline',
                              style: TextStyle(color: context.buddy.success, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Follow-me FAB (shown when user moved map) ──
          if (!_followUser)
            Positioned(
              right: 16, bottom: _showSteps ? 260 : 160,
              child: FloatingActionButton(
                mini: true,
                backgroundColor: context.buddy.accent,
                onPressed: () {
                  setState(() => _followUser = true);
                  if (_userLocation != null) {
                    _mapController.move(_userLocation!, 16);
                  }
                },
                child: Icon(
                  Icons.my_location,
                  color: AppColors.foregroundFor(context.buddy.accent),
                ),
              ),
            ),

          // ── Bottom Navigation Bar ──
          if (route != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: _NavigationBottomBar(
                route: route,
                nextStep: nextStep,
                nextStepDistance: _nextStepDistance,
                progress: _routeProgress,
                currentStepIndex: _currentStepIndex,
                destinationName: widget.destinationName,
              ),
            ),

          // ── Steps Sheet ──
          if (route != null && _showSteps && route.steps.isNotEmpty)
            Positioned(
              bottom: 80, left: 0, right: 0,
              child: DraggableScrollableSheet(
                initialChildSize: 0.35, minChildSize: 0.15, maxChildSize: 0.6,
                snap: true,
                builder: (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: context.buddy.card.withValues(alpha: 0.97),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 16)
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                            color: context.buddy.chipBorder,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(Icons.navigation, color: context.buddy.accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(widget.destinationName,
                                  style: TextStyle(color: context.buddy.t1,
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text('${route.steps.length} Schritte',
                                style: TextStyle(color: context.buddy.t2, fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: route.steps.length,
                          itemBuilder: (_, i) {
                            final step = route.steps[i];
                            final isCurrent = i == _currentStepIndex;
                            final isPast = i < _currentStepIndex;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _currentStepIndex = i);
                                _mapController.move(step.location, 17);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isCurrent
                                      ? context.buddy.accent.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isCurrent
                                      ? Border.all(color: context.buddy.accent.withValues(alpha: 0.4))
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28, height: 28,
                                      decoration: BoxDecoration(
                                        color: isCurrent
                                            ? context.buddy.accent
                                            : isPast
                                                ? context.buddy.success.withValues(alpha: 0.3)
                                                : context.buddy.elev,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: isPast
                                            ? Icon(Icons.check, color: context.buddy.success, size: 16)
                                            : Text('${i + 1}',
                                                style: TextStyle(
                                                  color: isCurrent ? Colors.white : context.buddy.t2,
                                                  fontWeight: FontWeight.bold, fontSize: 12,
                                                )),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(step.instruction,
                                              style: TextStyle(
                                                color: isPast
                                                    ? context.buddy.t3
                                                    : context.buddy.t1,
                                                fontSize: 14,
                                                fontWeight: isCurrent
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              )),
                                          Text(
                                            step.distance >= 1000
                                                ? '${(step.distance / 1000).toStringAsFixed(1)} km'
                                                : '${step.distance.round()} m',
                                            style: TextStyle(
                                                color: context.buddy.t2, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom bar showing next step instruction + progress bar.
/// Designed for pedestrians: big readable text, progress visible.
class _NavigationBottomBar extends StatelessWidget {
  final RouteResult route;
  final RouteStep? nextStep;
  final String nextStepDistance;
  final double progress;
  final int currentStepIndex;
  final String destinationName;

  const _NavigationBottomBar({
    required this.route,
    required this.nextStep,
    required this.nextStepDistance,
    required this.progress,
    required this.currentStepIndex,
    required this.destinationName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.buddy.card.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20)
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: context.buddy.elev,
              valueColor: AlwaysStoppedAnimation(context.buddy.accent),
              minHeight: 3,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Row(
              children: [
                // Next step icon
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: context.buddy.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(nextStepDistance,
                        style: TextStyle(
                          color: context.buddy.accent, fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center),
                  ),
                ),
                const SizedBox(width: 14),
                // Instruction
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nextStep?.instruction ?? 'Ankunft',
                        style: TextStyle(
                          color: context.buddy.t1, fontSize: 16,
                          fontWeight: FontWeight.w600, height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$destinationName · ${route.distanceText}',
                        style: TextStyle(
                          color: context.buddy.t2, fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Step counter
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.buddy.elev,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${currentStepIndex + 1}/${route.steps.length}',
                    style: TextStyle(
                      color: context.buddy.t2,
                      fontSize: 12, fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom TileProvider that checks local offline directory first,
/// and falls back to network requests if the tile is not cached.
class _HybridTileProvider extends TileProvider {
  final String offlineDir;

  _HybridTileProvider({required this.offlineDir});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final localFile = File('$offlineDir/${coordinates.z}/${coordinates.x}/${coordinates.y}.png');
    if (localFile.existsSync()) {
      return FileImage(localFile);
    }
    
    final url = 'https://tile.openstreetmap.org/${coordinates.z}/${coordinates.x}/${coordinates.y}.png';
    return NetworkImage(url);
  }
}
