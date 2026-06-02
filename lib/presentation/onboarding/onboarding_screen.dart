import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';
import '../../core/security/secure_storage.dart';
import '../../core/theme/colors.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
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
            Positioned(
              bottom: 32,
              left: 24,
              right: 24,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await SecureStorage.setOnboarded();
                    if (context.mounted) {
                      context.go(RouteNames.login);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
