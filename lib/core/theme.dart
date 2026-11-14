import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  AppColors._();

  static const felt = Color(0xFF0F6B45);
  static const feltDark = Color(0xFF062B1C);
  static const gold = Color(0xFFE9B949);
  static const goldDark = Color(0xFFB98A24);
  static const wood = Color(0xFF3E2615);
  static const woodLight = Color(0xFF6B4423);
  static const cream = Color(0xFFFFF8E7);
  static const danger = Color(0xFFE05A4F);
  static const cardRed = Color(0xFFC62828);
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
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.feltDark,
      textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withAlpha(60),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
