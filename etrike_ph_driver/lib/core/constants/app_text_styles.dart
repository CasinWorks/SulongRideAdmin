import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static TextStyle get _sans => GoogleFonts.plusJakartaSans(color: AppColors.textPrimary);
  static TextStyle get _serif => GoogleFonts.playfairDisplay(color: AppColors.textPrimary);

  static TextStyle headingLg = _serif.copyWith(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
  );

  static TextStyle headingMd = _serif.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w600,
  );

  static TextStyle headingSm = _sans.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
  );

  static TextStyle displayMetric = _serif.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.ecoGreenLight,
  );

  static TextStyle body = _sans.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle bodySecondary = _sans.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static TextStyle label = _sans.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  static TextStyle button = _sans.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.ecoCream,
  );

  static TextStyle mono = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.6,
  );
}
