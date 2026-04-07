import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/colors.dart';

/// The primary Scanning FAB — pill-shaped floating action button with:
///   - Primary gradient background (primary → primaryContainer)
///   - Glassmorphism container
///   - 12px ambient shadow (appears floating above content)
///   - Subtle scale pulse animation
class ScanningFab extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const ScanningFab({
    super.key,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: const [
        ScaleEffect(
          begin: Offset(0.95, 0.95),
          end: Offset(1.0, 1.0),
          duration: Duration(milliseconds: 1200),
          curve: Curves.easeInOut,
        ),
      ],
      onComplete: (c) => c.loop(reverse: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(50),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                splashColor: AppColors.onPrimary.withValues(alpha: 0.1),
                onTap: isLoading ? null : onPressed,
                borderRadius: BorderRadius.circular(50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      else
                        const Icon(Icons.document_scanner_rounded,
                            color: AppColors.onPrimary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isLoading ? 'Scanning…' : 'Scan Document',
                        style: const TextStyle(
                          color: AppColors.onPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
