import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/colors.dart';

/// Card displaying a government scheme with eligibility status.
/// Tapping "Apply Now" opens the scheme URL.
class SchemeCard extends StatelessWidget {
  final Map<String, dynamic> scheme;

  const SchemeCard({super.key, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final name        = scheme['name'] as String? ?? 'Scheme';
    final benefit     = scheme['benefit'] as String? ?? '';
    final level       = scheme['level'] as String? ?? 'Central';
    final isEligible  = scheme['is_eligible'] as bool? ?? false;
    final reason      = scheme['eligibility_reason'] as String?;
    final applyUrl    = scheme['apply_url'] as String?;

    final statusColor  = isEligible ? AppColors.success : AppColors.onSurfaceVariant;
    final statusLabel  = isEligible ? 'Eligible' : 'Not eligible';
    final statusIcon   = isEligible
        ? Icons.check_circle_rounded
        : Icons.cancel_outlined;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: isEligible
            ? Border.all(
                color: AppColors.success.withValues(alpha: 0.35),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusColor, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Level badge ───────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                level,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSecondaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Benefit ───────────────────────────────────────────────────
            Text(
              benefit,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            // ── Reason (why eligible / not) ───────────────────────────────
            if (reason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isEligible
                      ? AppColors.successContainer.withValues(alpha: 0.5)
                      : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  reason,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isEligible
                        ? AppColors.success
                        : AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],

            // ── Apply CTA ─────────────────────────────────────────────────
            if (isEligible && applyUrl != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(applyUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not open $applyUrl')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Apply Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
