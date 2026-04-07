import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 24),
            Text('DocsVault AI', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text('Secure. Offline. Intelligent.',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
