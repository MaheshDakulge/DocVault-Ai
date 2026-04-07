import 'package:flutter/material.dart';

/// DocsVault AI — "Digital Curator" Color System
/// Based on the Stitch design token export (project: AI Document Assistant)
class AppColors {
  AppColors._();

  // ── Primary Brand ──────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF630ED4);
  static const Color primaryContainer = Color(0xFF7C3AED);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFEDE0FF);
  static const Color primaryFixed = Color(0xFFEADDFF);
  static const Color primaryFixedDim = Color(0xFFD2BBFF);

  // ── Secondary ──────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF6A4FA0);
  static const Color secondaryContainer = Color(0xFFC4A7FF);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF523787);

  // ── Tertiary (Amber — for expiry alerts) ───────────────────────────────────
  static const Color tertiary = Color(0xFF7D3D00);
  static const Color tertiaryContainer = Color(0xFFA15100);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFFFE0CD);

  // ── Surface Hierarchy (The "Layered Glass" System) ─────────────────────────
  static const Color surface = Color(0xFFF7F9FB);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F6);
  static const Color surfaceContainer = Color(0xFFECEEF0);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EA);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E5);
  static const Color surfaceDim = Color(0xFFD8DADC);
  static const Color surfaceBright = Color(0xFFF7F9FB);

  // ── On Surface ─────────────────────────────────────────────────────────────
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF4A4455);
  static const Color onBackground = Color(0xFF191C1E);

  // ── Error ──────────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ── Outline ────────────────────────────────────────────────────────────────
  static const Color outline = Color(0xFF7B7487);
  static const Color outlineVariant = Color(0xFFCCC3D8);

  // ── Semantic Extras ────────────────────────────────────────────────────────
  /// "Emerald" used for verified / success states (sparingly)
  static const Color success = Color(0xFF166534);
  static const Color successContainer = Color(0xFFDCFCE7);

  // ── Glassmorphism Helper ───────────────────────────────────────────────────
  /// Semi-transparent surface for glassmorphism overlays (FAB, nav)
  static Color get glass => surfaceContainer.withValues(alpha: 0.72);
  static Color get glassStrong => surfaceContainerHighest.withValues(alpha: 0.88);
}
