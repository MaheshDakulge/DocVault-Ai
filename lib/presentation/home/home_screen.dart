import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';
import '../common_widgets/scanning_fab.dart';
import '../common_widgets/offline_banner.dart';
import 'widgets/document_tree_widget.dart';
import 'widgets/category_chip.dart';

/// Home Screen — The "Digital Curator" landing experience.
///
/// Layout:
///   - Asymmetric hero header (Manrope Display headline left-aligned)
///   - Category filter chips (horizontal scroll)
///   - Document tree grouped by category
///   - Floating glassmorphism ScanningFAB
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Glassmorphism SliverAppBar ──────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 140,
                collapsedHeight: 64,
                backgroundColor: AppColors.glass,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
                  title: Text(
                    'DocsVault AI',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primaryFixed.withValues(alpha: 0.4),
                          AppColors.surface,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20, top: 56, right: 20),
                      child: Text(
                        'Your Digital Sanctuary',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded, color: AppColors.onSurface),
                    onPressed: () => context.push(RouteNames.search),
                    tooltip: 'Search documents',
                  ),
                  IconButton(
                    icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
                    onPressed: () => context.push(RouteNames.assistant),
                    tooltip: 'AI Assistant',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, color: AppColors.onSurface),
                    onPressed: () => context.push(RouteNames.settings),
                  ),
                  const SizedBox(width: 8),
                ],
              ),

              // ── Offline Banner ──────────────────────────────────────────
              const SliverToBoxAdapter(child: OfflineBanner()),

              // ── Category Chips ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      CategoryChip(
                        label: 'All',
                        isSelected: _selectedCategory == null,
                        onTap: () => setState(() => _selectedCategory = null),
                      ),
                      ...['Identity', 'Education', 'Financial', 'Medical', 'Vehicle', 'Travel']
                          .map((c) => CategoryChip(
                                label: c,
                                isSelected: _selectedCategory == c,
                                onTap: () =>
                                    setState(() => _selectedCategory = c == _selectedCategory ? null : c),
                              )),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ── Bottom Nav Hint (Timeline) ──────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Documents',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          )),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => context.push('${RouteNames.home}/timeline'),
                        icon: const Icon(Icons.timeline_rounded, size: 16),
                        label: const Text('Timeline'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Document Tree ───────────────────────────────────────────
              DocumentTreeWidget(selectedCategory: _selectedCategory),

              // ── Bottom padding for FAB ──────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),

          // ── Floating Scanning FAB ─────────────────────────────────────
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Center(
              child: ScanningFab(
                onPressed: () => context.push(RouteNames.scan),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
