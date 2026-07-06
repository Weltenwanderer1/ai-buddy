import 'package:flutter/material.dart';
import '../../core/theme/buddy_colors.dart';

class ResultBox extends StatelessWidget {
  final String text;

  const ResultBox({super.key, required this.text});

  /// Fehler-Präfixe aller unterstützten Sprachen (config_*_error/_fail) —
  /// nur auf 'Fehler' zu prüfen färbte englische/japanische/chinesische
  /// Fehlermeldungen grün als Erfolg.
  static const _errorPrefixes = ['Fehler', 'Error', 'エラー', '错误'];

  @override
  Widget build(BuildContext context) {
    final ok = !_errorPrefixes.any(text.startsWith);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (ok ? context.buddy.success : context.buddy.error).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (ok ? context.buddy.success : context.buddy.error).withValues(alpha: 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded,
          size: 18, color: ok ? context.buddy.success : context.buddy.error),
        const SizedBox(width: 10),
        Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, color: ok ? context.buddy.success : context.buddy.error, height: 1.4))),
      ]),
    );
  }
}
