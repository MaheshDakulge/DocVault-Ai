import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/colors.dart';
import '../../../core/router/route_names.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/providers/database_providers.dart';
import '../../../data/local/database.dart';

/// Document tree widget — groups documents by category.
/// Reads from SQLite offline. No internet required.
/// Staggered animation on each card via flutter_animate.
class DocumentTreeWidget extends ConsumerWidget {
  final String? selectedCategory;

  const DocumentTreeWidget({super.key, this.selectedCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentDao = ref.watch(documentDaoProvider);
    
    return StreamBuilder<List<Document>>(
      stream: documentDao.watchAllDocuments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final docs = snapshot.data ?? [];
        final filtered = selectedCategory == null 
            ? docs 
            : docs.where((d) => d.category == selectedCategory).toList();

        if (filtered.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open_rounded,
                      size: 64, color: AppColors.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No documents yet',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the Scan button to add your first document',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.outlineVariant),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final doc = filtered[index];
              return DocumentCard(doc: doc)
                  .animate(delay: Duration(milliseconds: index * 60))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.06, end: 0, duration: 300.ms, curve: Curves.easeOut);
            },
            childCount: filtered.length,
          ),
        );
      },
    );
  }
}

/// Individual document card — lifted on surface with no dividers.
class DocumentCard extends StatelessWidget {
  final Document doc;
  const DocumentCard({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('${RouteNames.documentViewer}/${doc.id}'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Thumbnail or icon placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doc.filename,
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(doc.category,
                          style: theme.textTheme.labelMedium),
                    ],
                  ),
                ),
                if (doc.isTampered == true)
                  const Icon(Icons.warning_rounded,
                      color: AppColors.tertiary, size: 18),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.outlineVariant, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
