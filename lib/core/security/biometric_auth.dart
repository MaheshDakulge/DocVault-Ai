import 'package:local_auth/local_auth.dart';

/// Biometric + PIN authentication wrapper using flutter local_auth
/// No network call needed — 100% offline biometric check
class BiometricAuth {
  BiometricAuth._();
  static final _auth = LocalAuthentication();

  static Future<List<BiometricType>> getAvailableTypes() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) return const [];
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Returns true if the device supports biometric authentication
  /// and the user has enrolled at least one biometric.
  static Future<bool> isAvailable() async {
    final isSupported = await _auth.isDeviceSupported();
    final biometrics = await getAvailableTypes();
    return isSupported && biometrics.isNotEmpty;
  }

  /// Prompts the user for biometric or device PIN authentication.
  /// Returns true on success.
  static Future<bool> authenticate({
    String reason = 'Access your secure vault',
    bool biometricOnly = true,
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          biometricOnly: biometricOnly,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
