import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../../domain/providers/search_provider.dart';
import '../common_widgets/offline_banner.dart';
import 'widgets/search_result_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl   = TextEditingController();
  final _focus  = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    ref.read(searchQueryProvider.notifier).state = value;
  }

  void _clear() {
    _ctrl.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    _focus.requestFocus();
  }

  void _submit(String query) {
    if (query.trim().isEmpty) return;
    ref.read(recentSearchesProvider.notifier).add(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final query   = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final recents = ref.watch(recentSearchesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: 'Search documents, fields, dates…',
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.onSurfaceVariant),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18,
                              color: AppColors.onSurfaceVariant),
                          onPressed: _clear,
                        )
                      : null,
                ),
              ),
            ),
          ),

          const OfflineBanner(),

          // ── Body ───────────────────────────────────────────────────────
          Expanded(
            child: query.isEmpty
                ? _RecentSearches(
                    recents: recents,
                    onTap: (s) {
                      _ctrl.text = s;
                      _onChanged(s);
                    },
                    onRemove: (s) =>
                        ref.read(recentSearchesProvider.notifier).remove(s),
                  )
                : results.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (docs) => docs.isEmpty
                        ? _NoResults(query: query)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) => SearchResultTile(
                              result: docs[i],
                              query: query,
                              onTap: () {
                                _submit(query);
                                context.push(
                                    '${RouteNames.documentViewer}/${docs[i]['id']}');
                              },
                            )
                                .animate(
                                    delay: Duration(milliseconds: i * 40))
                                .fadeIn(duration: 220.ms)
                                .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    duration: 220.ms),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _RecentSearches extends StatelessWidget {
  final List<String> recents;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onRemove;

  const _RecentSearches({
    required this.recents,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (recents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_search_rounded,
                size: 56, color: AppColors.outlineVariant),
            const SizedBox(height: 12),
            Text(
              'Type to search instantly — offline',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Text('Recent Searches',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.onSurfaceVariant,
                  )),
            ],
          ),
        ),
        ...recents.map(
          (s) => ListTile(
            leading: const Icon(Icons.history_rounded,
                color: AppColors.outlineVariant, size: 20),
            title: Text(s, style: theme.textTheme.bodyMedium),
            trailing: IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 16, color: AppColors.outlineVariant),
              onPressed: () => onRemove(s),
            ),
            onTap: () => onTap(s),
          ),
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded,
              size: 56, color: AppColors.outlineVariant),
          const SizedBox(height: 14),
          Text('No results for "$query"',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            'Try a field value, date, or document name',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
