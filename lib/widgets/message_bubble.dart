import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/chat_message.dart';
import '../services/tts_playback_service.dart';
import '../core/theme/app_colors.dart';
import '../screens/navigation_map_screen.dart';
import '../services/navigation_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// Telegram-style Nachrichten-Bubbles.
/// - User: rechts, abgerundet, dezenter Blau-Gradient
/// - KI: links, abgerundet, dunkle Fläche
/// - Keine Avatars, keine Icons auf Bubbles
/// - Harte untere Kante bei KI (Telegram-Stil: nur eine Seite "schweift")
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Animation<double>? animation;
  final int? index;
  final ValueNotifier<double>? scrollOffsetNotifier;

  const MessageBubble({
    super.key,
    required this.message,
    this.animation,
    this.index,
    this.scrollOffsetNotifier,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = switch (message.type) {
      MessageType.text => message.isUser ? _userBubble(context) : _aiBubble(context),
      MessageType.system => _systemBubble(),
      MessageType.toolActivity => _toolActivity(context),
      MessageType.error => _errorBubble(context),
      MessageType.voice => message.isUser ? _userBubble(context) : _aiBubble(context),
      MessageType.navigation => _navigationBubble(context),
      MessageType.locationMap => _locationMapBubble(context),
    };

    if (animation != null) {
      content = SlideTransition(
        position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(parent: animation!, curve: Curves.easeOutCubic),
        ),
        child: FadeTransition(
          opacity: animation!,
          child: content,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: content,
    );
  }

  void _showCopyMenu(BuildContext context, Offset position) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _CopyMenuOverlay(
        position: position,
        onCopySelection: () {
          entry.remove();
          Clipboard.setData(ClipboardData(text: message.text));
          HapticFeedback.mediumImpact();
          _showCopiedSnackBar(context);
        },
        onDismiss: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
  }

  void _showCopiedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Kopiert', style: TextStyle(fontSize: 13)),
      duration: const Duration(seconds: 1),
      backgroundColor: AppColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── User Bubble (rechts, screen-space Farbverlauf Orange→Lila→Blau) ──
  static const _palette = [
    Color(0xFFFF8C42), // warmes Orange
    Color(0xFFE76F51), // Koralle
    Color(0xFFF4A261), // sandiges Orange
    Color(0xFFE0B1CB), // Pastell-Rosa
    Color(0xFFA56CC1), // Lila
    Color(0xFF7B68D4), // blau-violett
    Color(0xFF6B8DD6), // Periwinkle Blau
    Color(0xFFFF8C42), // wieder Orange (seamless)
  ];

  Widget _userBubble(BuildContext context) {
    if (scrollOffsetNotifier != null && index != null) {
      return ValueListenableBuilder<double>(
        valueListenable: scrollOffsetNotifier!,
        builder: (context, offset, child) {
          final gradient = _screenSpaceGradient(offset, index!);
          return _userBubbleWithGradient(context, gradient);
        },
      );
    }
    return _userBubbleWithGradient(context, AppColors.userBubble);
  }

  /// Screen-space Palette: Oben Orange → unten Lila/Blau.
  /// 1 Durchlauf pro Bildschirmhöhe: idx*0.5 = 14 Bubbles = 7 Schritte, scroll*0.009 ≈ 1 Palette/800px.
  LinearGradient _screenSpaceGradient(double scrollOffset, int idx) {
    // Virtuelle Position auf der Palette (float = erlaubt Zwischenfarben)
    final pos = (idx * 0.5 + scrollOffset * 0.009) % (_palette.length - 1);
    final p0 = pos.floor();
    final p1 = p0 + 1;
    final t = pos - p0; // 0.0 .. 1.0 zwischen zwei Palettenfarben

    final c0 = _palette[p0];
    final c1 = _palette[p1];
    final c2 = _palette[(p1 + 1) % _palette.length];

    // Top = etwas wärmer, Bottom = etwas kühler (Mini-Slice-Verlauf)
    final top    = _lerpColor(c0, c1, t);
    final bottom = _lerpColor(c1, c2, t);

    return LinearGradient(
      begin: Alignment.topLeft,
      end:   Alignment.bottomRight,
      colors: [top, bottom],
    );
  }

  Color _lerpColor(Color a, Color b, double t) {
    final tt = t.clamp(0.0, 1.0);
    return Color.fromARGB(
      255,
      (a.r * 255 + (b.r * 255 - a.r * 255) * tt).round(),
      (a.g * 255 + (b.g * 255 - a.g * 255) * tt).round(),
      (a.b * 255 + (b.b * 255 - a.b * 255) * tt).round(),
    );
  }

  Widget _userBubbleWithGradient(BuildContext context, Gradient gradient) {
    return GestureDetector(
      onLongPressStart: (details) => _showCopyMenu(context, details.globalPosition),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 64),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: SelectableText(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Bubble (links, wie Telegram Fremdnachricht) ──
  Widget _aiBubble(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (details) => _showCopyMenu(context, details.globalPosition),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(right: 64),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                gradient: AppColors.assistantBubbleBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4), // Harte untere rechte Ecke
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    message.text,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _TtsPlayButton(message: message),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _systemBubble() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _toolActivity(BuildContext context) {
    final bool isComplete = message.text.contains('✅') || 
                           message.text.contains('gesetzt') || 
                           message.text.contains('erledigt') ||
                           !message.text.contains('wird ausgefuehrt');
    
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isComplete ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
              size: 14,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 8),
            Text(
              message.text,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _navigationBubble(BuildContext context) {
    final md = message.metadata;
    if (md == null) return _aiBubble(context);
    final routeData = md['route'];
    final targetData = md['target'];
    if (targetData == null) return _aiBubble(context);
    
    // Reconstruct route
    RouteResult? route;
    try {
      if (routeData != null) {
        final points = (routeData['points'] as List).map((p) {
          final pp = p as Map;
          return LatLng(pp['latitude'] as double, pp['longitude'] as double);
        }).toList();
        final steps = (routeData['steps'] as List).map((s) {
          final ss = s as Map;
          return RouteStep(
            instruction: ss['instruction'] as String,
            distance: (ss['distance'] as num).toDouble(),
            duration: (ss['duration'] as num).toDouble(),
            location: LatLng(
              (ss['location'] as Map)['latitude'] as double,
              (ss['location'] as Map)['longitude'] as double,
            ),
          );
        }).toList();
        route = RouteResult(
          points: points,
          distanceMeters: routeData['distanceMeters'] as double,
          durationSeconds: routeData['durationSeconds'] as double,
          steps: steps,
          profile: routeData['profile'] as String,
        );
      }
    } catch (_) {
      route = null;
    }
    
    final target = LatLng(
      (targetData['lat'] as num).toDouble(),
      (targetData['lon'] as num).toDouble(),
    );
    final destinationName = md['destination_name'] as String? ?? 'Ziel';
    final modeIcon = route?.profile == 'cycling' ? '🚲' : '🚶';

    // ── Compact navigation card (tap → fullscreen map) ──
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NavigationMapScreen(
              target: target,
              routeResult: route,
              destinationName: destinationName,
            ),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bgCard.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Destination
              Row(
                children: [
                  const Icon(Icons.location_pin, color: Color(0xFFFF9500), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(destinationName,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Icon(Icons.map, color: AppColors.primary, size: 20),
                ],
              ),
              if (route != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(modeIcon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(route.distanceText,
                        style: const TextStyle(color: Colors.white,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 12),
                    Text(route.durationText,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14)),
                    const Spacer(),
                    Text('${route.steps.length} Schritte',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                // First 2 steps preview
                if (route.steps.length > 1) ...[
                  Text('→ ${route.steps[1].instruction}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
              if (route == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Auf Karte anzeigen',
                      style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Location Map Bubble (blauer Punkt, keine Route) ──
  Widget _locationMapBubble(BuildContext context) {
    final md = message.metadata;
    if (md == null) return _aiBubble(context);
    final lat = (md['lat'] as num?)?.toDouble();
    final lon = (md['lon'] as num?)?.toDouble();
    final label = md['label'] as String? ?? 'Standort';
    if (lat == null || lon == null) return _aiBubble(context);

    final center = LatLng(lat, lon);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => NavigationMapScreen(
              target: center,
              destinationName: label,
            ),
          ));
        },
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.weltenwanderer.ai_buddy',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 36, height: 36,
                        child: const Icon(Icons.my_location, color: Color(0xFF4FC3F7), size: 36),
                      ),
                    ],
                  ),
                ],
              ),
              // Fullscreen hint
              Positioned(
                top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, color: Colors.white70, size: 14),
                      SizedBox(width: 4),
                      Text('Karte', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ),
              // Label bar
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: const BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: Color(0xFF4FC3F7), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBubble(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: AppColors.error.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

// ── TTS Play Button (dezent, in der Bubble) ──
class _TtsPlayButton extends StatefulWidget {
  final ChatMessage message;
  const _TtsPlayButton({required this.message});

  @override
  State<_TtsPlayButton> createState() => _TtsPlayButtonState();
}

class _TtsPlayButtonState extends State<_TtsPlayButton> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (_isPlaying) return;
        setState(() => _isPlaying = true);
        final tts = context.read<TtsPlaybackService>();
        await tts.speak(widget.message.text);
        if (mounted) setState(() => _isPlaying = false);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
            size: 14,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: 4),
          Text(
            'Vorlesen',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Copy Menu Overlay ──
class _CopyMenuOverlay extends StatelessWidget {
  final Offset position;
  final VoidCallback onCopySelection;
  final VoidCallback onDismiss;

  const _CopyMenuOverlay({
    required this.position,
    required this.onCopySelection,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned(
              left: position.dx - 60,
              top: position.dy - 50,
              child: Material(
                color: AppColors.bgElevated,
                borderRadius: BorderRadius.circular(12),
                elevation: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MenuItem(
                        icon: Icons.copy,
                        label: 'Kopieren',
                        onTap: onCopySelection,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}
