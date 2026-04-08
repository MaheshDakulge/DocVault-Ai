import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/router/route_names.dart';
import '../../core/security/secure_storage.dart';
import '../../data/remote/supabase_client.dart';

/// Entry-point gate:
///  1. On cold-start: reads SecureStorage to decide initial route.
///  2. After Google OAuth redirect: Supabase fires a SIGNED_IN event on
///     [SupabaseClientWrapper.authStateChanges]; we persist the JWT and
///     navigate home so the user never gets stuck on the login screen.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _listenToAuthState();
    _navigateOnColdStart();
  }

  /// Reacts to Supabase auth events (including the OAuth deep-link callback).
  void _listenToAuthState() {
    _authSub = SupabaseClientWrapper.authStateChanges.listen((authState) async {
      final event = authState.event;
      final session = authState.session;

      if (event == AuthChangeEvent.signedIn && session != null) {
        // Persist the new token and check for PIN
        await SecureStorage.saveJwt(session.accessToken);
        await SecureStorage.saveUserId(session.user.id);
        
        final hasPin = await SecureStorage.getAppPin() != null;
        if (mounted) {
          if (hasPin) {
            context.go(RouteNames.pinLogin);
          } else {
            context.go(RouteNames.pinSetup);
          }
        }
      } else if (event == AuthChangeEvent.signedOut) {
        if (mounted) context.go(RouteNames.login);
      }
    });
  }

  /// First-launch route decision (cold start, no stream event yet).
  Future<void> _navigateOnColdStart() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    // Use Supabase's own session (persists via refresh token for weeks)
    final session = Supabase.instance.client.auth.currentSession;
    final onboarded = await SecureStorage.isOnboarded();

    if (session == null) {
      // Not logged in
      if (!onboarded) {
        if (mounted) context.go(RouteNames.onboarding);
      } else {
        if (mounted) context.go(RouteNames.login);
      }
    } else {
      // Logged in — persist fresh token for legacy usage
      await SecureStorage.saveJwt(session.accessToken);
      await SecureStorage.saveUserId(session.user.id);

      final hasPin = await SecureStorage.getAppPin() != null;
      if (mounted) {
        if (hasPin) {
          context.go(RouteNames.pinLogin);
        } else {
          context.go(RouteNames.home);
        }
      }
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D14),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF630ED4)),
      ),
    );
  }
}
