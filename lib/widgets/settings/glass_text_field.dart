import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

class GlassTextField extends StatefulWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool obscure;

  const GlassTextField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.obscure = false,
  });

  @override
  State<GlassTextField> createState() => _GlassTextFieldState();
}

class _GlassTextFieldState extends State<GlassTextField> {
  bool _focused = false;
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    final isObscure = widget.obscure && _obscureText;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Focus(
        onFocusChange: (f) => setState(() => _focused = f),
        child: TextField(
          controller: widget.controller,
          obscureText: isObscure,
          style: TextStyle(color: context.buddy.t1, fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: widget.label,
            hintStyle: TextStyle(color: context.buddy.t3.withValues(alpha: 0.5), fontSize: 15),
            prefixIcon: Icon(widget.icon, size: 20, color: _focused
              ? context.buddy.accent
              : context.buddy.t3.withValues(alpha: 0.6)),
            suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 18, color: context.buddy.t3),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
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
        ),
      ),
    );
  }
}
