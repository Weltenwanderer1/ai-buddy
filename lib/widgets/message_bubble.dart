import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/chat_message.dart';
import '../services/tts_playback_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/buddy_colors.dart';
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
  final bool isSelected;
  final VoidCallback? onToggleSelection;

  const MessageBubble({
    super.key,
    required this.message,
    this.animation,
    this.isSelected = false,
    this.onToggleSelection,
  });

  @override
  Widget build(BuildContext context) {
    // Detect navigation/location metadata on text messages from AI
    Widget content;
    if (message.type == MessageType.text && !message.isUser) {
      final md = message.metadata;
      if (md != null && md['show_map'] == true) {
        content = _navigationBubble(context);
      } else if (md != null && md['lat'] != null && md['lon'] != null) {
        content = _locationMapBubble(context);
      } else {
        content = _aiBubble(context);
      }
    } else {
      content = switch (message.type) {
        MessageType.text => message.isUser ? _userBubble(context) : _aiBubble(context),
        MessageType.system => _systemBubble(context),
        MessageType.toolActivity => _toolActivity(context),
        MessageType.error => _errorBubble(context),
        MessageType.voice => message.isUser ? _userBubble(context) : _aiBubble(context),
        MessageType.navigation => _navigationBubble(context),
        MessageType.locationMap => _locationMapBubble(context),
      };
    }

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
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: content,
    );
  }

  void _showCopiedSnackBar(BuildContext context, String text) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text, style: TextStyle(fontSize: 13)),
      duration: const Duration(seconds: 1),
      backgroundColor: context.buddy.elev,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _userBubble(BuildContext context) {
    final isMultiSelect = onToggleSelection != null;
    final imagePath = message.metadata?['image_path'] as String?;
    return GestureDetector(
      onLongPress: isMultiSelect
        ? () {
            onToggleSelection!();
            HapticFeedback.mediumImpact();
          }
        : () {
            Clipboard.setData(ClipboardData(text: message.text));
            HapticFeedback.mediumImpact();
            _showCopiedSnackBar(context, 'Nachricht kopiert');
          },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isSelected) ...[
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(left: 64),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: context.buddy.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(4),
                ),
                border: isSelected
                  ? Border.all(color: AppColors.success.withValues(alpha: 0.6), width: 2)
                  : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: 200,
                        height: 200,
                        cacheWidth: 400,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.broken_image, color: Colors.white70, size: 32),
                          ),
                        ),
                      ),
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 8),
                  ],
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Bubble (links, wie Telegram Fremdnachricht) ──
  Widget _aiBubble(BuildContext context) {
    final c = context.buddy;
    final isMultiSelect = onToggleSelection != null;
    return GestureDetector(
      onLongPress: isMultiSelect
        ? () {
            onToggleSelection!();
            HapticFeedback.mediumImpact();
          }
        : () {
            Clipboard.setData(ClipboardData(text: message.text));
            HapticFeedback.mediumImpact();
            _showCopiedSnackBar(context, 'Nachricht kopiert');
          },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isSelected) ...[
            Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(right: 64),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: c.aiBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: c.cardShadow,
                border: Border.all(
                  color: isSelected
                      ? AppColors.success.withValues(alpha: 0.6)
                      : c.aiBubbleBorder,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: c.t1,
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

  Widget _systemBubble(BuildContext context) {
    final c = context.buddy;
    final isProactive = message.metadata?['proactive'] == true;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(
                color: c.t2,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          if (isProactive)
            _ProactiveFeedback(messageId: message.id),
        ],
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
                color: context.buddy.t2,
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
    final c = context.buddy;
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
    
    // Guard the lat/lon casts — this runs outside the try above, so a target
    // without numeric lat/lon would throw during build and show a red error.
    final lat = targetData['lat'];
    final lon = targetData['lon'];
    if (lat is! num || lon is! num) return _aiBubble(context);
    final target = LatLng(lat.toDouble(), lon.toDouble());
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
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: c.cardShadow,
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
                        style: TextStyle(color: c.t1,
                            fontWeight: FontWeight.w600, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Icon(Icons.map, color: AppColors.primary, size: 20),
                ],
              ),
              if (route != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(modeIcon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(route.distanceText,
                        style: TextStyle(color: c.t1,
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 12),
                    Text(route.durationText,
                        style: TextStyle(color: c.t2, fontSize: 14)),
                    const Spacer(),
                    Text('${route.steps.length} Schritte',
                        style: TextStyle(color: c.t3, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                // First 2 steps preview
                if (route.steps.length > 1) ...[
                  Text('→ ${route.steps[1].instruction}',
                      style: TextStyle(color: c.t2, fontSize: 13),
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
      // Nur ein dezentes Icon — das Text-Label unter jeder Nachricht
      // macht den Chat unruhig.
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Icon(
          _isPlaying ? Icons.volume_up : Icons.volume_up_outlined,
          size: 15,
          color: _isPlaying ? AppColors.primary : context.buddy.t3,
        ),
      ),
    );
  }
}


// ── Proactive Feedback ──
class _ProactiveFeedback extends StatefulWidget {
  final String messageId;
  const _ProactiveFeedback({required this.messageId});

  @override
  State<_ProactiveFeedback> createState() => _ProactiveFeedbackState();
}

class _ProactiveFeedbackState extends State<_ProactiveFeedback> {
  int? _feedback; // 1 = helpful, -1 = not helpful, null = not yet rated

  @override
  Widget build(BuildContext context) {
    if (_feedback != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          _feedback! == 1 ? '👍 Danke!' : '👎 Verstanden.',
          style: TextStyle(fontSize: 11, color: context.buddy.t3),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _FeedbackButton(icon: Icons.thumb_up_outlined, onTap: () => _setFeedback(1)),
        const SizedBox(width: 8),
        _FeedbackButton(icon: Icons.thumb_down_outlined, onTap: () => _setFeedback(-1)),
      ],
    );
  }

  void _setFeedback(int value) {
    setState(() => _feedback = value);
    Future.microtask(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Save individual rating
        final key = 'proactive_feedback_${widget.messageId}';
        await prefs.setInt(key, value);
        // Save last-feedback meta (for cooldown in engine)
        await prefs.setInt('proactive_last_feedback_value', value);
        await prefs.setInt('proactive_last_feedback_time', DateTime.now().millisecondsSinceEpoch);
        // Track rolling window of last 10 ratings
        final histRaw = prefs.getString('proactive_feedback_history');
        final List<int> hist = histRaw != null
            ? List<int>.from((jsonDecode(histRaw) as List).cast<int>())
            : [];
        hist.add(value);
        if (hist.length > 10) hist.removeAt(0);
        await prefs.setString('proactive_feedback_history', jsonEncode(hist));
        // Auto-degrade if >=5 negative in last 10
        final negatives = hist.where((v) => v == -1).length;
        if (negatives >= 5 && hist.length >= 6) {
          final currentLevel = prefs.getInt('proactivity_level') ?? 2;
          if (currentLevel > 0) {
            await prefs.setInt('proactivity_level', currentLevel - 1);
            debugPrint('ProactiveEngine: Auto-degraded level from $currentLevel to ${currentLevel - 1} due to negative feedback trend');
          }
        }
        debugPrint('Proactive feedback for ${widget.messageId}: $value (history: $hist, negatives: $negatives)');
      } catch (e) {
        debugPrint('Feedback save error: $e');
      }
    });
  }
}

class _FeedbackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _FeedbackButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Icon(icon, size: 16, color: context.buddy.t3),
        ),
      ),
    );
  }
}
