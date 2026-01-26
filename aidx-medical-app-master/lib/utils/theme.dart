import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ====== Palette ======
  static const Color tealPrimary = Color(0xFF3B7691);
  static const Color tealLight   = Color(0xFF63A2BF);
  static const Color redPrimary  = Color(0xFFBF121D);
  static const Color redDark     = Color(0xFF7A0000);

  static const Color black = Color(0xFF0B0F14);
  static const Color white = Color(0xFFFFFFFF);

  // ====== Background ======
  static const Color bgLight = Color(0xFFF6F8FB); // أغمق شوي عشان التباين
  static const Color surface = Color(0xFFFFFFFF);

  // ====== Text ======
  static const Color textDark  = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF475569); // كان فاتح زيادة
  static const Color textOnDark = Color(0xFFF8FAFC);

  // ====== Main colors ======
  static const Color primaryColor = tealPrimary;
  static const Color accentColor  = tealLight;
  static const Color dangerColor  = redPrimary;
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color successColor = Color(0xFF22C55E);
  static const Color infoColor    = tealLight;

  // ====== Old names (compatibility) ======
  static const Color bgDark = bgLight;
  static const Color bgMedium = Color(0xFFEFF3F7);
  static const Color bgDarkSecondary = Color(0xFFE6EDF3);
  static const Color softWhite = white;

  static const Color textPrimary = textDark;
  static const Color textSecondary = textMuted;
  static const Color textTeal = tealPrimary;

  // ====== Glass / Cards ======
  // خليها أقل شفافية → أوضح
  static const Color bgGlassLight  = Color(0xFFFDFDFD);
  static const Color bgGlassMedium = Color(0xFFFFFFFF);
  static const Color bgGlassHeavy  = Color(0xFFFFFFFF);

  // ====== Gradients ======
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tealPrimary, tealLight],
  );

  static const LinearGradient vitalsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x143B7691),
      Color(0x1463A2BF),
    ],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [redPrimary, redDark],
  );

  static final LinearGradient bgGradientLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: const [
      Color(0xFFFFFFFF),
      Color(0xFFF6F8FB),
    ],
    stops: const [0.2, 0.8],
  );

  // 👈 مهم: عشان الشاشات القديمة
  static LinearGradient get bgGradient => bgGradientLight;

  // ====== Decorations ======
  static BoxDecoration cardDecoration = BoxDecoration(
    color: bgGlassHeavy,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: const Color(0x1F0B0F14)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x220B0F14),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ],
  );

  static BoxDecoration glassContainer = BoxDecoration(
    color: bgGlassMedium,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color(0x240B0F14), width: 1),
    boxShadow: const [
      BoxShadow(
        color: Color(0x1A0B0F14),
        blurRadius: 22,
        offset: Offset(0, 12),
      ),
    ],
  );

  // ====== Text styles ======
  static final TextStyle headlineLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: textDark,
  );

  static final TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static final TextStyle bodyText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textMuted,
    height: 1.6,
  );

  // ====== ThemeData (LIGHT) ======
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: bgLight,
    fontFamily: GoogleFonts.inter().fontFamily,

    colorScheme: const ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: dangerColor,
      surface: surface,
      onPrimary: white,
      onSurface: textDark,
    ),

    textTheme: GoogleFonts.interTextTheme(
      ThemeData.light().textTheme,
    ).copyWith(
      // عناوين
      headlineLarge: const TextStyle(color: textDark, fontWeight: FontWeight.w700),
      headlineMedium: const TextStyle(color: textDark, fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(color: textDark, fontWeight: FontWeight.w600),

      // Titles
      titleLarge: const TextStyle(color: textDark, fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(color: textMuted, fontWeight: FontWeight.w600),

      // Body (هذا أهم شيء)
      bodyLarge: const TextStyle(color: textDark),
      bodyMedium: const TextStyle(color: textDark),
      bodySmall: const TextStyle(color: textMuted),

      // Labels (أزرار صغيرة / chips)
      labelLarge: const TextStyle(color: textDark, fontWeight: FontWeight.w600),
      labelMedium: const TextStyle(color: textMuted),
      labelSmall: const TextStyle(color: textMuted),
    ),


    cardTheme: CardThemeData(
      color: white,
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x1F0B0F14)),
      ),
    ),


    appBarTheme: AppBarTheme(
      backgroundColor: bgLight,
      elevation: 0,
      centerTitle: true,
      foregroundColor: textDark,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFFFFFFFF),
      selectedItemColor: primaryColor,
      unselectedItemColor: textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 2,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: bgGlassMedium,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0x240B0F14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: primaryColor, width: 1.5),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primaryColor,
    ),
  );

  // ====== ThemeData (DARK) ======
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: black,
    fontFamily: GoogleFonts.inter().fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      error: dangerColor,
      surface: Color(0xFF111827),
    ),
  );

  static const Color backgroundColor = bgLight;
}
