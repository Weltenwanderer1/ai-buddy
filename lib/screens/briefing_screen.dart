import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../services/briefing_service.dart';
import '../services/email_service.dart';
import '../services/chat_history_service.dart';
import '../services/ollama_cloud_service.dart';
import '../services/memory_service.dart';
import '../services/persona_service.dart';
import '../services/context_service.dart';
import '../tools/tool_registry.dart';
import '../models/chat_message.dart';
import 'chat_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// BRIEFING SCREEN v2.0 — Premium Morning Brief
/// Features:
///   • Pull-to-refresh (Cupertino)
///   • Parallax hero with live particles
///   • Timeline-based Tagesplan
///   • Swipable email cards
///   • Expandable sections with full details
///   • Voice shortcut to chat
///   • Notification badges
///   • Battery / time / context bar
/// ═══════════════════════════════════════════════════════════════

class BriefingScreen extends StatefulWidget {
  const BriefingScreen({super.key});

  @override
  State<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends State<BriefingScreen>
    with TickerProviderStateMixin {
  MorningBriefing? _briefing;
  bool _isLoading = true;
  String? _error;
  late final ScrollController _scrollCtrl;
  double _scrollOffset = 0;

  // Animations
  late final AnimationController _heroCtrl;
  late final Animation<double> _heroFade;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _particlesCtrl;

  // Expandable sections tracking
  final Set<int> _expandedSections = {};

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    _scrollCtrl.addListener(_onScroll);

    _heroCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutQuart),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _particlesCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _loadBriefing();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _heroCtrl.dispose();
    _shimmerCtrl.dispose();
    _particlesCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() => _scrollOffset = _scrollCtrl.offset);
  }

  Future<void> _loadBriefing() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ollama = context.read<OllamaCloudService>();
      final memory = context.read<MemoryService>();
      final tools = context.read<ToolRegistry>();

      final service = BriefingService(
        llm: ollama,
        memory: memory,
        tools: tools,
      );
      final briefing = await service.generateBriefing();

      if (mounted) {
        setState(() {
          _briefing = briefing;
          _isLoading = false;
        });
        _heroCtrl.forward(from: 0);
        _shimmerCtrl.stop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Fehler beim Laden: $e';
          _isLoading = false;
        });
        _shimmerCtrl.stop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ctx = ContextService().currentContext();
    final hourStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final weekday = ['Montag','Dienstag','Mittwoch','Donnerstag',
        'Freitag','Samstag','Sonntag'][now.weekday - 1];
    final month = ['','Januar','Februar','März','April','Mai','Juni',
        'Juli','August','September','Oktober','November','Dezember'][now.month];

    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: CupertinoScrollbar(
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── Pull-to-Refresh ──
            CupertinoSliverRefreshControl(
              onRefresh: _loadBriefing,
            ),

            // ── Context Status Bar ──
            SliverToBoxAdapter(
              child: _ContextStatusBar(
                time: hourStr,
                greeting: _greetingForHour(now.hour),
                batteryPct: null, // Would come from get_battery_info tool
                unreadCount: _briefing?.totalUnread ?? 0,
                scrollOffset: _scrollOffset,
              ),
            ),

            // ── Parallax Hero ──
            SliverToBoxAdapter(
              child: _buildHero(weekday, now.day, month),
            ),

            // ── Loading ──
            if (_isLoading)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: List.generate(5, (i) =>
                      _ShimmerCard(controller: _shimmerCtrl, delay: i * 180),
                    ),
                  ),
                ),
              ),

            // ── Error ──
            if (_error != null)
              SliverToBoxAdapter(
                child: _GlassCard(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 40),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      _ActionChip(
                        label: '↻ Erneut versuchen',
                        color: AppColors.primary,
                        onTap: _loadBriefing,
                      ),
                    ],
                  ),
                ),
              ),

            // ── Tagesplan Section (if we have calendar data) ──
            if (_briefing != null && _briefing!.sections.any((s) => s.type == BriefingType.calendar))
              SliverToBoxAdapter(
                child: _TagesplanSection(
                  briefing: _briefing!,
                  onTap: () => _continueWithTopic('Tagesplan'),
                ),
              ),

            // ── Sections ──
            if (_briefing != null)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) {
                    if (index == _briefing!.sections.length) {
                      return _BottomActions(
                        briefing: _briefing!,
                        onChat: () => _continueInChat(_briefing!),
                        onVoice: () => _startVoiceBriefing(_briefing!),
                      );
                    }
                    final section = _briefing!.sections[index];
                    final isExpanded = _expandedSections.contains(index);
                    return _SectionCard(
                      section: section,
                      index: index,
                      isExpanded: isExpanded,
                      onExpand: () => setState(() {
                        if (isExpanded) {
                          _expandedSections.remove(index);
                        } else {
                          _expandedSections.add(index);
                        }
                      }),
                      onTap: () => _onSectionTap(section),
                      onAction: (action) => _onSectionAction(section, action),
                    );
                  },
                  childCount: _briefing!.sections.length + 1,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(String weekday, int day, String month) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Parallax gradient + floating particles
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, _scrollOffset * 0.25),
            child: Container(
              height: 420,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.22),
                    const Color(0xFF06B6D4).withOpacity(0.10),
                    const Color(0xFFD946EF).withOpacity(0.06),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),

        // Animated floating particles
        AnimatedBuilder(
          animation: _particlesCtrl,
          builder: (context, child) {
            final t = _particlesCtrl.value;
            return Stack(
              children: [
                Positioned(
                  top: 30 + math.sin(t * 2 * math.pi) * 15,
                  right: 20 + math.cos(t * math.pi) * 10,
                  child: _GlowOrb(
                    color: const Color(0xFF8B5CF6),
                    size: 140,
                    opacity: 0.10,
                  ),
                ),
                Positioned(
                  top: 100 + math.sin(t * math.pi + 1) * 20,
                  left: 10 + math.cos(t * 2 * math.pi) * 15,
                  child: _GlowOrb(
                    color: const Color(0xFF06B6D4),
                    size: 90,
                    opacity: 0.08,
                  ),
                ),
                Positioned(
                  top: 180 + math.sin(t * 1.5 * math.pi + 2) * 10,
                  right: 60 + math.cos(t * 0.5 * math.pi) * 20,
                  child: _GlowOrb(
                    color: const Color(0xFFD946EF),
                    size: 60,
                    opacity: 0.06,
                  ),
                ),
              ],
            );
          },
        ),

        // Hero content
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 60, 28, 32),
          child: FadeTransition(
            opacity: _heroFade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DayBadge(weekday: weekday),
                const SizedBox(height: 14),
                Text(
                  '$day. $month',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 24),
                if (_briefing != null)
                  _SummaryCard(text: _briefing!.summary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _greetingForHour(int hour) {
    if (hour < 6) return 'Gute Nacht';
    if (hour < 11) return 'Guten Morgen';
    if (hour < 14) return 'Guten Tag';
    if (hour < 18) return 'Schönen Nachmittag';
    if (hour < 22) return 'Guten Abend';
    return 'Gute Nacht';
  }

  void _onSectionTap(BriefingSection section) {
    HapticFeedback.selectionClick();
    _continueWithTopic('${section.title}: ${section.displayText ?? section.content.substring(0, section.content.length < 150 ? section.content.length : 150)}');
  }

  void _onSectionAction(BriefingSection section, String action) {
    HapticFeedback.mediumImpact();
    if (action == 'reply_email' && section.type == BriefingType.email) {
      final important = section.extraData?['important'] as List<EmailMessage>? ?? [];
      if (important.isNotEmpty) {
        final e = important.first;
        _continueWithTopic(
            'Schreibe eine professionelle Antwort auf diese E-Mail:\n'
            'Von: ${e.sender}\nBetreff: ${e.subject}\n\n'
            'Bitte knapp, höflich, auf Deutsch. Ich bin mir unsicher was genau ich antworten soll.');
      }
    } else if (action == 'mark_read') {
      _showSnackbar('Als gelesen markiert (Mock)');
    } else if (action == 'calendar_plan') {
      _continueWithTopic(
          'Hilf mir meinen heutigen Tag optimal zu planen. '
          'Berücksichtige Wetter, Termine und wichtige Aufgaben.');
    } else if (action == 'remind_me') {
      _continueWithTopic(
          'Erstelle Erinnerungen für die wichtigsten Aufgaben aus meinem Briefing.');
    }
  }

  void _continueInChat(MorningBriefing briefing) {
    HapticFeedback.heavyImpact();
    final contextLines = briefing.sections
        .map((s) => '${s.icon} ${s.title}: ${s.displayText ?? s.content.substring(0, s.content.length < 180 ? s.content.length : 180)}')
        .join('\n');
    _continueWithTopic(
        '📋 Morgenbriefing vom ${briefing.generatedAt.day}.${briefing.generatedAt.month}.\n\n$contextLines\n\n'
        'Ich möchte über diese Themen sprechen und bei der Umsetzung helfen lassen. '
        'Was schlägst du als erstes vor?');
  }

  void _startVoiceBriefing(MorningBriefing briefing) {
    // Voice briefing — inject context and open chat with live voice hint
    _continueWithTopic(
        '🎙️ Voice-Briefing: Bitte fasse mein Morgenbriefing zusammen und '
        'nenn mir die 3 wichtigsten Handlungen für heute.');
  }

  void _continueWithTopic(String topic) {
    final chatHistory = context.read<ChatHistoryService>();
    chatHistory.add(ChatMessage(
      text: topic,
      isUser: false,
      type: MessageType.system,
    ));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChatScreen()),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────

class _ContextStatusBar extends StatelessWidget {
  final String time;
  final String greeting;
  final int? batteryPct;
  final int unreadCount;
  final double scrollOffset;

  const _ContextStatusBar({
    required this.time,
    required this.greeting,
    required this.batteryPct,
    required this.unreadCount,
    required this.scrollOffset,
  });

  @override
  Widget build(BuildContext context) {
    // Fade out as user scrolls
    final opacity = (1 - scrollOffset / 80).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                greeting,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (unreadCount > 0)
              _NotificationBadge(count: unreadCount),
            if (batteryPct != null) ...[
              const SizedBox(width: 8),
              _BatteryIndicator(pct: batteryPct!),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotificationBadge extends StatelessWidget {
  final int count;
  const _NotificationBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.9),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _BatteryIndicator extends StatelessWidget {
  final int pct;
  const _BatteryIndicator({required this.pct});

  @override
  Widget build(BuildContext context) {
    final color = pct < 20
        ? AppColors.error
        : pct < 50
            ? AppColors.warning
            : AppColors.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.battery_full, color: color, size: 16),
        const SizedBox(width: 2),
        Text(
          '$pct%',
          style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _DayBadge extends StatelessWidget {
  final String weekday;
  const _DayBadge({required this.weekday});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        weekday.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.5,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String text;
  const _SummaryCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.45),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withOpacity(0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16.5,
          height: 1.75,
          fontWeight: FontWeight.w400,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withOpacity(opacity),
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final AnimationController controller;
  final int delay;
  const _ShimmerCard({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = ((controller.value * 2) + delay / 1000) % 1.0;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(20),
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                AppColors.bgCard.withOpacity(0.25),
                AppColors.bgCard.withOpacity(0.55),
                AppColors.bgCard.withOpacity(0.25),
              ],
              stops: [0.0, 0.5 + progress * 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAGESPLAN SECTION — Timeline view of the day's schedule
// ═══════════════════════════════════════════════════════════════════════

class _TagesplanSection extends StatelessWidget {
  final MorningBriefing briefing;
  final VoidCallback onTap;

  const _TagesplanSection({required this.briefing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final calSection = briefing.sections.firstWhere(
      (s) => s.type == BriefingType.calendar,
      orElse: () => briefing.sections.first,
    );

    // Parse events from the content text
    final events = _parseEvents(calSection.content);

    if (events.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('📅', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Dein Tagesplan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                _ActionChip(
                  label: '✨ Optimieren',
                  color: const Color(0xFF8B5CF6),
                  onTap: onTap,
                ),
              ],
            ),
          ),
          // Timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bgCard.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF8B5CF6).withOpacity(0.1),
              ),
            ),
            child: Column(
              children: events.map((e) => _TimelineEvent(
                time: e.time,
                title: e.title,
                isPast: e.isPast,
                isNext: e.isNext,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  List<_Event> _parseEvents(String content) {
    final events = <_Event>[];
    final lines = content.split('\n');
    final now = DateTime.now();

    for (final line in lines) {
      final match = RegExp(r'- (.+?) \((\d{2}:\d{2})').firstMatch(line);
      if (match != null) {
        final title = match.group(1) ?? 'Termin';
        final timeStr = match.group(2) ?? '00:00';
        final parts = timeStr.split(':');
        final hour = int.tryParse(parts[0]) ?? 0;
        final min = int.tryParse(parts[1]) ?? 0;
        final eventTime = DateTime(now.year, now.month, now.day, hour, min);
        events.add(_Event(
          time: timeStr,
          title: title,
          isPast: eventTime.isBefore(now),
          isNext: false,
        ));
      }
    }

    // Mark the first future event as "next"
    for (int i = 0; i < events.length; i++) {
      if (!events[i].isPast) {
        events[i] = _Event(
          time: events[i].time,
          title: events[i].title,
          isPast: false,
          isNext: true,
        );
        break;
      }
    }

    return events.take(4).toList();
  }
}

class _Event {
  final String time;
  final String title;
  final bool isPast;
  final bool isNext;
  _Event({required this.time, required this.title, required this.isPast, required this.isNext});
}

class _TimelineEvent extends StatelessWidget {
  final String time;
  final String title;
  final bool isPast;
  final bool isNext;

  const _TimelineEvent({
    required this.time,
    required this.title,
    required this.isPast,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = isPast
        ? AppColors.textTertiary
        : isNext
            ? AppColors.primary
            : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                  boxShadow: isNext
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              if (!isPast)
                Container(
                  width: 2,
                  height: 24,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        dotColor.withOpacity(0.5),
                        dotColor.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPast ? AppColors.textTertiary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                    color: isPast ? AppColors.textTertiary : Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isNext)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'NEXT',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SECTION CARD — Expandable, swipable for emails, action chips
// ═══════════════════════════════════════════════════════════════════════

class _SectionCard extends StatefulWidget {
  final BriefingSection section;
  final int index;
  final bool isExpanded;
  final VoidCallback onExpand;
  final VoidCallback onTap;
  final void Function(String) onAction;

  const _SectionCard({
    required this.section,
    required this.index,
    required this.isExpanded,
    required this.onExpand,
    required this.onTap,
    required this.onAction,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  bool _pressed = false;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    Future.delayed(
      Duration(milliseconds: widget.index * 120 + 300),
      () => _ctrl.forward(),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _sectionColor(widget.section.type);
    final isEmail = widget.section.type == BriefingType.email;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _ctrl.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        // Swipe for emails
        onHorizontalDragUpdate: isEmail
            ? (details) => setState(() => _dragOffset += details.delta.dx)
            : null,
        onHorizontalDragEnd: isEmail
            ? (_) {
                if (_dragOffset > 80) {
                  widget.onAction('reply_email');
                } else if (_dragOffset < -80) {
                  widget.onAction('mark_read');
                }
                setState(() => _dragOffset = 0);
              }
            : null,
        child: Transform.translate(
          offset: Offset(_dragOffset, 0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _pressed
                  ? AppColors.bgCard.withOpacity(0.8)
                  : AppColors.bgCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: _pressed
                    ? color.withOpacity(0.35)
                    : color.withOpacity(0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        widget.section.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.section.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          if (widget.section.displayText != null)
                            Text(
                              widget.section.displayText!,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Expand/chevron
                    GestureDetector(
                      onTap: widget.onExpand,
                      child: AnimatedRotation(
                        turns: widget.isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more,
                          color: AppColors.textTertiary,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Content
                Text(
                  widget.section.content,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.65,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: widget.isExpanded ? null : 5,
                  overflow: widget.isExpanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                ),
                // Expanded details
                if (widget.isExpanded && isEmail)
                  _ExpandedEmailDetails(
                    extraData: widget.section.extraData,
                    onReply: () => widget.onAction('reply_email'),
                  ),
                // Swipe hint for emails
                if (isEmail && !widget.isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        Icon(Icons.swipe_left,
                            color: AppColors.textTertiary, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Swipe: ← Antwort  |  Gelesen →',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Action chips
                if (!widget.isExpanded)
                  _buildActionChips(color, isEmail),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChips(Color color, bool isEmail) {
    final chips = <Widget>[];

    if (isEmail) {
      chips.add(_ActionChip(
        label: '✍️ Antwort',
        color: color,
        onTap: () => widget.onAction('reply_email'),
      ));
      chips.add(_ActionChip(
        label: '✓ Gelesen',
        color: color,
        onTap: () => widget.onAction('mark_read'),
      ));
    }

    if (widget.section.type == BriefingType.calendar) {
      chips.add(_ActionChip(
        label: '✨ Tagesplan',
        color: color,
        onTap: () => widget.onAction('calendar_plan'),
      ));
    }

    if (widget.section.type == BriefingType.tasks) {
      chips.add(_ActionChip(
        label: '⏰ Erinnern',
        color: color,
        onTap: () => widget.onAction('remind_me'),
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Color _sectionColor(BriefingType type) {
    switch (type) {
      case BriefingType.weather: return const Color(0xFF06B6D4);
      case BriefingType.calendar: return const Color(0xFF8B5CF6);
      case BriefingType.email: return const Color(0xFFEF4444);
      case BriefingType.news: return const Color(0xFFF59E0B);
      case BriefingType.tasks: return const Color(0xFF22C55E);
      case BriefingType.summary: return const Color(0xFF3B82F6);
    }
  }
}

class _ExpandedEmailDetails extends StatelessWidget {
  final Map<String, dynamic>? extraData;
  final VoidCallback onReply;

  const _ExpandedEmailDetails({required this.extraData, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final important = (extraData?['important'] as List<dynamic>? ?? [])
        .cast<EmailMessage>();
    final other = (extraData?['other'] as List<dynamic>? ?? [])
        .cast<EmailMessage>();

    if (important.isEmpty && other.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (important.isNotEmpty) ...[
            const Text(
              'Wichtige E-Mails',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ...important.map((e) => _EmailRow(
              email: e,
              isImportant: true,
              onReply: onReply,
            )),
            const SizedBox(height: 12),
          ],
          if (other.isNotEmpty) ...[
            const Text(
              'Weitere',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...other.take(3).map((e) => _EmailRow(
              email: e,
              isImportant: false,
              onReply: onReply,
            )),
          ],
        ],
      ),
    );
  }
}

class _EmailRow extends StatelessWidget {
  final EmailMessage email;
  final bool isImportant;
  final VoidCallback onReply;

  const _EmailRow({
    required this.email,
    required this.isImportant,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isImportant
            ? const Color(0xFFEF4444).withOpacity(0.08)
            : AppColors.bgDark.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isImportant
              ? const Color(0xFFEF4444).withOpacity(0.2)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.subject,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isImportant ? FontWeight.w700 : FontWeight.w500,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  email.sender.split('<').first.trim(),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          if (isImportant)
            GestureDetector(
              onTap: onReply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Antwort',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// BOTTOM ACTIONS — Chat + Voice shortcuts
// ═══════════════════════════════════════════════════════════════════════

class _BottomActions extends StatelessWidget {
  final MorningBriefing briefing;
  final VoidCallback onChat;
  final VoidCallback onVoice;

  const _BottomActions({
    required this.briefing,
    required this.onChat,
    required this.onVoice,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 10),
      child: Column(
        children: [
          // Main CTA
          GestureDetector(
            onTap: onChat,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withOpacity(0.35),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  const Text(
                    'Im Chat besprechen',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary: Voice
          GestureDetector(
            onTap: onVoice,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.2),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.mic,
                      color: AppColors.secondary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Voice-Briefing starten',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondary,
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
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
