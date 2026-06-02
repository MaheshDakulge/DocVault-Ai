import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/models/document_model.dart';
import '../../common_widgets/expiry_alert_badge.dart';

/// Rich document card for grid or list display.
/// Shows thumbnail, category badge, expiry badge and tamper indicator.
class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // ── Thumbnail ────────────────────────────────────────────────
              _Thumbnail(thumbPath: document.thumbPath, category: document.category),
              const SizedBox(width: 14),

              // ── Content ──────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.filename,
                      style: theme.textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _CategoryBadge(category: document.category),
                        if (document.subcategory != null) ...[
                          const SizedBox(width: 4),
                          Text(
                            document.subcategory!,
                            style: theme.textTheme.labelSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                    if (document.expiryDate != null) ...[
                      const SizedBox(height: 6),
                      ExpiryAlertBadge(
                        expiryDate: document.expiryDate,
                        compact: true,
                      ),
                    ],
                  ],
                ),
              ),

              // ── Trailing icons ───────────────────────────────────────────
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (document.isTampered)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(
                        Icons.warning_rounded,
                        color: AppColors.tertiary,
                        size: 16,
                      ),
                    ),
                  if (!document.isSynced)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Icon(
                        Icons.cloud_off_rounded,
                        color: AppColors.outlineVariant,
                        size: 14,
                      ),
                    ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.outlineVariant,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? thumbPath;
  final String category;

  const _Thumbnail({required this.thumbPath, required this.category});

  @override
  Widget build(BuildContext context) {
    final file = thumbPath != null ? File(thumbPath!) : null;
    final hasFile = file != null && file.existsSync();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 52,
        height: 52,
        child: hasFile
            ? Image.file(file, fit: BoxFit.cover)
            : Container(
                color: AppColors.primaryFixed,
                child: Icon(
                  _iconFor(category),
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Identity':   return Icons.badge_rounded;
      case 'Education':  return Icons.school_rounded;
      case 'Financial':  return Icons.account_balance_rounded;
      case 'Medical':    return Icons.medical_information_rounded;
      case 'Vehicle':    return Icons.directions_car_rounded;
      case 'Travel':     return Icons.flight_rounded;
      case 'Property':   return Icons.home_rounded;
      case 'Employment': return Icons.work_rounded;
      default:           return Icons.description_rounded;
    }
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        category,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
