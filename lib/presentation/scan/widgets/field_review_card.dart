import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// Editable field card shown on the scan result review screen.
/// Lets the user confirm or correct a Gemini-extracted field before saving.
class FieldReviewCard extends StatefulWidget {
  final String label;
  final String value;
  final double confidence;
  final ValueChanged<String> onChanged;

  const FieldReviewCard({
    super.key,
    required this.label,
    required this.value,
    required this.confidence,
    required this.onChanged,
  });

  @override
  State<FieldReviewCard> createState() => _FieldReviewCardState();
}

class _FieldReviewCardState extends State<FieldReviewCard> {
  late final TextEditingController _ctrl;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _confidenceColor {
    if (widget.confidence >= 0.85) return AppColors.success;
    if (widget.confidence >= 0.6)  return AppColors.tertiary;
    return AppColors.error;
  }

  String get _confidenceLabel =>
      '${(widget.confidence * 100).toStringAsFixed(0)}%';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: _editing
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Label + confidence ─────────────────────────────────────────
          Row(
            children: [
              Text(
                widget.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _confidenceColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _confidenceLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _confidenceColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // ── Value (editable) ───────────────────────────────────────────
          _editing
              ? TextField(
                  controller: _ctrl,
                  autofocus: true,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                  onSubmitted: (v) {
                    widget.onChanged(v);
                    setState(() => _editing = false);
                  },
                )
              : GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _ctrl.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.edit_rounded,
                        size: 14,
                        color: AppColors.outlineVariant,
                      ),
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
