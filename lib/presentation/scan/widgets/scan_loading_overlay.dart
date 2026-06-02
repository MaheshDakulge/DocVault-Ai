import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';

/// Full-screen overlay displayed while Gemini Vision processes the document.
/// Shows animated progress stages so the user knows what's happening.
class ScanLoadingOverlay extends StatefulWidget {
  final String? message;
  const ScanLoadingOverlay({super.key, this.message});

  @override
  State<ScanLoadingOverlay> createState() => _ScanLoadingOverlayState();
}

class _ScanLoadingOverlayState extends State<ScanLoadingOverlay> {
  int _stage = 0;

  static const _stages = [
    'Uploading image…',
    'Gemini reading document…',
    'Extracting fields…',
    'Computing tamper hash…',
    'Saving to vault…',
  ];

  @override
  void initState() {
    super.initState();
    _tick();
  }

  void _tick() async {
    for (var i = 0; i < _stages.length; i++) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) setState(() => _stage = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.surface.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Pulsing icon ───────────────────────────────────────────────
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                color: AppColors.primary,
                size: 42,
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(begin: 0.92, end: 1.0, duration: 900.ms, curve: Curves.easeInOut),

            const SizedBox(height: 36),

            // ── Stage label ────────────────────────────────────────────────
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                widget.message ?? _stages[_stage],
                key: ValueKey(widget.message ?? _stage),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'This may take a few seconds',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 32),

            // ── Step dots ──────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_stages.length, (i) {
                final active = i <= _stage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
