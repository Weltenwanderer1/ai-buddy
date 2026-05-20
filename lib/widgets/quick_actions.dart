import 'package:flutter/material.dart';
import '../services/context_service.dart';
import '../core/theme/app_colors.dart';

class QuickActions extends StatelessWidget {
  final void Function(String text) onSend;

  const QuickActions({super.key, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final ctx = ContextService().currentContext();
    final actions = ContextService.suggestedActions(ctx);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = actions[index];
          return _ActionChip(
            label: action.label,
            prefix: action.prefix,
            onTap: () => onSend(action.prefix),
          );
        },
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final String prefix;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.prefix, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconForLabel(label),
              size: 15,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label) {
      case 'Briefing': return Icons.wb_sunny;
      case 'Navi': return Icons.navigation;
      case 'Timer': return Icons.timer;
      case 'Termine': return Icons.calendar_month;
      case 'Notiz': return Icons.note_add;
      case 'Akku': return Icons.battery_charging_full;
      case 'SMS': return Icons.message;
      case 'Apps': return Icons.apps;
      case 'Suche': return Icons.search;
      case 'Rückblick': return Icons.history;
      case 'Ruhe': return Icons.nightlight_round;
      case 'Morgen': return Icons.alarm;
      default: return Icons.touch_app;
    }
  }
}
