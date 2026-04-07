import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/colors.dart';

/// Collapsible offline status banner — shown at top of affected screens
/// when the app detects no internet connectivity.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.tertiary,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppColors.onTertiary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Offline — search, browse & view work normally',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onTertiary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -1, end: 0, duration: 350.ms, curve: Curves.easeOut);
  }
}
