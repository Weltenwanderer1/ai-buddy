import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/buddy_colors.dart';
import '../services/geofence_service.dart';
import '../services/location_service.dart';

/// Manage geofenced places for location-based reminders.
class GeofenceScreen extends StatefulWidget {
  const GeofenceScreen({super.key});

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  final _nameCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _selectedLocation = '';
  double _selectedLat = 0;
  double _selectedLon = 0;
  int _radius = 100;
  bool _showAddForm = false;
  bool _pickingLocation = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.buddy;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('📍 Orts-Erinnerungen'),
        backgroundColor: c.card,
        foregroundColor: c.t1,
        actions: [
          IconButton(
            icon: Icon(_showAddForm ? Icons.close : Icons.add_location_alt, color: c.accent),
            onPressed: () => setState(() => _showAddForm = !_showAddForm),
          ),
        ],
      ),
      body: Consumer2<GeofenceService, LocationService>(
        builder: (context, geo, loc, _) {
          final fences = geo.activeFences;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showAddForm) _buildAddForm(c, loc),

                // Active fences
                Text('📍 Aktive Orte', style: TextStyle(color: c.t2, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (fences.isEmpty)
                  _buildEmpty(c, 'Noch keine Orte hinterlegt. '
                      'Tippe auf + um einen Ort hinzuzufügen.')
                else
                  ...fences.map((f) => _buildFenceTile(c, f, geo)),

                // Inactive (need to compute outside the list literal)
                ...() {
                  final inactive = geo.fences.where((f) => !f.active).toList();
                  if (inactive.isEmpty) return <Widget>[];
                  return [
                    const SizedBox(height: 20),
                    Text('⏸️ Inaktiv', style: TextStyle(color: c.t3, fontSize: 13)),
                    ...inactive.map((f) => _buildFenceTile(c, f, geo)),
                  ];
                }(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddForm(c, LocationService loc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Neuen Ort hinzufügen', style: TextStyle(color: c.t1, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          TextField(
            controller: _nameCtrl,
            style: TextStyle(color: c.t1, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Name (z.B. "Supermarkt", "Apotheke")',
              hintStyle: TextStyle(color: c.t3, fontSize: 13),
              prefixIcon: Icon(Icons.place, size: 18, color: c.t3),
              filled: true,
              fillColor: c.elev,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickingLocation ? null : () => _pickLocation(loc),
            icon: Icon(_pickingLocation ? Icons.hourglass_top : Icons.my_location, size: 18),
            label: Text(
              _pickingLocation
                  ? 'Standort wird ermittelt...'
                  : _selectedLocation.isNotEmpty
                      ? _selectedLocation
                      : 'Aktuellen Standort verwenden',
              style: TextStyle(fontSize: 13, color: _selectedLocation.isNotEmpty ? c.accent : null),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: c.t1,
              side: BorderSide(color: c.border),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Radius:', style: TextStyle(color: c.t2, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Slider(
                  value: _radius.toDouble(),
                  min: 20,
                  max: 500,
                  divisions: 24,
                  label: '${_radius}m',
                  activeColor: c.accent,
                  onChanged: (v) => setState(() => _radius = v.round()),
                ),
              ),
              Text('${_radius}m', style: TextStyle(color: c.t1, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _messageCtrl,
            style: TextStyle(color: c.t1, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Benachrichtigung (z.B. "Hol Milch!")',
              hintStyle: TextStyle(color: c.t3, fontSize: 13),
              prefixIcon: Icon(Icons.notifications, size: 18, color: c.t3),
              filled: true,
              fillColor: c.elev,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _nameCtrl.text.trim().isEmpty || _selectedLat == 0
                  ? null
                  : _saveFence,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Speichern'),
              style: FilledButton.styleFrom(backgroundColor: c.accent),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLocation(LocationService loc) async {
    setState(() => _pickingLocation = true);
    try {
      final info = await loc.getLocation();
      if (info != null && mounted) {
        setState(() {
          _selectedLat = info.latitude;
          _selectedLon = info.longitude;
          _selectedLocation = info.toShortString();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _pickingLocation = false);
  }

  void _saveFence() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selectedLat == 0) return;

    final now = DateTime.now();
    final fence = Geofence(
      id: '${now.millisecondsSinceEpoch}_$name',
      name: name,
      latitude: _selectedLat,
      longitude: _selectedLon,
      radiusMeters: _radius,
      message: _messageCtrl.text.trim(),
      createdAt: now,
    );

    context.read<GeofenceService>().addFence(fence);

    _nameCtrl.clear();
    _messageCtrl.clear();
    _selectedLocation = '';
    _selectedLat = 0;
    _selectedLon = 0;
    _radius = 100;
    setState(() => _showAddForm = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('📍 "$name" wurde als Ort gespeichert'),
      backgroundColor: Colors.green.withValues(alpha: 0.8),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _buildFenceTile(c, Geofence fence, GeofenceService geo) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fence.active ? c.border : c.border.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            fence.active ? Icons.location_on : Icons.location_off,
            color: fence.active ? c.accent : c.t3,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fence.name, style: TextStyle(color: c.t1, fontSize: 14, fontWeight: FontWeight.w500)),
                Text(
                  '📍 ${fence.latitude.toStringAsFixed(4)}, ${fence.longitude.toStringAsFixed(4)} • ${fence.radiusMeters}m',
                  style: TextStyle(color: c.t3, fontSize: 12),
                ),
                if (fence.message.isNotEmpty)
                  Text(fence.message, style: TextStyle(color: c.t2, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(fence.active ? Icons.toggle_on : Icons.toggle_off_outlined,
                color: fence.active ? Colors.green : c.t3, size: 28),
            onPressed: () => geo.toggleActive(fence.id),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: c.error, size: 20),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Ort entfernen?'),
                  content: Text('"${fence.name}" wirklich löschen?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Abbrechen')),
                    TextButton(onPressed: () {
                      geo.removeFence(fence.id);
                      Navigator.pop(ctx);
                    }, child: const Text('Löschen', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(c, String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      child: Center(
        child: Text(text, style: TextStyle(color: c.t3, fontSize: 14)),
      ),
    );
  }
}
