import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/colors.dart';
import '../../domain/providers/assistant_provider.dart';
import '../common_widgets/vault_app_bar.dart';
import 'widgets/scheme_card.dart';

class EligibilityScreen extends ConsumerStatefulWidget {
  const EligibilityScreen({super.key});

  @override
  ConsumerState<EligibilityScreen> createState() => _EligibilityScreenState();
}

class _EligibilityScreenState extends ConsumerState<EligibilityScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-run eligibility check on screen open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(eligibilityProvider.notifier).checkEligibility();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eligibilityProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: VaultAppBar(
        title: 'Scheme Eligibility',
        subtitle: 'AI-matched government schemes',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded,
                color: AppColors.primary),
            onPressed: () =>
                ref.read(eligibilityProvider.notifier).checkEligibility(),
            tooltip: 'Re-check eligibility',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: state.when(
        loading: () => _LoadingView(),
        error: (e, _) => _ErrorView(
          error: e.toString(),
          onRetry: () =>
              ref.read(eligibilityProvider.notifier).checkEligibility(),
        ),
        data: (schemes) {
          if (schemes.isEmpty) {
            return _EmptyView(
              onRetry: () =>
                  ref.read(eligibilityProvider.notifier).checkEligibility(),
            );
          }

          final eligible    = schemes.where((s) => s['is_eligible'] == true).toList();
          final notEligible = schemes.where((s) => s['is_eligible'] != true).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // ── Summary banner ─────────────────────────────────────────
              _SummaryBanner(
                total: schemes.length,
                eligible: eligible.length,
              ),
              const SizedBox(height: 24),

              // ── Eligible schemes ───────────────────────────────────────
              if (eligible.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.success,
                  label: 'You may be eligible (${eligible.length})',
                ),
                const SizedBox(height: 10),
                ...eligible.asMap().entries.map((e) => SchemeCard(scheme: e.value)
                    .animate(delay: Duration(milliseconds: e.key * 60))
                    .fadeIn(duration: 250.ms)
                    .slideY(begin: 0.05, end: 0, duration: 250.ms)),
                const SizedBox(height: 16),
              ],

              // ── Not eligible ───────────────────────────────────────────
              if (notEligible.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.cancel_outlined,
                  color: AppColors.onSurfaceVariant,
                  label: 'Not currently eligible (${notEligible.length})',
                ),
                const SizedBox(height: 10),
                ...notEligible.asMap().entries.map((e) => SchemeCard(scheme: e.value)
                    .animate(delay: Duration(milliseconds: (eligible.length * 60) + (e.key * 40)))
                    .fadeIn(duration: 250.ms)),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final int total;
  final int eligible;

  const _SummaryBanner({required this.total, required this.eligible});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryFixed, AppColors.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: AppColors.primary, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eligible == 0
                      ? 'No matching schemes found'
                      : '$eligible of $total schemes match your documents',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Based on your scanned documents',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _SectionHeader({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 20),
          Text(
            'Gemini is analysing\nyour documents…',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Could not connect to server',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Eligibility check requires an internet connection.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 56, color: AppColors.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No schemes found',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Scan more documents to improve eligibility matching.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Re-check'),
            ),
          ],
        ),
      ),
    );
  }
}
