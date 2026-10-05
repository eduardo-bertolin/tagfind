import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TagFind brand palette — matches the web landing page.
class AppColors {
  AppColors._();

  static const Color amber       = Color(0xFFFFC700);
  static const Color amberDark   = Color(0xFFE0AF00);
  static const Color background  = Color(0xFF121212);
  static const Color card        = Color(0xFF1C1C1C);
  static const Color cardBorder  = Color(0xFF2A2A2A);
  static const Color surface     = Color(0xFF252525);
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textMuted   = Color(0xFFA3A3A3);
  static const Color danger      = Color(0xFFFF6B6B);
  static const Color success     = Color(0xFF4ADE80);
  static const Color whatsapp    = Color(0xFF25D366);

  // Semantic surface roles (M3-aligned)
  static const Color surfaceContainerLow = Color(0xFF252525);
  static const Color surfaceContainerHigh = Color(0xFF2D2D2D);
  static const Color onSurfaceVariant    = Color(0xFFA3A3A3);
  static const Color onSurfacePrimary    = Color(0xFFF5F5F5);
}

class AppTheme {
  AppTheme._();

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.amber,
      onPrimary: Colors.black,
      secondary: AppColors.amber,
      surface: AppColors.card,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.amber),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.amber,
      foregroundColor: Colors.black,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.amber, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.onSurfaceVariant),
      hintStyle: const TextStyle(color: AppColors.onSurfaceVariant),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.amber,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surface,
      contentTextStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.cardBorder,
      thickness: 1,
    ),
  );
}
