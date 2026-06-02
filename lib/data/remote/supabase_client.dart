import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper around [Supabase] that exposes the client, auth, and storage.
/// Call [SupabaseClientWrapper.init] once in main() before runApp.
class SupabaseClientWrapper {
  SupabaseClientWrapper._();

  // ── Replace with your actual project values ──────────────────────────────
  static const String _supabaseUrl = 'https://dxxrfhpuqandgkfazjqq.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR4eHJmaHB1cWFuZGdrZmF6anFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU1MjkwMzYsImV4cCI6MjA5MTEwNTAzNn0.uzJoO4pgdTfBc3sKJNfTFxoReeiZgqsqOAwXn4c9AHY';

  /// Initialise Supabase — call once in main() before runApp.
  static Future<void> init() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
      debug: false,
    );
  }

  /// The authenticated Supabase client.
  static SupabaseClient get client => Supabase.instance.client;

  /// Current Supabase Auth session.
  static GoTrueClient get auth => Supabase.instance.client.auth;

  /// Supabase Storage bucket accessor.
  static SupabaseStorageClient get storage => Supabase.instance.client.storage;

  /// The currently signed-in user (null if unauthenticated).
  static User? get currentUser => Supabase.instance.client.auth.currentUser;

  /// Stream of auth state changes.
  static Stream<AuthState> get authStateChanges =>
      Supabase.instance.client.auth.onAuthStateChange;

  /// Cloud file storage bucket for document images.
  static StorageFileApi get docsBucket =>
      Supabase.instance.client.storage.from('documents');
}
