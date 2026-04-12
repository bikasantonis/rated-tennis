import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Wraps [LocalAuthentication] for biometric / device-credential prompts.
///
/// Guarded with [kIsWeb] — local_auth has no web implementation.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final _auth = LocalAuthentication();

  /// Returns true if the device has any biometric (or device-credential) method
  /// enrolled and available.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the user for biometric / PIN authentication.
  ///
  /// [localizedReason] is displayed in the system prompt (required on iOS).
  /// Returns true on success, false on failure or cancellation.
  Future<bool> authenticate(String localizedReason) async {
    if (kIsWeb) return true; // no-op on web
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN / pattern as fallback
          stickyAuth: true,     // keep prompt alive if user leaves app briefly
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
