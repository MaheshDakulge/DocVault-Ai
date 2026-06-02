import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/router/route_names.dart';

/// App shell that wraps all main screens with a persistent bottom navigation bar.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppShell({super.key, required this.navigationShell});

  static const _tabs = [
    _NavTab(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', route: RouteNames.home),
    _NavTab(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: 'Search', route: RouteNames.search),
    _NavTab(icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded, label: 'Assistant', route: RouteNames.assistant),
    _NavTab(icon: Icons.settings_outlined, activeIcon: Icons.settings_rounded, label: 'Settings', route: RouteNames.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_tabs.length, (i) {
                final tab = _tabs[i];
                final isActive = currentIndex == i;

                // Centre tab gets the ScanFAB treatment: no nav item
                return _NavItem(
                  icon: isActive ? tab.activeIcon : tab.icon,
                  label: tab.label,
                  isActive: isActive,
                  onTap: () => navigationShell.goBranch(
                    i,
                    initialLocation: i == navigationShell.currentIndex,
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      // Centrally placed floating Scan FAB above nav bar
      floatingActionButton: _ScanFab(
        onPressed: () => context.push(RouteNames.scan),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _ScanFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryContainer],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.document_scanner_outlined, color: Colors.white, size: 28),
      ),
    );
  }
}
