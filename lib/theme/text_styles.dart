import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_tokens.dart';

class AppTextStyles {
  static TextTheme lightTextTheme = GoogleFonts.interTextTheme(
    ThemeData.light().textTheme,
  ).copyWith(
    titleLarge: GoogleFonts.inter(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textSecondary,
    ),
  );

  static TextTheme darkTextTheme = GoogleFonts.interTextTheme(
    ThemeData.dark().textTheme,
  ).copyWith(
    titleLarge: GoogleFonts.inter(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: AppColors.textInverse,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.textInverse,
    ),
    bodyLarge: GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textInverse.withOpacity(0.72),
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      color: AppColors.textInverse.withOpacity(0.72),
    ),
  );
}
