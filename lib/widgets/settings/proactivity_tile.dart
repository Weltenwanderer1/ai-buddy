import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/theme/buddy_colors.dart';
import '../../services/secure_config_service.dart';
import 'list_tile.dart';

class ProactivityTile extends StatefulWidget {
  const ProactivityTile({super.key});

  @override
  State<ProactivityTile> createState() => _ProactivityTileState();
}

class _ProactivityTileState extends State<ProactivityTile> {
  late AppLocalizations t;

  List<String> get _labels => [t.config_proactivity_off, t.config_proactivity_low, t.config_proactivity_normal, t.config_proactivity_high];
  List<String> get _hints => [
    t.config_proactivity_off_desc,
    t.config_proactivity_low_desc,
    t.config_proactivity_normal_desc,
    t.config_proactivity_high_desc,
  ];

  @override
  Widget build(BuildContext context) {
    t = AppLocalizations.of(context);
    final config = context.read<SecureConfigService>();
    return SettingsListTile(
      icon: Icons.notifications_active_rounded,
      title: t.config_proactivity,
      subtitle: '${_labels[config.proactivityLevel]} · ${_hints[config.proactivityLevel]}',
      color: context.buddy.accent,
      trailing: DropdownButton<int>(
        value: config.proactivityLevel,
        underline: const SizedBox(),
        style: TextStyle(color: context.buddy.t1, fontSize: 13),
        items: [
          DropdownMenuItem(value: 0, child: Text(t.config_proactivity_off)),
          DropdownMenuItem(value: 1, child: Text(t.config_proactivity_low)),
          DropdownMenuItem(value: 2, child: Text(t.config_proactivity_normal)),
          DropdownMenuItem(value: 3, child: Text(t.config_proactivity_high)),
        ],
        onChanged: (v) async {
          if (v == null) return;
          await config.setProactivityLevel(v);
          if (!context.mounted) return;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.config_proactivity}: ${_labels[v]}')),
          );
        },
      ),
      onTap: () {}, // DropdownButton is the primary interaction here
    );
  }
}
