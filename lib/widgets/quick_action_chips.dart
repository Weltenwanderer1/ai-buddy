import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Action-Chips die unter AI-Nachrichten erscheinen —
/// schlaegt sinnvolle Follow-up-Aktionen vor.
class QuickActionChips extends StatelessWidget {
  final String messageText;
  final void Function(String action) onAction;

  const QuickActionChips({
    super.key,
    required this.messageText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final actions = _suggestActions(messageText);
    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: actions.map((a) => _ActionChip(
          label: a.label,
          icon: a.icon,
          onTap: () => onAction(a.command),
        )).toList(),
      ),
    );
  }

  static List<_SuggestedAction> _suggestActions(String text) {
    final lower = text.toLowerCase();
    final actions = <_SuggestedAction>[];

    // UC5: Persona insights detection
    if (_hasAny(lower, ['gelernt', 'ueber mich', 'weiss', 'persona', 'entwicklung', 'muster', 'gewohnheit'])) {
      actions.add(_SuggestedAction('🧠', 'Was hast du gelernt?', 'search_memories'));
    }

    // Catch-up / summary
    if (_hasAny(lower, ['stand', 'ueberblick', 'neuigkeiten', 'zusammenfassung', 'summary'])) {
      actions.add(_SuggestedAction('📋', 'Bring mich auf Stand', 'quick_summary'));
    }

    // Reminder detection
    if (_hasAny(lower, ['morgen', 'spaeter', 'nachher', 'vergessen', 'wichtig', 'termin', 'uhr', 'um '])) {
      actions.add(_SuggestedAction('⏰', 'Erinnerung setzen', 'set_reminder'));
    }

    // Calendar detection
    if (_hasAny(lower, ['kalender', 'eintragen', 'event', 'planen', 'treffen', 'besprechung'])) {
      actions.add(_SuggestedAction('📅', 'In Kalender eintragen', 'add_calendar'));
    }

    // Web search
    if (_hasAny(lower, ['suchen', 'finden', 'herausfinden', 'nachschauen', 'recherchieren', 'wissen', 'information'])) {
      actions.add(_SuggestedAction('🔍', 'Im Web suchen', 'web_search'));
    }

    // Navigation
    if (_hasAny(lower, ['hinfahren', 'navigieren', 'route', 'weg', 'adresse', 'wo ist', 'finde', 'navigiere', 'fahren', 'bring'])) {
      actions.add(_SuggestedAction('🗺️', 'Navigation starten', 'navigate'));
    }

    // Quick note
    if (_hasAny(lower, ['merken', 'notieren', 'aufschreiben', 'speichern'])) {
      actions.add(_SuggestedAction('📝', 'Notiz speichern', 'save_note'));
    }

    return actions.take(3).toList();
  }

  static bool _hasAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));
}

class _SuggestedAction {
  final String icon;
  final String label;
  final String command;
  const _SuggestedAction(this.icon, this.label, this.command);
}

class _ActionChip extends StatelessWidget {
  final String label;
  final String icon;
  final VoidCallback onTap;

  const _ActionChip({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}