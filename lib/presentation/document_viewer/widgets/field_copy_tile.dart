import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/colors.dart';
import '../../../domain/models/field_model.dart';

/// A tappable field row that copies [value] to clipboard on tap.
/// Shows a brief "Copied!" snackbar confirmation.
class FieldCopyTile extends StatefulWidget {
  final FieldModel field;

  const FieldCopyTile({super.key, required this.field});

  @override
  State<FieldCopyTile> createState() => _FieldCopyTileState();
}

class _FieldCopyTileState extends State<FieldCopyTile> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.field.value));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.field.isCopyable ? _copy : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // ── Label + value ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.field.label.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.field.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Copy indicator ────────────────────────────────────────
              if (widget.field.isCopyable)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _copied
                      ? const Icon(
                          Icons.check_circle_rounded,
                          key: ValueKey('checked'),
                          color: AppColors.success,
                          size: 20,
                        )
                      : const Icon(
                          Icons.copy_rounded,
                          key: ValueKey('copy'),
                          color: AppColors.outlineVariant,
                          size: 18,
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
