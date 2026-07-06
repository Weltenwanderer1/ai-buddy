import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

/// Callback signature for showing a custom model dialog.
typedef ShowCustomModelDialog = Future<String?> Function(BuildContext context, String current);

/// Glass-styled model dropdown for cloud provider presets.
class ModelDropdown extends StatefulWidget {
  const ModelDropdown({
    super.key,
    required this.label,
    required this.icon,
    required this.models,
    required this.controller,
    this.onCustomModelTap,
  });
  final String label;
  final IconData icon;
  final List<Map<String, String>> models;
  final TextEditingController controller;
  final ShowCustomModelDialog? onCustomModelTap;

  @override
  State<ModelDropdown> createState() => _ModelDropdownState();
}

class _ModelDropdownState extends State<ModelDropdown> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final currentId = widget.controller.text;
    final isCustom = !widget.models.any((m) => m['id'] == currentId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: DropdownButtonFormField<String>(
          initialValue: isCustom ? '__custom__' : currentId,
          icon: Icon(Icons.arrow_drop_down_rounded, color: context.buddy.t3),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: context.buddy.t3.withValues(alpha: 0.5), fontSize: 15),
            prefixIcon: Icon(widget.icon, size: 20, color: _focused
              ? context.buddy.accent
              : context.buddy.t3.withValues(alpha: 0.6)),
            filled: true,
            fillColor: _focused
              ? context.buddy.card.withValues(alpha: 0.5)
              : context.buddy.card.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.buddy.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: context.buddy.accent.withValues(alpha: 0.6), width: 1.5),
            ),
            isDense: true,
          ),
          dropdownColor: context.buddy.card,
          style: TextStyle(color: context.buddy.t1, fontSize: 15, fontWeight: FontWeight.w500),
          items: [
            ...widget.models.map((model) => DropdownMenuItem(
              value: model['id'],
              child: Text(model['name']!, style: TextStyle(color: context.buddy.t1, fontSize: 14)),
            )),
            DropdownMenuItem(
              value: '__custom__',
              child: Row(children: [
                Icon(Icons.edit_rounded, size: 16, color: context.buddy.t3),
                const SizedBox(width: 8),
                Text(isCustom ? 'Eigene: ${currentId.length > 30 ? "${currentId.substring(0, 30)}…" : currentId}' : 'Eigene ID eingeben…',
                  style: TextStyle(color: isCustom ? context.buddy.accent : context.buddy.t2, fontSize: 14)),
              ]),
            ),
          ],
          onChanged: (value) async {
            if (value == '__custom__') {
              if (widget.onCustomModelTap != null) {
                final custom = await widget.onCustomModelTap!(context, widget.controller.text);
                if (!mounted) return;
                if (custom != null && custom.isNotEmpty) {
                  setState(() => widget.controller.text = custom);
                }
              }
            } else if (value != null) {
              setState(() => widget.controller.text = value);
            }
          },
        ),
      ),
    );
  }
}
