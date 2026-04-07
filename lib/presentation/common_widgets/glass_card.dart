import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

/// Glassmorphism card — the signature floating component in DocsVault AI.
///
/// Implements the "Glass & Gradient" rule from the design system:
///   - Semi-transparent surface background (72% opacity)
///   - 20px backdrop blur
///   - Ambient shadow (6% opacity, no hard lines)
///   - Ghost border via outlineVariant at 15% opacity
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final double blurStrength;
  final bool elevated;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 20,
    this.backgroundColor,
    this.blurStrength = 20,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurStrength, sigmaY: blurStrength),
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.glass,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              // Ghost border — felt, not seen (15% opacity)
              color: AppColors.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      // Ambient shadow — no hard black, tinted purple-grey
                      color: AppColors.onSurface.withValues(alpha: 0.06),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
