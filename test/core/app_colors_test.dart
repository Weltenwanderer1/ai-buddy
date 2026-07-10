import 'package:ai_buddy/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppColors.foregroundFor', () {
    test('uses dark text on warm cream', () {
      expect(
        AppColors.foregroundFor(const Color(0xFFF5E6CC)),
        const Color(0xFF14151A),
      );
    });

    test('uses white text on dark accents', () {
      expect(
        AppColors.foregroundFor(const Color(0xFF1B1F2E)),
        Colors.white,
      );
    });
  });
}
