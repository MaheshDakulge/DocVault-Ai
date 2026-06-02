import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/colors.dart';
import '../../../core/router/route_names.dart';
import '../../../domain/providers/document_provider.dart';
import 'document_card.dart';

/// Document tree widget — reactive stream from SQLite, 100% offline.
/// Staggered fade+slide animation per card.
class DocumentTreeWidget extends ConsumerWidget {
  final String? selectedCategory;

  const DocumentTreeWidget({super.key, this.selectedCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = selectedCategory != null
        ? ref.watch(documentsByCategoryProvider(selectedCategory))
        : ref.watch(documentsStreamProvider);

    return docsAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ),
      error: (e, _) => SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Error loading documents: $e',
                style: const TextStyle(color: AppColors.error)),
          ),
        ),
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return const SliverFillRemaining(child: _EmptyState());
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final doc = docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: DocumentCard(
                    document: doc,
                    onTap: () =>
                        context.push('${RouteNames.documentViewer}/${doc.id}'),
                  )
                      .animate(delay: Duration(milliseconds: index * 55))
                      .fadeIn(duration: 280.ms)
                      .slideY(
                          begin: 0.06,
                          end: 0,
                          duration: 280.ms,
                          curve: Curves.easeOut),
                );
              },
              childCount: docs.length,
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.folder_open_rounded,
            size: 72, color: AppColors.outlineVariant),
        const SizedBox(height: 16),
        Text(
          'Your vault is empty',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the Scan button below\nto add your first document',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.outlineVariant,
              ),
        ),
      ],
    );
  }
}
