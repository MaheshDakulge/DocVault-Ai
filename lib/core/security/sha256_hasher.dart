import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// SHA-256 tamper detection utility
/// On first scan, a fingerprint is computed from raw image bytes.
/// On subsequent reads, the fingerprint is recomputed and compared.
/// If they differ → file has been tampered with (forensic-level detection).
class Sha256Hasher {
  Sha256Hasher._();

  /// Compute SHA-256 hex digest from raw image [bytes]
  static String hashBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify [bytes] against a previously stored [expectedHash]
  /// Returns true if the file is intact (no tampering detected)
  static bool verify(Uint8List bytes, String expectedHash) {
    final current = hashBytes(bytes);
    return current == expectedHash;
  }

  /// Compute hash from a base64-encoded string (e.g. from API response)
  static String hashFromBase64(String base64Str) {
    final bytes = base64Decode(base64Str);
    return hashBytes(Uint8List.fromList(bytes));
  }
}
