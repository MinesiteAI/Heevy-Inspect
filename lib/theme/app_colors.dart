import 'package:flutter/material.dart';

import '../config/heevy_brand.dart';

abstract final class AppColors {
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext c) => isDark(c) ? Colors.black : Colors.white;
  static Color sheet(BuildContext c) =>
      isDark(c) ? const Color(0xFF121212) : const Color(0xFFF2F2F7);
  static Color surface(BuildContext c) =>
      isDark(c) ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
  static Color surfaceAlt(BuildContext c) =>
      isDark(c) ? const Color(0xFF2A2A2C) : const Color(0xFFECECEC);
  static Color card(BuildContext c) =>
      isDark(c) ? const Color(0xFF1C1C1E) : Colors.white;
  static Color divider(BuildContext c) =>
      isDark(c) ? const Color(0xFF2A2A2C) : const Color(0xFFE5E5EA);
  static Color border(BuildContext c) =>
      isDark(c) ? const Color(0xFF3A3A3C) : const Color(0xFFD1D1D6);
  static Color text(BuildContext c) => isDark(c) ? Colors.white : Colors.black;
  static Color get muted => const Color(0xFF8E8E93);
  static Color inverseBg(BuildContext c) =>
      isDark(c) ? Colors.white : Colors.black;
  static Color inverseText(BuildContext c) =>
      isDark(c) ? Colors.black : Colors.white;
  static Color get brandAccent => HeevyBrand.accent;
  static Color get error => const Color(0xFFFF6B6B);
}
