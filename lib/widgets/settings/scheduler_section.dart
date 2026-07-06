import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/buddy_colors.dart';
import '../../services/buddy_scheduler.dart';
import 'glass_card.dart';
import 'divider.dart';

/// Settings section for background tasks (BuddyScheduler).
class SchedulerSection extends StatelessWidget {
  const SchedulerSection({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheduler = context.watch<BuddyScheduler>();
    if (!scheduler.isInitialized) return const SizedBox.shrink();

    return GlassCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Row(children: [
          Icon(Icons.schedule_outlined, size: 20, color: context.buddy.accent),
          const SizedBox(width: 8),
          Text(t.bg_tasks_title,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.buddy.accent)),
        ]),
      ),
      const SizedBox(height: 4),
      for (final entry in scheduler.tasks.entries) ...[
        SchedulerTaskTile(
          taskId: entry.key,
          config: entry.value,
          lastRun: scheduler.getLastRun(entry.key),
          onToggle: (enabled) => scheduler.setTaskEnabled(entry.key, enabled),
          onRunNow: () => scheduler.runTaskNow(entry.key),
        ),
        if (entry.key != scheduler.tasks.keys.last) const SettingsDivider(),
      ],
    ]);
  }
}

class SchedulerTaskTile extends StatelessWidget {
  const SchedulerTaskTile({
    super.key,
    required this.taskId,
    required this.config,
    this.lastRun,
    required this.onToggle,
    required this.onRunNow,
  });
  final String taskId;
  final BuddyTaskConfig config;
  final String? lastRun;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRunNow;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return ListTile(
      leading: Icon(
        taskId == 'self_optimization' ? Icons.auto_fix_high_outlined : Icons.wb_sunny_outlined,
        color: config.enabled ? context.buddy.accent : context.buddy.t2,
        size: 22,
      ),
      title: Text(config.name, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: config.enabled ? context.buddy.t1 : context.buddy.t2,
      )),
      subtitle: Text(
        '${config.description}\n${t.bg_tasks_every_minutes.replaceAll("{n}", config.frequency.inMinutes.toString())}${lastRun != null ? " · ${t.bg_tasks_last_run} ${_formatLastRun(lastRun!, t)}" : ""}',
        style: TextStyle(fontSize: 12, color: context.buddy.t2),
      ),
      isThreeLine: true,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          icon: const Icon(Icons.play_circle_outline, size: 20),
          color: context.buddy.accent,
          onPressed: onRunNow,
          tooltip: t.bg_tasks_run_now,
        ),
        Switch(
          value: config.enabled,
          onChanged: onToggle,
          activeThumbColor: context.buddy.accent,
        ),
      ]),
    );
  }

  String _formatLastRun(String iso, AppLocalizations t) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return t.time_just_now;
      if (diff.inMinutes < 60) return t.time_minutes_ago.replaceAll('{n}', diff.inMinutes.toString());
      if (diff.inHours < 24) return t.time_hours_ago.replaceAll('{n}', diff.inHours.toString());
      return t.time_days_ago.replaceAll('{n}', diff.inDays.toString());
    } catch (_) {
      return iso;
    }
  }
}
