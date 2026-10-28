import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class JaColors {
  static const ink = Color(0xFF12211B);
  static const inkSoft = Color(0xFF2C4339);
  static const paper = Color(0xFFF3EEE3);
  static const card = Color(0xFFFFFDF8);
  static const line = Color(0xFFDDD3C2);
  static const copper = Color(0xFFC46A2E);
  static const copperDark = Color(0xFF9B4E1C);
  static const forest = Color(0xFF1B5C45);
  static const muted = Color(0xFF6D6458);
  static const danger = Color(0xFFB42318);
  static const warn = Color(0xFFB45309);
  static const ok = Color(0xFF176C45);
  static const cream = Color(0xFFEFE7D8);
  static const gold = Color(0xFFE8C39A);
}

ThemeData buildJaTheme() {
  final outfit = GoogleFonts.outfit();
  final display = GoogleFonts.fraunces(color: JaColors.ink, fontWeight: FontWeight.w700);

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: JaColors.paper,
    fontFamily: outfit.fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: JaColors.forest,
      primary: JaColors.forest,
      surface: JaColors.card,
      error: JaColors.danger,
    ),
    textTheme: TextTheme(
      displayLarge: display.copyWith(fontSize: 64),
      displayMedium: display.copyWith(fontSize: 56, height: 0.95),
      headlineLarge: display.copyWith(fontSize: 40),
      headlineMedium: display.copyWith(fontSize: 36),
      headlineSmall: display.copyWith(fontSize: 28),
      titleLarge: display.copyWith(fontSize: 22),
      bodyMedium: outfit.copyWith(fontSize: 15, color: JaColors.ink),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: JaColors.forest, width: 1.4),
      ),
    ),
  );
}
