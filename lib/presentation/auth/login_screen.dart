import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../common_widgets/glass_card.dart';

/// Login Screen — minimal purple aesthetic with Google Sign-In
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryFixed, AppColors.surface, AppColors.surface],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(flex: 2),
                // Hero headline — intentional asymmetry
                Text('Your\nDigital\nSanctuary.',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      height: 1.05,
                    )),
                const SizedBox(height: 16),
                Text('Secure, offline-first document vault\npowered by Gemini AI.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    )),
                const Spacer(flex: 3),
                GlassCard(
                  elevated: true,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Google Sign-In button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Implement Supabase Google Sign-In (Day 3)
                          },
                          icon: const Icon(Icons.g_mobiledata_rounded, size: 24),
                          label: const Text('Continue with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Your documents never leave your device without permission.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
