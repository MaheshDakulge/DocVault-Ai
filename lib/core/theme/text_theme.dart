import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// DocsVault AI — "Editorial Voice" Typography
/// Manrope → Headlines (authority, brand)
/// Inter → Body / Labels (legibility for document metadata)
class AppTextTheme {
  AppTextTheme._();

  static TextTheme get textTheme {
    final manrope = GoogleFonts.manropeTextTheme();
    final inter = GoogleFonts.interTextTheme();

    return TextTheme(
      // ── Display: high-impact hero moments ─────────────────────────────────
      displayLarge: manrope.displayLarge!.copyWith(
        fontSize: 56, fontWeight: FontWeight.w800, color: AppColors.onSurface, height: 1.1,
      ),
      displayMedium: manrope.displayMedium!.copyWith(
        fontSize: 45, fontWeight: FontWeight.w700, color: AppColors.onSurface, height: 1.15,
      ),
      displaySmall: manrope.displaySmall!.copyWith(
        fontSize: 36, fontWeight: FontWeight.w700, color: AppColors.onSurface, height: 1.2,
      ),

      // ── Headline: major section headers ───────────────────────────────────
      headlineLarge: manrope.headlineLarge!.copyWith(
        fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.onSurface,
      ),
      headlineMedium: manrope.headlineMedium!.copyWith(
        fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onSurface,
      ),
      headlineSmall: manrope.headlineSmall!.copyWith(
        fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.onSurface,
      ),

      // ── Title: document card / list headers (Inter) ───────────────────────
      titleLarge: inter.titleLarge!.copyWith(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onSurface,
      ),
      titleMedium: inter.titleMedium!.copyWith(
        fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.onSurface, letterSpacing: 0.15,
      ),
      titleSmall: inter.titleSmall!.copyWith(
        fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface, letterSpacing: 0.1,
      ),

      // ── Body: metadata + descriptions (Inter) ─────────────────────────────
      bodyLarge: inter.bodyLarge!.copyWith(
        fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.onSurface, height: 1.5,
      ),
      bodyMedium: inter.bodyMedium!.copyWith(
        fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.onSurface, height: 1.5,
      ),
      bodySmall: inter.bodySmall!.copyWith(
        fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant, height: 1.4,
      ),

      // ── Label: micro-copy, timestamps, status tags (Inter) ────────────────
      labelLarge: inter.labelLarge!.copyWith(
        fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.onSurface, letterSpacing: 0.1,
      ),
      labelMedium: inter.labelMedium!.copyWith(
        fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.onSurfaceVariant, letterSpacing: 0.5,
      ),
      labelSmall: inter.labelSmall!.copyWith(
        fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.onSurfaceVariant, letterSpacing: 0.5,
      ),
    );
  }
}
