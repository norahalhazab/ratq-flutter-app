import 'package:flutter/material.dart';

class AppColors {
  // === Brand colors (from design) ===
  static const Color primaryColor = Color(0xFF3B7691); // main blue
  static const Color secondaryColor = Color(0xFF63A2BF); // light blue
  static const Color accentColor = Color(0xFF63A2BF);

  // === Backgrounds ===
  static const Color backgroundColor = Color(0xFFFFFFFF); // white
  static const Color surfaceColor = Color(0xFFF8FAFC); // cards background
  static const Color dividerColor = Color(0xFFE2E8F0);

  // === Text colors ===
  static const Color textPrimary = Color(0xFF0F172A); // almost black
  static const Color textSecondary = Color(0xFF475569); // slate
  static const Color textMuted = Color(0xFF94A3B8);

  // === Status colors ===
  static const Color successColor = Color(0xFF3B7691); // reused blue
  static const Color infoColor = Color(0xFF63A2BF);

  static const Color warningColor = Color(0xFFF59E0B);

  static const Color errorColor = Color(0xFFBF121D); // red alert
  static const Color errorDark = Color(0xFF7A0000);

  // === Transparent helpers ===
  static Color primarySoft = primaryColor.withOpacity(0.12);
  static Color errorSoft = errorColor.withOpacity(0.12);
  static Color infoSoft = secondaryColor.withOpacity(0.12);

  // === Gradients (subtle like cards & buttons) ===
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFF3B7691),
      Color(0xFF63A2BF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [
      Color(0xFFBF121D),
      Color(0xFF7A0000),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
