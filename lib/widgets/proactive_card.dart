import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/proactive_engine.dart';
import '../core/theme/app_colors.dart';

/// An inline card in the chat that shows a proactive suggestion
/// from the ProactiveEngine. Tapping the quick action sends it as a message.
class ProactiveCard extends StatelessWidget {
  final ProactiveSuggestion suggestion;
  final void Function(String text) onSend;

  const ProactiveCard({
    super.key,
    required this.suggestion,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(suggestion.type);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_iconForType(suggestion.type), size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                suggestion.title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            suggestion.body,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          if (suggestion.quickAction != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () => onSend(suggestion.quickAction!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.2),
                        color.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _actionLabel(suggestion.type),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _colorForType(ProactiveEventType type) {
    switch (type) {
      case ProactiveEventType.morningBriefing:
        return Colors.amber.shade400;
      case ProactiveEventType.calendarHeadsup:
        return Colors.blue.shade400;
      case ProactiveEventType.batteryLow:
        return Colors.orange.shade400;
      case ProactiveEventType.eveningRecap:
        return Colors.indigo.shade400;
      case ProactiveEventType.contextualSuggestion:
        return AppColors.primary;
    }
  }

  IconData _iconForType(ProactiveEventType type) {
    switch (type) {
      case ProactiveEventType.morningBriefing:
        return Icons.wb_sunny_rounded;
      case ProactiveEventType.calendarHeadsup:
        return Icons.calendar_month_rounded;
      case ProactiveEventType.batteryLow:
        return Icons.battery_alert_rounded;
      case ProactiveEventType.eveningRecap:
        return Icons.nights_stay_rounded;
      case ProactiveEventType.contextualSuggestion:
        return Icons.lightbulb_rounded;
    }
  }

  String _actionLabel(ProactiveEventType type) {
    switch (type) {
      case ProactiveEventType.morningBriefing:
        return 'Checken';
      case ProactiveEventType.calendarHeadsup:
        return 'Navigieren';
      case ProactiveEventType.batteryLow:
        return 'Handeln';
      case ProactiveEventType.eveningRecap:
        return 'Antworten';
      case ProactiveEventType.contextualSuggestion:
        return 'Ausführen';
    }
  }
}
