import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';
import '../../core/theme/colors.dart';
import '../../domain/providers/auth_provider.dart';
import '../common_widgets/glass_card.dart';

/// Login Screen — minimal purple aesthetic with Google Sign-In
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Listen to auth state to show loading spinner if needed
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;

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
                          onPressed: isLoading
                              ? null
                              : () async {
                                  await ref.read(authProvider.notifier).signInWithGoogle();
                                  
                                  // Check if the user is now signed in successfully
                                  if (context.mounted) {
                                    if (ref.read(isSignedInProvider)) {
                                      context.go(RouteNames.home);
                                    } else if (ref.read(authProvider).hasError) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Sign in failed: ${ref.read(authProvider).error}'),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: isLoading 
                              ? const SizedBox(
                                  width: 24, 
                                  height: 24, 
                                  child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2)
                                )
                              : const Icon(Icons.g_mobiledata_rounded, size: 24),
                          label: Text(isLoading ? 'Connecting...' : 'Continue with Google'),
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
