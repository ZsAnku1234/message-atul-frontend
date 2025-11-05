import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF4E5FF8);
  static const primaryDark = Color(0xFF3C4ADC);
  static const secondary = Color(0xFF6B7CFF);
  static const accent = Color(0xFFEE6352);
  static const background = Color(0xFFF4F5FA);
  static const backgroundDark = Color(0xFF101223);
  static const surface = Colors.white;
  static const surfaceDark = Color(0xFF1A1C2E);
  static const textPrimary = Color(0xFF1F2430);
  static const textSecondary = Color(0xFF636D7C);
  static const textInverse = Colors.white;
  static const success = Color(0xFF4CAF50);
  static const warning = Color(0xFFFFB300);
  static const danger = Color(0xFFE53935);

  static const linearGradient = LinearGradient(
    colors: [Color(0xFF4E5FF8), Color(0xFF6B7CFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const subtleGradient = LinearGradient(
    colors: [Color(0xFFEEF0FF), Color(0xFFF9FAFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
