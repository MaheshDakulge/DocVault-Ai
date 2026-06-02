import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Displays the SHA-256 tamper verification result for a document.
/// Shows a forensic-grade integrity indicator — green if intact, red if modified.
class TamperStatusBadge extends StatelessWidget {
  final bool isTampered;
  final bool showLabel;

  const TamperStatusBadge({
    super.key,
    required this.isTampered,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final color  = isTampered ? AppColors.error   : AppColors.success;
    final icon   = isTampered ? Icons.gpp_bad_rounded : Icons.verified_user_rounded;
    final label  = isTampered ? 'Integrity Compromised' : 'Integrity Verified';
    final bgColor = color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          if (showLabel) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
