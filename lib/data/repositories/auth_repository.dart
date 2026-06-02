import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/security/secure_storage.dart';
import '../../domain/models/user_model.dart';
import '../remote/supabase_client.dart';

/// Authentication repository.
/// Wraps Supabase Auth + Google Sign-In and persists the JWT locally.
class AuthRepository {
  final _auth = SupabaseClientWrapper.auth;

  // ── State ─────────────────────────────────────────────────────────────────

  /// Current user or null if unauthenticated.
  UserModel? get currentUser {
    final u = SupabaseClientWrapper.currentUser;
    if (u == null) return null;
    return UserModel(
      id: u.id,
      email: u.email ?? '',
      name: u.userMetadata?['full_name'] as String?,
      profilePicUrl: u.userMetadata?['avatar_url'] as String?,
      createdAt: DateTime.parse(u.createdAt),
    );
  }

  /// Stream of auth state changes for reactive UI.
  Stream<UserModel?> get authStateStream =>
      SupabaseClientWrapper.authStateChanges.map((state) {
        final u = state.session?.user;
        if (u == null) return null;
        return UserModel(
          id: u.id,
          email: u.email ?? '',
          name: u.userMetadata?['full_name'] as String?,
          profilePicUrl: u.userMetadata?['avatar_url'] as String?,
          createdAt: DateTime.parse(u.createdAt),
        );
      });

  // ── Sign In ───────────────────────────────────────────────────────────────

  /// Sign in with Google via Supabase OAuth.
  /// On success, persists the JWT to [SecureStorage].
  Future<UserModel?> signInWithGoogle() async {
    await _auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: 'io.supabase.digisafe://login-callback',
    );
    // The session is received via deep-link in AuthGate
    return currentUser;
  }

  /// Restore session from stored JWT (called on cold start).
  Future<UserModel?> restoreSession() async {
    final token = await SecureStorage.getJwt();
    if (token == null) return null;

    try {
      final response = await _auth.setSession(token);
      final u = response.user;
      if (u == null) return null;

      // Refresh token in secure storage
      if (response.session?.accessToken != null) {
        await SecureStorage.saveJwt(response.session!.accessToken);
      }

      return currentUser;
    } catch (_) {
      await SecureStorage.deleteJwt();
      return null;
    }
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────

  /// Sign out and clear all locally stored credentials.
  Future<void> signOut() async {
    await _auth.signOut();
    await SecureStorage.clearAll();
  }

  // ── Session helpers ───────────────────────────────────────────────────────

  bool get isSignedIn => SupabaseClientWrapper.currentUser != null;

  Future<void> persistSession(Session session) async {
    await SecureStorage.saveJwt(session.accessToken);
    await SecureStorage.saveUserId(session.user.id);
  }
}
