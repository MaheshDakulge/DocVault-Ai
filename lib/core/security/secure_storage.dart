import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage wrapper for sensitive strings (JWT, Supabase tokens, user ID)
/// Uses Keystore on Android and Keychain on iOS
class SecureStorage {
  SecureStorage._();
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyJwt        = 'jwt_token';
  static const _keyUserId     = 'user_id';
  static const _keyOnboarded  = 'onboarding_complete';

  // JWT
  static Future<void> saveJwt(String token)   => _storage.write(key: _keyJwt, value: token);
  static Future<String?> getJwt()             => _storage.read(key: _keyJwt);
  static Future<void> deleteJwt()             => _storage.delete(key: _keyJwt);

  // User ID
  static Future<void> saveUserId(String id)   => _storage.write(key: _keyUserId, value: id);
  static Future<String?> getUserId()          => _storage.read(key: _keyUserId);

  // Onboarding flag
  static Future<void> setOnboarded()          => _storage.write(key: _keyOnboarded, value: 'true');
  static Future<bool> isOnboarded() async {
    final v = await _storage.read(key: _keyOnboarded);
    return v == 'true';
  }

  /// Clear all secure data on logout
  static Future<void> clearAll() => _storage.deleteAll();
}
