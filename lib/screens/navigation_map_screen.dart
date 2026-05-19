import 'dart:math' show max, min;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme/app_colors.dart';
import '../services/navigation_service.dart';
import '../services/location_service.dart';

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

class _NavigationMapScreenState extends State<NavigationMapScreen> {
  final MapController _mapController = MapController();
  LatLng? _userLocation;
  int? _selectedStepIndex;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final loc = await LocationService().getLocation();
    if (loc != null && mounted) {
      setState(() => _userLocation = LatLng(loc.latitude, loc.longitude));
      _fitBounds();
    }
  }

  void _fitBounds() {
    final points = widget.routeResult?.points;
    if (points == null || points.isEmpty) return;
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
          LatLng(minLat - 0.002, minLng - 0.002),
          LatLng(maxLat + 0.002, maxLng + 0.002),
        ),
        padding: const EdgeInsets.all(60),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.routeResult;
    final points = route?.points;
    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.target ?? _userLocation ?? const LatLng(48.2082, 16.3738),
              initialZoom: 13,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom | InteractiveFlag.scrollWheelZoom,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.weltenwanderer.ai_buddy',
              ),
              if (points != null && points.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: points,
                      strokeWidth: 5,
                      color: AppColors.primary.withOpacity(0.85),
                      borderStrokeWidth: 7,
                      borderColor: AppColors.primary.withOpacity(0.2),
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 24, height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 8, spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),
                  if (widget.target != null)
                    Marker(
                      point: widget.target!,
                      width: 36, height: 36,
                      child: const Icon(Icons.location_pin, color: Color(0xFFFF9500), size: 36),
                    ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
                          SizedBox(width: 4),
                          Text('Zurück', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (route != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(route.distanceText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(route.durationText, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (route != null && route.steps.isNotEmpty)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: DraggableScrollableSheet(
                initialChildSize: 0.22, minChildSize: 0.12, maxChildSize: 0.55, snap: true,
                builder: (context, scrollController) => Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgCard.withOpacity(0.95),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16)],
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 6),
                        width: 40, height: 4,
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(Icons.navigation, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(widget.destinationName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
                            ),
                            Text('${route.steps.length} Schritte', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
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
                            final isSelected = _selectedStepIndex == i;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedStepIndex = i);
                                _mapController.move(step.location, 16);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: isSelected ? Border.all(color: AppColors.primary.withOpacity(0.3)) : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 28, height: 28,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.primary : AppColors.bgElevated,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text('${i + 1}', style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                                          fontWeight: FontWeight.bold, fontSize: 12,
                                        )),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(step.instruction, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                                          Text(step.distance >= 1000 ? '${(step.distance / 1000).toStringAsFixed(1)} km' : '${step.distance.round()} m', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3), size: 18),
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
