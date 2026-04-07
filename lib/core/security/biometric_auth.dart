import 'package:local_auth/local_auth.dart';

/// Biometric + PIN authentication wrapper using flutter local_auth
/// No network call needed — 100% offline biometric check
class BiometricAuth {
  BiometricAuth._();
  static final _auth = LocalAuthentication();

  /// Returns true if the device supports biometric authentication
  static Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  }

  /// Prompts the user for biometric or device PIN authentication.
  /// Returns true on success.
  static Future<bool> authenticate({String reason = 'Access your secure vault'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allows PIN/pattern fallback
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
