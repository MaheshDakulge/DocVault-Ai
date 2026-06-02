import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../models/user_model.dart';

// ── Repository provider ────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ── Auth state notifier ────────────────────────────────────────────────────

class AuthNotifier extends AsyncNotifier<UserModel?> {
  @override
  Future<UserModel?> build() async {
    // Try restoring from stored JWT on cold start
    final repo = ref.read(authRepositoryProvider);
    return repo.restoreSession();
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    final repo = ref.read(authRepositoryProvider);
    state = await AsyncValue.guard(() => repo.signInWithGoogle());
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, UserModel?>(
  AuthNotifier.new,
);

/// Convenience bool provider — true when a user is signed in.
final isSignedInProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).valueOrNull != null;
});

/// The current user (null-safe) — throws if loading.
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});
