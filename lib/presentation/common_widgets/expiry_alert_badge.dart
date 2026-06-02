import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Badge showing document expiry status.
/// Green = valid, Amber = expiring soon, Red = expired.
class ExpiryAlertBadge extends StatelessWidget {
  final DateTime? expiryDate;
  final bool compact;

  const ExpiryAlertBadge({
    super.key,
    required this.expiryDate,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (expiryDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final daysLeft = expiryDate!.difference(now).inDays;

    final Color color;
    final String label;
    final IconData icon;

    if (daysLeft < 0) {
      color = AppColors.error;
      label = compact ? 'Expired' : 'Expired ${(-daysLeft)}d ago';
      icon  = Icons.error_outline_rounded;
    } else if (daysLeft <= 30) {
      color = AppColors.tertiary;
      label = compact ? '${daysLeft}d' : 'Expires in $daysLeft days';
      icon  = Icons.warning_amber_rounded;
    } else {
      color = AppColors.success;
      label = compact ? 'Valid' : 'Valid until ${_format(expiryDate!)}';
      icon  = Icons.check_circle_outline_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 12 : 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  String _format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}
