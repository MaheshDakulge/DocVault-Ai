import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

/// A single search result row corresponding to the JSON from backend /search
class SearchResultTile extends StatelessWidget {
  final Map<String, dynamic> result;
  final String query;
  final VoidCallback onTap;

  const SearchResultTile({
    super.key,
    required this.result,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = result['category'] as String? ?? 'Other';
    final subcategory = result['subcategory'] as String?;
    final filename = result['filename'] as String? ?? 'Document';
    final matchFieldLabel = result['match_field_label'] as String?;
    final matchHighlight = result['match_highlight'] as String?;
    
    // Fall back to filename if there's no highlight string
    final displayHighlight = matchHighlight ?? filename;

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Category icon ────────────────────────────────────────────
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _categoryIcon(category),
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),

              // ── Document info + Highlights ─────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BackendHighlightText(
                      text: displayHighlight,
                      query: query,
                      style: theme.textTheme.titleSmall!,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      category + (subcategory != null ? ' · $subcategory' : '') +
                          (matchFieldLabel != null ? ' · Matched in $matchFieldLabel' : ''),
                      style: theme.textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),

              // ── Trailing ─────────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.outlineVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
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

/// Parses the backend's ^^highlight^^ syntax and applies a yellow background
class _BackendHighlightText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _BackendHighlightText({
    required this.text,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    // If no markup is present, we try a fallback manual indexOf highlight
    if (!text.contains("^^")) {
      return _buildManualHighlight(text, query, style);
    }

    final spans = <TextSpan>[];
    final parts = text.split("^^");
    
    // Splitting by ^^ alternatingly gives [normal, highlight, normal, highlight...]
    for (int i = 0; i < parts.length; i++) {
      if (i % 2 == 1 && parts[i].isNotEmpty) {
        // Highlighted segment
        spans.add(TextSpan(
          text: parts[i],
          style: style.copyWith(
            backgroundColor: Colors.yellow.withValues(alpha: 0.4),
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ));
      } else if (parts[i].isNotEmpty) {
        // Normal segment
        spans.add(TextSpan(text: parts[i]));
      }
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: spans,
      ),
    );
  }

  Widget _buildManualHighlight(String text, String query, TextStyle style) {
    if (query.isEmpty) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

    final lower      = text.toLowerCase();
    final queryLower = query.toLowerCase();
    final start      = lower.indexOf(queryLower);

    if (start == -1) return Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis);

    final end = start + query.length;
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: style,
        children: [
          if (start > 0) TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: style.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              backgroundColor: Colors.yellow.withValues(alpha: 0.4),
            ),
          ),
          if (end < text.length) TextSpan(text: text.substring(end)),
        ],
      ),
    );
  }
}
