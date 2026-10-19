import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const canvas = Color(0xFF080D18);
  static const surface = Color(0xFF101827);
  static const surfaceRaised = Color(0xFF151F32);
  static const outline = Color(0xFF27354A);
  static const navy = Color(0xFF0B1323);
  static const navyMid = Color(0xFF12233B);
  static const electric = Color(0xFF69E5FF);
  static const electricDark = Color(0xFF20A9D2);
  static const violet = Color(0xFF9A7BFF);
  static const mint = Color(0xFF67F3C2);
  static const card = Color(0xFF111C2C);
  static const muted = Color(0xFFA1B1C8);
}

class AppTheme {
  static ThemeData futuristic() {
    final scheme = ColorScheme.fromSeed(
      brightness: Brightness.dark,
      seedColor: AppColors.electric,
      primary: AppColors.electric,
      secondary: AppColors.violet,
      surface: AppColors.surface,
      error: const Color(0xFFFF718C),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      dividerColor: AppColors.outline,
      visualDensity: VisualDensity.standard,
    );
    final text = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: const Color(0xFFEAF2FF),
      displayColor: const Color(0xFFF6FAFF),
    );
    return base.copyWith(
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.canvas.withValues(alpha: .94),
        foregroundColor: const Color(0xFFF6FAFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
          color: const Color(0xFFF6FAFF),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.electric,
          foregroundColor: AppColors.canvas,
          disabledBackgroundColor: AppColors.outline,
          disabledForegroundColor: AppColors.muted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFEAF2FF),
          side: const BorderSide(color: AppColors.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas.withValues(alpha: .72),
        hintStyle: const TextStyle(color: AppColors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.electric, width: 1.4),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: AppColors.surfaceRaised,
        side: const BorderSide(color: AppColors.outline),
        labelStyle: const TextStyle(color: Color(0xFFD8E5F6)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: const TextStyle(color: Color(0xFFF6FAFF)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
