import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/route_names.dart';
import '../../core/security/secure_storage.dart';

/// Entry point gate: checks auth state and redirects accordingly.
/// Offline-capable: auth state is read from secure local storage.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final jwt = await SecureStorage.getJwt();
    final onboarded = await SecureStorage.isOnboarded();

    if (jwt == null) {
      if (!onboarded) {
        if (mounted) context.go(RouteNames.onboarding);
      } else {
        if (mounted) context.go(RouteNames.login);
      }
    } else {
      if (mounted) context.go(RouteNames.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Splash / loading state while checking auth
    return const Scaffold(
      backgroundColor: Color(0xFFF7F9FB),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF630ED4)),
      ),
    );
  }
}
