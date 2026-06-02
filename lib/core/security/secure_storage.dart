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

  // App PIN
  static const _keyAppPin = 'app_pin';
  static Future<void> saveAppPin(String pin) => _storage.write(key: _keyAppPin, value: pin);
  static Future<String?> getAppPin()         => _storage.read(key: _keyAppPin);
  static Future<void> deleteAppPin()         => _storage.delete(key: _keyAppPin);

  // Biometric lock preference
  static const _keyBiometricLockEnabled = 'biometric_lock_enabled';
  static Future<void> setBiometricLockEnabled(bool enabled) =>
      _storage.write(key: _keyBiometricLockEnabled, value: enabled.toString());
  static Future<bool> isBiometricLockEnabled() async {
    final value = await _storage.read(key: _keyBiometricLockEnabled);
    return value == 'true';
  }
  static Future<void> deleteBiometricLockEnabled() =>
      _storage.delete(key: _keyBiometricLockEnabled);

  // Onboarding flag
  static Future<void> setOnboarded()          => _storage.write(key: _keyOnboarded, value: 'true');
  static Future<bool> isOnboarded() async {
    final v = await _storage.read(key: _keyOnboarded);
    return v == 'true';
  }

  /// Clear all secure data on logout
  static Future<void> clearAll() => _storage.deleteAll();
}
