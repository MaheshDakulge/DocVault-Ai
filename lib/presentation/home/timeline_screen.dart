import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../../domain/providers/document_provider.dart';
import '../../domain/models/document_model.dart';
import '../common_widgets/vault_app_bar.dart';
import '../common_widgets/expiry_alert_badge.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(documentsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const VaultAppBar(
        title: 'Timeline',
        subtitle: 'Documents by year',
      ),
      body: docsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (docs) {
          if (docs.isEmpty) {
            return _EmptyTimeline();
          }
          final grouped = _groupByYear(docs);
          final years   = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            itemCount: years.length,
            itemBuilder: (context, i) {
              final year  = years[i];
              final items = grouped[year]!;
              return _YearSection(
                year: year,
                documents: items,
                index: i,
              );
            },
          );
        },
      ),
    );
  }

  Map<int, List<DocumentModel>> _groupByYear(List<DocumentModel> docs) {
    final map = <int, List<DocumentModel>>{};
    for (final doc in docs) {
      final year = doc.createdAt.year;
      map.putIfAbsent(year, () => []).add(doc);
    }
    return map;
  }
}

class _YearSection extends StatelessWidget {
  final int year;
  final List<DocumentModel> documents;
  final int index;

  const _YearSection({
    required this.year,
    required this.documents,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Year header ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                year.toString(),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${documents.length} document${documents.length == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),

        // ── Document rows ────────────────────────────────────────────────
        ...documents.asMap().entries.map((entry) {
          final i   = entry.key;
          final doc = entry.value;
          return Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 8),
            child: _TimelineRow(document: doc)
                .animate(delay: Duration(milliseconds: (index * 80) + (i * 40)))
                .fadeIn(duration: 280.ms)
                .slideX(begin: -0.05, end: 0, duration: 280.ms, curve: Curves.easeOut),
          );
        }),

        const SizedBox(height: 12),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final DocumentModel document;
  const _TimelineRow({required this.document});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date  = document.createdAt;
    final month = _monthAbbr(date.month);

    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.push('${RouteNames.documentViewer}/${document.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // ── Month badge ──────────────────────────────────────────────
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      month,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                    Text(
                      date.day.toString(),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // ── Info ─────────────────────────────────────────────────────
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
                    Text(
                      document.category,
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),

              // ── Expiry ────────────────────────────────────────────────────
              if (document.expiryDate != null)
                ExpiryAlertBadge(expiryDate: document.expiryDate, compact: true),

              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.outlineVariant),
            ],
          ),
        ),
      ),
    );
  }

  String _monthAbbr(int month) => const [
        'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
        'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
      ][month - 1];
}

class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timeline_rounded,
              size: 64, color: AppColors.outlineVariant),
          const SizedBox(height: 16),
          Text(
            'No documents yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Scan your first document to see the timeline',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.outlineVariant),
          ),
        ],
      ),
    );
  }
}
