import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  // درجات الجوخ الأخضر الفاخر (Casino Emerald Felt)
  static const felt = Color(0xFF0F7A4C);
  static const feltDark = Color(0xFF062B1C);
  static const feltVibrant = Color(0xFF14935D);
  static const feltDeep = Color(0xFF031A11);

  // درجات الذهب الملكي (Royal Champagne Gold)
  static const gold = Color(0xFFE5B83A);
  static const goldLight = Color(0xFFFBE795);
  static const goldDark = Color(0xFFA67C1E);
  static const goldMuted = Color(0xFF8C6C23);

  // درجات الخشب الفاخر (Polished Mahogany Wood)
  static const wood = Color(0xFF26150B);
  static const woodLight = Color(0xFF4A2B18);
  static const woodBorder = Color(0xFF754523);

  // درجات أوراق اللعب (Playing Cards)
  static const cardCream = Color(0xFFFAF7EE);
  static const cardDimmed = Color(0xFFC8C2B3);
  static const cardRed = Color(0xFFD32F2F);
  static const cardRedDark = Color(0xFF9A0007);
  static const cardBlack = Color(0xFF1A1A1A);
  static const cardGoldAccent = Color(0xFFC59B27);
  static const cream = Color(0xFFFFF9EC);

  // حالات وتنبيهات
  static const danger = Color(0xFFE05244);
  static const success = Color(0xFF2EB872);
  static const info = Color(0xFF388E3C);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.felt,
        brightness: Brightness.dark,
        primary: AppColors.gold,
        onPrimary: Colors.black,
        surface: AppColors.feltDark,
        surfaceTint: AppColors.gold,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.feltDark,
      textTheme: GoogleFonts.tajawalTextTheme(base.textTheme).apply(
        bodyColor: Colors.white,
        displayColor: AppColors.goldLight,
        fontFamilyFallback: const ['Apple Symbols', 'Arial', 'sans-serif'],
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.feltDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.gold.withAlpha(90), width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withAlpha(90),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withAlpha(30)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withAlpha(30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIconColor: AppColors.gold,
      ),
    );
  }
}
